import Foundation
import OSLog
import StoreKit

enum SubscriptionTier: String, CaseIterable {
    case free
    case pro
}

enum DailyQuotaFeature: String {
    case voice
    case agentRecipe = "agent_recipe"
    case chat
}

struct SubscriptionPeriodDescriptor: Equatable {
    enum Unit: Equatable {
        case day
        case week
        case month
        case year
    }

    let unit: Unit
    let value: Int

    init(unit: Unit, value: Int) {
        self.unit = unit
        self.value = value
    }

    init?(storeKitPeriod: Product.SubscriptionPeriod?) {
        guard let storeKitPeriod else { return nil }

        let mappedUnit: Unit
        switch storeKitPeriod.unit {
        case .day:
            mappedUnit = .day
        case .week:
            mappedUnit = .week
        case .month:
            mappedUnit = .month
        case .year:
            mappedUnit = .year
        @unknown default:
            return nil
        }

        self.init(unit: mappedUnit, value: storeKitPeriod.value)
    }

    var totalMonths: Int? {
        switch unit {
        case .month:
            return value
        case .year:
            return value * 12
        case .day, .week:
            return nil
        }
    }

    var isAnnual: Bool {
        totalMonths == 12
    }

    func localizedDuration(locale: Locale = .current) -> String? {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1
        var calendar = Calendar.autoupdatingCurrent
        calendar.locale = locale
        formatter.calendar = calendar

        let components: DateComponents
        switch unit {
        case .day:
            formatter.allowedUnits = [.day]
            components = DateComponents(day: value)
        case .week:
            formatter.allowedUnits = [.weekOfMonth]
            components = DateComponents(weekOfMonth: value)
        case .month:
            formatter.allowedUnits = [.month]
            components = DateComponents(month: value)
        case .year:
            formatter.allowedUnits = [.year]
            components = DateComponents(year: value)
        }

        return formatter.string(from: components)
    }
}

struct IntroductoryOfferDescriptor: Equatable {
    enum PaymentMode: Equatable {
        case freeTrial
        case payAsYouGo
        case payUpFront
    }

    let paymentMode: PaymentMode
    let period: SubscriptionPeriodDescriptor

    init(paymentMode: PaymentMode, period: SubscriptionPeriodDescriptor) {
        self.paymentMode = paymentMode
        self.period = period
    }

    init?(storeKitOffer: Product.SubscriptionOffer?) {
        guard let storeKitOffer,
              let period = SubscriptionPeriodDescriptor(storeKitPeriod: storeKitOffer.period) else {
            return nil
        }

        let mappedMode: PaymentMode
        switch storeKitOffer.paymentMode {
        case .freeTrial:
            mappedMode = .freeTrial
        case .payAsYouGo:
            mappedMode = .payAsYouGo
        case .payUpFront:
            mappedMode = .payUpFront
        default:
            return nil
        }

        self.init(paymentMode: mappedMode, period: period)
    }

    var isFreeTrial: Bool {
        paymentMode == .freeTrial
    }
}

struct SubscriptionDisplayInfo: Equatable {
    let isAnnual: Bool
    let badgeText: String
    let ctaText: String
    let billingPeriodText: String
    let equivalentMonthlyText: String?
    let equivalentWeeklyText: String?
    let renewalText: String?
    let trialDurationText: String?

    var hasFreeTrial: Bool {
        trialDurationText != nil
    }

