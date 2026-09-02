import Foundation
import OSLog
import RevenueCat

struct RevenueCatEntitlementSnapshot: Equatable {
    let isActive: Bool
    let expirationDate: Date?
    let productIdentifier: String?
}

@MainActor
final class RevenueCatService {
    static let shared = RevenueCatService()

    private static let entitlementIdentifier = "pro"
    private static let migrationKeyPrefix = "revenuecat.legacy_purchase_synced."
    private static let logger = Logger(subsystem: "com.chillnote.app", category: "revenuecat")

    private var isConfigured = false
    private var customerInfoTask: Task<Void, Never>?
    private var customerInfoObserver: ((RevenueCatEntitlementSnapshot) -> Void)?

    private init() {}

    var configured: Bool { isConfigured }

    func configure() {
        guard !isConfigured else { return }
        guard let apiKey = AppConfig.revenueCatIOSAPIKey else {
            Self.logger.notice("RevenueCat is disabled because REVENUECAT_IOS_API_KEY is missing")
            return
        }

#if DEBUG
        Purchases.logLevel = .debug
#endif

        // Keep transaction completion in the existing StoreKit 2 listener for the
        // first migration release. RevenueCat still owns offerings, purchase
        // initiation, CustomerInfo, restore and server-side lifecycle tracking.
        let configuration = Configuration.Builder(withAPIKey: apiKey)
            .with(purchasesAreCompletedBy: .myApp, storeKitVersion: .storeKit2)
            .build()
        Purchases.configure(with: configuration)
        isConfigured = true
        startCustomerInfoObservation()
    }

    func setCustomerInfoObserver(_ observer: @escaping (RevenueCatEntitlementSnapshot) -> Void) {
        customerInfoObserver = observer
    }

    func identify(userID: String?, migrateLegacyPurchase: Bool) async -> RevenueCatEntitlementSnapshot? {
        configure()
        guard isConfigured, let userID, !userID.isEmpty else { return nil }

        do {
            let customerInfo: CustomerInfo
            if Purchases.shared.appUserID == userID {
                customerInfo = try await Purchases.shared.customerInfo()
            } else {
                customerInfo = try await Purchases.shared.logIn(userID).customerInfo
            }
            var snapshot = Self.snapshot(from: customerInfo)

            // Existing iOS subscribers stay protected by the legacy backend while
            // their receipt is associated with the stable Supabase user exactly once.
            let migrationKey = Self.migrationKeyPrefix + userID
            if migrateLegacyPurchase,
               !snapshot.isActive,
               !UserDefaults.standard.bool(forKey: migrationKey) {
                let synced = try await Purchases.shared.syncPurchases()
                snapshot = Self.snapshot(from: synced)
                UserDefaults.standard.set(true, forKey: migrationKey)
            }
            customerInfoObserver?(snapshot)
            return snapshot
        } catch {
            Self.logger.error("RevenueCat user identification failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func currentOfferingPackages() async throws -> [Package] {
        guard isConfigured else { return [] }
        return try await Purchases.shared.offerings().current?.availablePackages ?? []
    }

    func storeProducts(identifiers: [String]) async -> [RevenueCat.StoreProduct] {
        guard isConfigured else { return [] }
        return await Purchases.shared.products(identifiers)
    }

    func purchase(package: Package) async throws -> (snapshot: RevenueCatEntitlementSnapshot, userCancelled: Bool) {
        let result = try await Purchases.shared.purchase(package: package)
        let snapshot = Self.snapshot(from: result.customerInfo)
        customerInfoObserver?(snapshot)
        return (snapshot, result.userCancelled)
    }

    func purchase(product: RevenueCat.StoreProduct) async throws -> (snapshot: RevenueCatEntitlementSnapshot, userCancelled: Bool) {
        let result = try await Purchases.shared.purchase(product: product)
        let snapshot = Self.snapshot(from: result.customerInfo)
        customerInfoObserver?(snapshot)
        return (snapshot, result.userCancelled)
    }

    func restorePurchases() async throws -> RevenueCatEntitlementSnapshot {
        let customerInfo = try await Purchases.shared.restorePurchases()
        let snapshot = Self.snapshot(from: customerInfo)
        customerInfoObserver?(snapshot)
        return snapshot
    }

    func refreshCustomerInfo() async -> RevenueCatEntitlementSnapshot? {
        guard isConfigured else { return nil }
        do {
            let snapshot = Self.snapshot(from: try await Purchases.shared.customerInfo())
            customerInfoObserver?(snapshot)
            return snapshot
        } catch {
            Self.logger.warning("RevenueCat CustomerInfo refresh failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func startCustomerInfoObservation() {
        customerInfoTask?.cancel()
        customerInfoTask = Task { [weak self] in
            guard let self else { return }
            for await customerInfo in Purchases.shared.customerInfoStream {
                guard !Task.isCancelled else { return }
                self.customerInfoObserver?(Self.snapshot(from: customerInfo))
            }
        }
    }

    private static func snapshot(from customerInfo: CustomerInfo) -> RevenueCatEntitlementSnapshot {
        let entitlement = customerInfo.entitlements[Self.entitlementIdentifier]
        return RevenueCatEntitlementSnapshot(
            isActive: entitlement?.isActive == true,
            expirationDate: entitlement?.expirationDate,
            productIdentifier: entitlement?.productIdentifier
        )
    }
}
