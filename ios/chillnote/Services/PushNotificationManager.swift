import Foundation
import OSLog
import UIKit
import UserNotifications

enum PushNotificationDestination: Equatable {
    case note(UUID)
    case home
    case weeklyTopics
}

extension Notification.Name {
    static let pushNotificationDestinationRequested = Notification.Name(
        "pushNotification.destinationRequested"
    )
}

final class ChillScriptAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            await PushNotificationManager.shared.didRegister(deviceToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PushNotificationManager.logRegistrationFailure(error)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        PushNotificationManager.shared.handle(
            userInfo: response.notification.request.content.userInfo
        )
    }
}

@MainActor
final class PushNotificationManager {
    static let shared = PushNotificationManager()

    nonisolated private static let logger = Logger(
        subsystem: "com.chillnote.app",
        category: "push-notifications"
    )

    private(set) var pendingDestination: PushNotificationDestination?
    private var currentDeviceToken: String?

    private init() {}

    /// Quietly enrolls eligible users. Provisional authorization lets iOS show
    /// useful notifications in Notification Center before an interruptive
    /// system permission prompt is justified by real product value.
    func refreshRegistration() async {
        guard AuthService.shared.currentUserId != nil else { return }

        let center = UNUserNotificationCenter.current()
        var settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            do {
                _ = try await center.requestAuthorization(
                    options: [.alert, .sound, .badge, .provisional]
                )
                settings = await center.notificationSettings()
            } catch {
                Self.logger.error(
                    "Notification authorization request failed: \(error.localizedDescription, privacy: .public)"
                )
                return
            }
        }

        guard settings.authorizationStatus != .denied else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    func shouldOfferImportCompletionAlerts() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .provisional
    }

    func requestImportCompletionAlerts() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            UIApplication.shared.registerForRemoteNotifications()
        } catch {
            Self.logger.error(
                "Full notification authorization request failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func didRegister(deviceToken: Data) async {
        guard AuthService.shared.currentUserId != nil,
              let sessionToken = await AuthService.shared.getSessionToken(),
              !sessionToken.isEmpty else {
            return
        }

        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        currentDeviceToken = token
        guard let endpoint = URL(string: AppConfig.backendBaseURL + "/push-devices") else {
            return
        }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let payload = PushDeviceRegistrationPayload(
            token: token,
            environment: Self.apnsEnvironment,
            locale: Locale.current.identifier,
            timeZone: TimeZone.current.identifier,
            authorizationStatus: Self.authorizationStatusName(settings.authorizationStatus)
        )

        do {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 20
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(payload)
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                Self.logger.error("Push device registration returned a non-success status")
                return
            }
        } catch {
            Self.logger.error(
                "Push device registration failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func deactivateCurrentDevice() async {
        guard let token = currentDeviceToken,
              let sessionToken = await AuthService.shared.getSessionToken(),
              let endpoint = URL(string: AppConfig.backendBaseURL + "/push-devices") else {
            return
        }

        do {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "DELETE"
            request.timeoutInterval = 15
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(["token": token])
            _ = try await URLSession.shared.data(for: request)
            currentDeviceToken = nil
        } catch {
            Self.logger.error(
                "Push device deactivation failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func handle(userInfo: [AnyHashable: Any]) {
        let destination: PushNotificationDestination
        if userInfo["route"] as? String == "weekly_topics" {
            destination = .weeklyTopics
        } else if userInfo["route"] as? String == "note",
           let rawNoteID = userInfo["noteId"] as? String,
           let noteID = UUID(uuidString: rawNoteID) {
            destination = .note(noteID)
        } else {
            destination = .home
        }

        pendingDestination = destination
        NotificationCenter.default.post(
            name: .pushNotificationDestinationRequested,
            object: nil
        )
    }

    func consumePendingDestination() -> PushNotificationDestination? {
        defer { pendingDestination = nil }
        return pendingDestination
    }

    nonisolated static func logRegistrationFailure(_ error: Error) {
        logger.error(
            "APNs registration failed: \(error.localizedDescription, privacy: .public)"
        )
    }

    private static var apnsEnvironment: String {
        #if DEBUG
        "sandbox"
        #else
        "production"
        #endif
    }

    private static func authorizationStatusName(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            "not_determined"
        case .denied:
            "denied"
        case .authorized:
            "authorized"
        case .provisional:
            "provisional"
        case .ephemeral:
            "ephemeral"
        @unknown default:
            "unknown"
        }
    }
}

private struct PushDeviceRegistrationPayload: Encodable {
    let token: String
    let environment: String
    let locale: String
    let timeZone: String
    let authorizationStatus: String
}