    static func build(
        price: Decimal,
        priceFormatStyle: Decimal.FormatStyle.Currency,
        billingPeriod: SubscriptionPeriodDescriptor?,
        introductoryOffer: IntroductoryOfferDescriptor?,
        locale: Locale = .current
    ) -> SubscriptionDisplayInfo {
        let priceText = price.formatted(priceFormatStyle)
        let isAnnual = billingPeriod?.isAnnual == true
        let billingPeriodText = String(
            localized: isAnnual ? "subscription.billing_period.yearly" : "subscription.billing_period.monthly",
            locale: locale
        )

        let trialDurationText: String?
        if isAnnual,
           let introductoryOffer,
           introductoryOffer.isFreeTrial {
            trialDurationText = introductoryOffer.period.localizedDuration(locale: locale)
        } else {
            trialDurationText = nil
        }

        let badgeText: String
        if let trialDurationText {
            badgeText = String(
                localized: "subscription.badge.free_trial",
                locale: locale
            )
            .replacingOccurrences(of: "%@", with: trialDurationText.uppercased(with: locale))
        } else {
            badgeText = String(
                localized: isAnnual ? "subscription.badge.best_value" : "subscription.badge.flexible",
                locale: locale
            )
        }

        let ctaText: String
        if let trialDurationText {
            ctaText = String(
                localized: "subscription.cta.start_free_trial",
                locale: locale
            )
            .replacingOccurrences(of: "%@", with: trialDurationText)
        } else {
            ctaText = String(
                localized: isAnnual ? "subscription.cta.start_annual" : "subscription.cta.start_monthly",
                locale: locale
            )
        }

        let equivalentMonthlyText: String?
        if isAnnual,
           let monthCount = billingPeriod?.totalMonths,
           monthCount > 0 {
            let monthlyPrice = price / Decimal(monthCount)
            let monthlyPriceText = monthlyPrice.formatted(priceFormatStyle)
            let template = String(
                localized: "subscription.equivalent_monthly_billed_yearly",
                locale: locale
            )
            equivalentMonthlyText = String(format: template, locale: locale, monthlyPriceText)
        } else {
            equivalentMonthlyText = nil
        }

        let equivalentWeeklyText: String?
        if isAnnual {
            let weeklyPrice = price / Decimal(52)
            equivalentWeeklyText = weeklyPrice.formatted(priceFormatStyle)
        } else {
            equivalentWeeklyText = nil
        }

        let renewalText: String?
        if let trialDurationText {
            let billedYearlyTemplate = String(
                localized: "subscription.price_per_year",
                locale: locale
            )
            let billedYearlyText = String(format: billedYearlyTemplate, locale: locale, priceText)
            let renewalTemplate = String(
                localized: "subscription.free_trial_then_price",
                locale: locale
            )
            renewalText = String(format: renewalTemplate, locale: locale, trialDurationText, billedYearlyText)
        } else {
            renewalText = nil
        }

        return SubscriptionDisplayInfo(
            isAnnual: isAnnual,
            badgeText: badgeText,
            ctaText: ctaText,
            billingPeriodText: billingPeriodText,
            equivalentMonthlyText: equivalentMonthlyText,
            equivalentWeeklyText: equivalentWeeklyText,
            renewalText: renewalText,
            trialDurationText: trialDurationText
        )
    }
}

@MainActor
class StoreService: ObservableObject {
    static let shared = StoreService()
    nonisolated private static let logger = Logger(subsystem: "com.chillnote.app", category: "store")

    static let freeRecordingTimeLimit: TimeInterval = 60
    static let proRecordingTimeLimit: TimeInterval = 600
    static let freeDailyVoiceLimit = 5
    static let freeDailyAgentRecipeLimit = 3
    static let freeDailyAIChatLimit = 10
    
    @Published var currentTier: SubscriptionTier = .free
    @Published var availableProducts: [Product] = []
    @Published var isPurchasing = false
    @Published var errorMessage: String?
    @Published var isLoadingProducts = false
    @Published var productsErrorMessage: String?
    
    // Subscription Details
    @Published var subscriptionExpirationDate: Date?
    @Published var activeSubscriptionProductId: String?
    
    // Feature Limits
    var recordingTimeLimit: TimeInterval {
        currentTier == .pro ? Self.proRecordingTimeLimit : Self.freeRecordingTimeLimit
    }

    var dailyVoiceLimit: Int {
        currentTier == .pro ? Int.max : Self.freeDailyVoiceLimit
    }

    var dailyAgentRecipeLimit: Int {
        currentTier == .pro ? Int.max : Self.freeDailyAgentRecipeLimit
    }

    var dailyAIChatLimit: Int {
        currentTier == .pro ? Int.max : Self.freeDailyAIChatLimit
    }

    // MARK: - Usage Tracking
    private let voiceUsageKey = "daily_voice_ai_usage"
    private let agentRecipeUsageKey = "daily_agent_recipe_ai_usage"
    private let chatUsageKey = "daily_chat_ai_usage"
    
    var remainingFreeVoiceCount: Int {
        if currentTier == .pro { return 999 }
        return max(0, dailyVoiceLimit - currentDailyVoiceUsage)
    }

    private var currentDailyVoiceUsage: Int {
        let defaults = UserDefaults.standard
        let key = usageKeyForToday(baseKey: voiceUsageKey)
        return defaults.integer(forKey: key)
    }

    private var currentDailyAgentRecipeUsage: Int {
        let defaults = UserDefaults.standard
        let key = usageKeyForToday(baseKey: agentRecipeUsageKey)
        return defaults.integer(forKey: key)
    }

