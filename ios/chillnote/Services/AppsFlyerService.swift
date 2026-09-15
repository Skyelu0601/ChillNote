import AppsFlyerLib
import Foundation
import OSLog
import UIKit

struct AppsFlyerInstallAttribution {
    let mediaSource: String?
    let campaign: String?
    let adGroup: String?
    let ad: String?

    init(conversionData: [AnyHashable: Any]) {
        func string(_ key: String) -> String? {
            guard let value = conversionData[key] else { return nil }
            let normalized = String(describing: value)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return normalized.isEmpty ? nil : normalized
        }

        mediaSource = string("media_source")
        campaign = string("campaign")
        adGroup = string("af_adset")
        ad = string("af_ad")
    }
}

final class AppsFlyerService: NSObject, AppsFlyerLibDelegate {
    static let shared = AppsFlyerService()

    private static let appleAppID = "6758427839"
    private static let logger = Logger(subsystem: "com.chillnote.app", category: "appsflyer")
    private var isConfigured = false

    private override init() {}

    @MainActor
    func configure(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        guard !isConfigured else { return }
        guard let devKey = AppConfig.appsFlyerDevKey else {
            Self.logger.notice("AppsFlyer is disabled because APPSFLYER_DEV_KEY is missing")
            return
        }

        let appsFlyer = AppsFlyerLib.shared()
        appsFlyer.initialize(devKey: devKey, appId: Self.appleAppID)
        appsFlyer.delegate = self
        appsFlyer.customerUserID = AuthService.shared.currentUserId.map(RevenueCatIdentity.canonicalUserID)
        appsFlyer.handleLaunchOptions(launchOptions)
#if DEBUG
        appsFlyer.isDebug = true
#endif
        appsFlyer.registerSessionReadyListener { [weak self] in
            AppsFlyerLib.shared().start()
            self?.syncDeviceIdentifiersToRevenueCat()
        }
        isConfigured = true
    }

    @MainActor
    func identify(userID: String?) {
        guard isConfigured else { return }
        AppsFlyerLib.shared().customerUserID = userID.map(RevenueCatIdentity.canonicalUserID)
        syncDeviceIdentifiersToRevenueCat()
    }

    func onConversionDataSuccess(_ conversionData: [AnyHashable: Any]) {
        let status = String(describing: conversionData["af_status"] ?? "")
        let attribution = status.caseInsensitiveCompare("Non-organic") == .orderedSame
            ? AppsFlyerInstallAttribution(conversionData: conversionData)
            : nil

        Task { @MainActor in
            RevenueCatService.shared.setAppsFlyerAttribution(
                appsFlyerID: AppsFlyerLib.shared().getAppsFlyerUID(),
                attribution: attribution
            )
        }
    }

    func onConversionDataFail(_ error: Error) {
        Self.logger.warning(
            "AppsFlyer conversion data failed: \(error.localizedDescription, privacy: .public)"
        )
        syncDeviceIdentifiersToRevenueCat()
    }

    private func syncDeviceIdentifiersToRevenueCat() {
        let appsFlyerID = AppsFlyerLib.shared().getAppsFlyerUID()
        Task { @MainActor in
            RevenueCatService.shared.setAppsFlyerAttribution(
                appsFlyerID: appsFlyerID,
                attribution: nil
            )
        }
    }
}
