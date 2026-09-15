import Foundation
import PostHog

/// Product metadata only. Never pass note content, URLs, email, audio, or error messages.
@MainActor
final class ProductAnalytics {
    static let shared = ProductAnalytics()
    private let identityKey = "analytics.posthog.userID"
    private let firstOpenKey = "analytics.posthog.firstOpenCaptured"
    private let completedOperationsKey = "analytics.posthog.completedOperations"
    private let shareEventQueueKey = "analytics.posthog.shareEventQueue"
    private let appGroupIdentifier = "group.com.sponteoai.chillnote"
    private var configured = false

    private struct QueuedShareEvent: Codable {
        let name: String
        let properties: [String: String]
        let occurredAt: Date
    }

    func configure(userID: String?) {
        guard !configured,
              ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
              ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1",
              !ProcessInfo.processInfo.arguments.contains(where: { $0.contains("design-preview") }) else { return }
        // Public ingestion token, not a personal/admin API key.
        let config = PostHogConfig(
            projectToken: "phc_pYcofJNTakcLUaB2pC6jAEDyiz53CVkoULFu6SpAeWkM",
            host: "https://us.i.posthog.com"
        )
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = false
        config.captureElementInteractions = false
        config.enableSwizzling = false
        config.sessionReplay = false
        config.errorTrackingConfig.autoCapture = true
        config.surveys = false
        config.preloadFeatureFlags = false
        config.setBeforeSend { event in
            event.properties["platform"] = "ios"
            event.properties["schema_version"] = 1
            event.properties["$geoip_disable"] = true
#if DEBUG
            event.properties["environment"] = "development"
#else
            event.properties["environment"] = "production"
#endif
            if event.event == "$exception" {
                event.properties = CrashEventSanitizer.sanitize(event.properties)
            }
            return event
        }
        PostHogSDK.shared.setup(config)
        configured = true
        synchronizeUser(userID)
        capture("app_session_started", properties: ["surface": "main_app"])
        if !UserDefaults.standard.bool(forKey: firstOpenKey) {
            let existingInstall = UserDefaults.standard.bool(forKey: "onboarding.introViewedOnDevice")
                || userID != nil
            if !existingInstall {
                capture("app_first_opened", properties: ["surface": "main_app"])
            }
            UserDefaults.standard.set(true, forKey: firstOpenKey)
        }
        drainShareExtensionEvents()
#if DEBUG
        // Opt-in simulator smoke test. Launch without a debugger, then relaunch without this argument.
        if ProcessInfo.processInfo.arguments.contains("--posthog-crash-smoke-test") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                fatalError("PostHog crash smoke test")
            }
        }
#endif
    }

    func synchronizeUser(_ userID: String?) {
        guard configured else { return }
        let normalizedID = userID?.lowercased()
        let previousID = UserDefaults.standard.string(forKey: identityKey)
        if previousID != nil && previousID != normalizedID {
            PostHogSDK.shared.reset()
        }
        if let normalizedID {
            // Lowercase UUIDs match Android for cross-platform identity.
            PostHogSDK.shared.identify(normalizedID)
        }
        UserDefaults.standard.set(normalizedID, forKey: identityKey)
    }

    func capture(_ event: String, properties: [String: Any] = [:]) {
        guard configured else { return }
        PostHogSDK.shared.capture(event, properties: properties)
    }

    /// Sends events queued by the share extension when the main app becomes active.
    func flushPendingShareExtensionEvents() {
        guard configured else { return }
        drainShareExtensionEvents()
    }

    /// Emits one durable creation success per business operation, even if UI callbacks repeat.
    func captureCreationCompleted(
        operationID: String,
        type: String,
        entryPoint: String,
        properties: [String: Any] = [:]
    ) {
        guard configured else { return }
        var completed = Set(UserDefaults.standard.stringArray(forKey: completedOperationsKey) ?? [])
        guard completed.insert(operationID).inserted else { return }
        UserDefaults.standard.set(Array(completed.suffix(250)), forKey: completedOperationsKey)
        capture(
            "creation_completed",
            properties: properties.merging([
                "operation_id": operationID,
                "creation_type": type,
                "entry_point": entryPoint,
                "surface": "main_app"
            ]) { current, _ in current }
        )
    }

    private func drainShareExtensionEvents() {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = sharedDefaults.data(forKey: shareEventQueueKey),
              let events = try? JSONDecoder().decode([QueuedShareEvent].self, from: data),
              !events.isEmpty else { return }

        sharedDefaults.removeObject(forKey: shareEventQueueKey)
        for event in events {
            var properties: [String: Any] = event.properties
            properties["surface"] = "ios_share_extension"
            properties["occurred_at"] = ISO8601DateFormatter().string(from: event.occurredAt)
            capture(event.name, properties: properties)
        }
    }
}