    private var currentDailyAIChatUsage: Int {
        let defaults = UserDefaults.standard
        let key = usageKeyForToday(baseKey: chatUsageKey)
        return defaults.integer(forKey: key)
    }
    
    private func usageKeyForToday(baseKey: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: Date())
        return "\(baseKey)_\(dateStr)"
    }
    
    func canUseVoiceAI() -> Bool {
        if currentTier == .pro { return true }
        return currentDailyVoiceUsage < dailyVoiceLimit
    }

    func canUseAgentRecipeAI() -> Bool {
        if currentTier == .pro { return true }
        return currentDailyAgentRecipeUsage < dailyAgentRecipeLimit
    }

    func canUseAIChat() -> Bool {
        if currentTier == .pro { return true }
        return currentDailyAIChatUsage < dailyAIChatLimit
    }

    func incrementAgentRecipeAIUsage() {
        if currentTier == .pro { return }
        let defaults = UserDefaults.standard
        let key = usageKeyForToday(baseKey: agentRecipeUsageKey)
        let current = defaults.integer(forKey: key)
        defaults.set(current + 1, forKey: key)
    }

    func incrementAIChatUsage() {
        if currentTier == .pro { return }
        let defaults = UserDefaults.standard
        let key = usageKeyForToday(baseKey: chatUsageKey)
        let current = defaults.integer(forKey: key)
        defaults.set(current + 1, forKey: key)
    }

    func incrementVoiceAIUsage() {
        if currentTier == .pro { return }
        let defaults = UserDefaults.standard
        let key = usageKeyForToday(baseKey: voiceUsageKey)
        let current = defaults.integer(forKey: key)
        defaults.set(current + 1, forKey: key)
    }

    @discardableResult
    func consumeAgentRecipeAIUsage() -> Bool {
        guard canUseAgentRecipeAI() else { return false }
        incrementAgentRecipeAIUsage()
        return true
    }

    @discardableResult
    func consumeAIChatUsage() -> Bool {
        guard canUseAIChat() else { return false }
        incrementAIChatUsage()
        return true
    }

    @discardableResult
    func consumeVoiceAIUsage() -> Bool {
        guard canUseVoiceAI() else { return false }
        incrementVoiceAIUsage()
        return true
    }

    private func performDailyQuotaRequest(
        feature: DailyQuotaFeature,
        action: String
    ) async -> Bool {
        await ensureSubscriptionStatusReadyForFeatureGate()

        // Pro users have unlimited access — skip the server quota check entirely.
        if currentTier == .pro { return true }

        guard AuthService.shared.confirmedUserId != nil else { return true }
        guard let token = await AuthService.shared.getSessionToken(), !token.isEmpty else { return true }

        let url = URL(string: "\(AppConfig.backendBaseURL)/quota/daily")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "feature": feature.rawValue,
            "action": action
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return true }

            if http.statusCode == 429 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["error"] as? String {
                    self.errorMessage = message
                }
                return false
            }

            return (200...299).contains(http.statusCode)
        } catch {
            // Network failure fallback: don't hard-block user locally.
            return true
        }
    }

    func checkDailyQuotaOnServer(feature: DailyQuotaFeature) async -> Bool {
        await performDailyQuotaRequest(feature: feature, action: "check")
    }

    func consumeDailyQuotaOnServer(feature: DailyQuotaFeature) async -> Bool {
        await performDailyQuotaRequest(feature: feature, action: "consume")
    }

    func authorizeVoiceRecordingStart() async -> Bool {
        await consumeDailyQuotaOnServer(feature: .voice)
    }
    
    // Product Identifiers
    private let productIds = ["com.chillnote.pro.monthly", "com.chillnote.pro.yearly"]
    
    private var transactionListener: Task<Void, Error>?
    private struct BackendSubscriptionStatus: Decodable {
        let tier: String?
        let expiresAt: String?
    }

    private struct CachedBackendSubscriptionStatus: Codable {
        let tier: String
        let expiresAt: String?
    }

    private struct BackendSubscriptionSnapshot {
        let tier: SubscriptionTier
        let expiresAt: Date?
        let isFreshFromBackend: Bool
    }

    private static let legacyBackendTierCacheKey = "cached_backend_subscription_tier"
    private static let backendTierCacheKeyPrefix = "cached_backend_subscription_tier."
    private var lastFreshSubscriptionStatusUserId: String?
    
    init() {
        hydrateCachedSubscriptionStatusForLastAuthenticatedUser()

        // Start listening for transaction updates
        transactionListener = listenForTransactions()
        
        Task {
            await updateSubscriptionStatus(syncActiveTransactionToBackend: false)
            await fetchProducts()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - Transaction Listener
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    
                    // Keep the local UI in sync, but avoid rebinding subscriptions
                    // to whichever ChillNote account is currently signed in.
                    await self.updateSubscriptionStatus(syncActiveTransactionToBackend: false)
                    
                    // Always finish a transaction
                    await transaction.finish()
                } catch {
                    Self.logger.error("Transaction verification failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }
    
    // MARK: - Purchasing
    
    func purchase(_ product: Product) async {
        isPurchasing = true
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await syncSubscriptionWithBackendIfNeeded(transaction)
                await updateSubscriptionStatus(syncActiveTransactionToBackend: false)
                await transaction.finish()
                
            case .userCancelled:
                break
                
            case .pending:
                break
                
            @unknown default:
                break
            }
        } catch {
            errorMessage = String(
                format: L10n.text("store.error.purchase_failed"),
                error.localizedDescription
            )
        }

        isPurchasing = false
    }
    
    func restorePurchases() async {
        isPurchasing = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus(syncActiveTransactionToBackend: true)
        } catch {
            errorMessage = String(
                format: L10n.text("store.error.restore_failed"),
                error.localizedDescription
            )
        }
        
        isPurchasing = false
    }

    func refreshSubscriptionStatus() async {
        await updateSubscriptionStatus(syncActiveTransactionToBackend: false)
    }

    func ensureSubscriptionStatusReadyForFeatureGate() async {
        hydrateCachedSubscriptionStatusForCurrentUserIfNeeded()

        guard currentTier != .pro else { return }
        guard AuthService.shared.currentUserId != nil else { return }

        if AuthService.shared.confirmedUserId == nil {
            await AuthService.shared.waitForSessionResolution()
        }

        guard statusNeedsBackendConfirmationForCurrentUser else { return }
        await refreshSubscriptionStatus()
    }

    func resetForSignedOut() {
        currentTier = .free
        subscriptionExpirationDate = nil
        activeSubscriptionProductId = nil
        lastFreshSubscriptionStatusUserId = nil
        UserDefaults.standard.removeObject(forKey: Self.legacyBackendTierCacheKey)
    }

    func refreshProducts() async {
        await fetchProducts()
    }

    func subscriptionDisplayInfo(for product: Product, locale: Locale = .current) -> SubscriptionDisplayInfo {
        let billingPeriod = SubscriptionPeriodDescriptor(storeKitPeriod: product.subscription?.subscriptionPeriod)
        let introductoryOffer = IntroductoryOfferDescriptor(storeKitOffer: product.subscription?.introductoryOffer)
        return SubscriptionDisplayInfo.build(
            price: product.price,
            priceFormatStyle: product.priceFormatStyle,
            billingPeriod: billingPeriod,
            introductoryOffer: introductoryOffer,
            locale: locale
        )
    }
    
    // MARK: - Data Fetching
    
    // MARK: - App Account Token
    // Optional: Use this to link the purchase to the user account in Apple's system (obfuscated)
    private var appAccountToken: UUID? {
        guard let userId = AuthService.shared.confirmedUserId else { return nil }
        return UUID(uuidString: userId) // Simplified, ideally hash checking
    }
    
    // MARK: - Data Fetching
    
    private func fetchProducts() async {
        isLoadingProducts = true
        productsErrorMessage = nil
        do {
            let products = try await Product.products(for: productIds)
            availableProducts = products.sorted(by: { $0.price < $1.price })
            if availableProducts.isEmpty {
                productsErrorMessage = L10n.text("store.error.no_subscription_products")
            }
        } catch {
            Self.logger.error("Failed to fetch products: \(error.localizedDescription, privacy: .public)")
            productsErrorMessage = L10n.text("store.error.unable_to_load_prices")
        }
        isLoadingProducts = false
    }
    
    private func updateSubscriptionStatus(syncActiveTransactionToBackend: Bool) async {
        hydrateCachedSubscriptionStatusForCurrentUserIfNeeded()
        let userIdAtStart = AuthService.shared.currentUserId

        // 1. Check Local StoreKit Entitlements — used only to sync to backend
        var activeTransaction: Transaction? = nil
        self.subscriptionExpirationDate = nil
        self.activeSubscriptionProductId = nil
        
        // Check for active subscriptions from Apple
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if productIds.contains(transaction.productID) {
                    if let expirationDate = transaction.expirationDate, expirationDate > Date() {
                        activeTransaction = transaction
                        self.subscriptionExpirationDate = expirationDate
                        self.activeSubscriptionProductId = transaction.productID
                    }
                }
            } catch {
                Self.logger.error("Failed to verify entitlement: \(error.localizedDescription, privacy: .public)")
            }
        }
        
        // 2. Only sync entitlements when the user explicitly triggers purchase/restore.
        if syncActiveTransactionToBackend, let transaction = activeTransaction {
            await syncSubscriptionWithBackendIfNeeded(transaction)
        }
         
        // 3. Backend is the single source of truth for membership
        let backendStatus = await fetchBackendSubscriptionStatus(for: userIdAtStart)
        guard AuthService.shared.currentUserId == userIdAtStart else { return }

        self.currentTier = backendStatus.tier
        if backendStatus.tier == .pro {
            self.subscriptionExpirationDate = backendStatus.expiresAt ?? self.subscriptionExpirationDate
        }
        if backendStatus.isFreshFromBackend {
            lastFreshSubscriptionStatusUserId = userIdAtStart
        }
    }

    private func fetchBackendSubscriptionStatus(for userId: String?) async -> BackendSubscriptionSnapshot {
        guard let userId else {
            UserDefaults.standard.removeObject(forKey: Self.legacyBackendTierCacheKey)
            return BackendSubscriptionSnapshot(tier: .free, expiresAt: nil, isFreshFromBackend: false)
        }

        guard let token = await AuthService.shared.getSessionToken(), !token.isEmpty else {
            return cachedBackendStatus(for: userId)
        }

        let url = URL(string: "\(AppConfig.backendBaseURL)/subscription/status")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return cachedBackendStatus(for: userId)
            }
            guard (200...299).contains(http.statusCode) else {
                if http.statusCode == 401 || http.statusCode == 403 {
                    cacheBackendStatus(tier: .free, expiresAt: nil, for: userId)
                    return BackendSubscriptionSnapshot(tier: .free, expiresAt: nil, isFreshFromBackend: true)
                }
                return cachedBackendStatus(for: userId)
            }
            let decoded = try JSONDecoder().decode(BackendSubscriptionStatus.self, from: data)
            let expiresAt = parseBackendDate(decoded.expiresAt)
            let tier = backendTier(from: decoded.tier, expiresAt: expiresAt)
            // Cache successful result for offline fallback
            cacheBackendStatus(tier: tier, expiresAt: decoded.expiresAt, for: userId)
            UserDefaults.standard.removeObject(forKey: Self.legacyBackendTierCacheKey)
            return BackendSubscriptionSnapshot(tier: tier, expiresAt: expiresAt, isFreshFromBackend: true)
        } catch {
            // Network failure: return last known backend tier
            return cachedBackendStatus(for: userId)
        }
    }

    private var statusNeedsBackendConfirmationForCurrentUser: Bool {
        guard let userId = AuthService.shared.currentUserId else { return false }
        return lastFreshSubscriptionStatusUserId != userId
    }

    private func hydrateCachedSubscriptionStatusForLastAuthenticatedUser() {
        guard let userId = UserDefaults.standard.string(forKey: AuthService.lastAuthenticatedUserIdKey),
              !userId.isEmpty else {
            return
        }
        applyCachedSubscriptionStatus(for: userId)
    }

    private func hydrateCachedSubscriptionStatusForCurrentUserIfNeeded() {
        guard let userId = AuthService.shared.currentUserId else { return }
        guard currentTier != .pro || lastFreshSubscriptionStatusUserId != userId else { return }
        applyCachedSubscriptionStatus(for: userId)
    }

    private func applyCachedSubscriptionStatus(for userId: String) {
        let cached = cachedBackendStatus(for: userId)
        currentTier = cached.tier
        if cached.tier == .pro {
            subscriptionExpirationDate = cached.expiresAt
        } else {
            subscriptionExpirationDate = nil
        }
    }

    private func backendTierCacheKey(for userId: String) -> String {
        Self.backendTierCacheKeyPrefix + userId
    }

    private func cacheBackendStatus(tier: SubscriptionTier, expiresAt: String?, for userId: String) {
        let cached = CachedBackendSubscriptionStatus(tier: tier.rawValue, expiresAt: expiresAt)
        guard let data = try? JSONEncoder().encode(cached),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        UserDefaults.standard.set(json, forKey: backendTierCacheKey(for: userId))
    }

    private func cachedBackendStatus(for userId: String) -> BackendSubscriptionSnapshot {
        let raw = UserDefaults.standard.string(forKey: backendTierCacheKey(for: userId)) ?? SubscriptionTier.free.rawValue
        if let data = raw.data(using: .utf8),
           let cached = try? JSONDecoder().decode(CachedBackendSubscriptionStatus.self, from: data) {
            let expiresAt = parseBackendDate(cached.expiresAt)
            return BackendSubscriptionSnapshot(
                tier: backendTier(from: cached.tier, expiresAt: expiresAt),
                expiresAt: expiresAt,
                isFreshFromBackend: false
            )
        }

        let tier = SubscriptionTier(rawValue: raw) ?? .free
        return BackendSubscriptionSnapshot(tier: tier, expiresAt: nil, isFreshFromBackend: false)
    }

    private func backendTier(from rawTier: String?, expiresAt: Date?) -> SubscriptionTier {
        guard rawTier?.lowercased() == SubscriptionTier.pro.rawValue else { return .free }
        guard let expiresAt else { return .pro }
        return expiresAt > Date() ? .pro : .free
    }

    private func parseBackendDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }
        return ISO8601DateFormatter().date(from: value)
    }

    private func syncSubscriptionWithBackendIfNeeded(_ transaction: Transaction) async {
        guard AuthService.shared.confirmedUserId != nil else { return }

        do {
            try await verifySubscriptionWithBackend(transaction)
        } catch {
            if let urlError = error as? URLError, urlError.code == .dataNotAllowed {
                Self.logger.info("Backend verification skipped: network data not allowed")
            } else if String(describing: error).localizedCaseInsensitiveContains("userCancelled") {
                Self.logger.info("Backend verification skipped: user cancelled")
            } else {
                Self.logger.warning("Backend verification warning: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    private func verifySubscriptionWithBackend(_ transaction: Transaction) async throws {
        guard AuthService.shared.confirmedUserId != nil else { return }
        guard let token = await AuthService.shared.getSessionToken() else { return }
        
        let url = URL(string: "\(AppConfig.backendBaseURL)/subscription/verify")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build the verification payload.
        // On iOS 18+ the legacy app receipt is unavailable, so we send transaction
        // metadata directly. The backend should accept the request with or without
        // receiptData and can verify the transaction via Apple's Server-to-Server
        // Notifications or the App Store Server API using the transaction IDs.
        var body: [String: Any] = [
            "transactionId": String(transaction.id),
            "originalTransactionId": String(transaction.originalID),
            "productId": transaction.productID,
            "expiresDate": transaction.expirationDate?.ISO8601Format() ?? ""
        ]
        
        // Include the legacy receipt if available (pre-iOS 18).
        if let receiptData = fetchAppReceiptData() {
            body["receiptData"] = receiptData
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
             throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode != 200 {
            // Handle specific errors like 409 (Bound to another user)
            if httpResponse.statusCode == 409 {
                 self.errorMessage = L10n.text("store.error.subscription_linked_elsewhere")
            } else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let message = json["error"] as? String {
                self.errorMessage = message
                Self.logger.error("Subscription verify failed status=\(httpResponse.statusCode, privacy: .public) message=\(message, privacy: .public)")
            } else if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                Self.logger.error("Subscription verify failed status=\(httpResponse.statusCode, privacy: .public) body=\(text, privacy: .public)")
            } else {
                Self.logger.error("Subscription verify failed status=\(httpResponse.statusCode, privacy: .public)")
            }
            throw URLError(.badServerResponse)
        }
        
        // Success
        Self.logger.info("Subscription verified with backend")
    }

    private func fetchAppReceiptData() -> String? {
        if #available(iOS 18.0, *) {
            // appStoreReceiptURL is deprecated on iOS 18+; skip legacy receipt flow.
            // Current backend still supports receipt verification via pre-iOS 18 path.
            return nil
        } else {
            guard let receiptURL = Bundle.main.appStoreReceiptURL else {
                return nil
            }

            // Apple verifyReceipt expects the raw app receipt (PKCS7) in base64 form.
            guard let data = try? Data(contentsOf: receiptURL), !data.isEmpty else {
                return nil
            }
            return data.base64EncodedString()
        }
    }
    
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

}

enum StoreError: Error {
    case failedVerification
}
