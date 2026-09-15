import Foundation
import StoreKit
import UIKit

@MainActor
final class AppRatingService: ObservableObject {
    static let shared = AppRatingService()

    private let successfulEventCountKey = "app_rating.successful_event_count"
    private let legacySuccessfulVoiceNoteCountKey = "app_rating.successful_voice_note_count"
    private let didMigrateLegacyVoiceNoteCountKey = "app_rating.did_migrate_legacy_voice_note_count"
    private let hasTriggeredPromptKey = "app_rating.has_triggered_prompt"
    private let promptAttemptDatesKey = "app_rating.prompt_attempt_dates"
    private let lastPromptEventCountKey = "app_rating.last_prompt_event_count"
    private let didMigratePromptScheduleKey = "app_rating.did_migrate_prompt_schedule"
    private let countedLinkImportNoteIDsKey = "app_rating.counted_link_import_note_ids"

    private init() {}

    func registerSuccessfulVoiceNoteSave() -> Bool {
        registerSuccessfulEvent(trigger: "voice_note")
    }

    func registerSuccessfulLinkImportCompletion(noteID: UUID) -> Bool {
        var countedNoteIDs = countedLinkImportNoteIDs
        let noteIDString = noteID.uuidString
        guard !countedNoteIDs.contains(noteIDString) else { return false }

        countedNoteIDs.insert(noteIDString)
        countedLinkImportNoteIDs = countedNoteIDs

        return registerSuccessfulEvent(trigger: "link_import")
    }

    private func registerSuccessfulEvent(trigger: String, now: Date = Date()) -> Bool {
        migrateLegacyPromptScheduleIfNeeded(now: now)
        successfulEventCount += 1

        let recentAttempts = promptAttemptDates.filter {
            now.timeIntervalSince($0) < AppRatingPromptPolicy.attemptWindow
        }
        promptAttemptDates = recentAttempts
        guard AppRatingPromptPolicy.shouldRequest(
            successfulEventCount: successfulEventCount,
            attemptDates: recentAttempts,
            lastAttemptEventCount: lastPromptEventCount,
            now: now
        ) else { return false }

        promptAttemptDates = recentAttempts + [now]
        lastPromptEventCount = successfulEventCount
        ProductAnalytics.shared.capture("rating_prompt_eligible", properties: [
            "attempt_index": recentAttempts.count + 1,
            "successful_event_count": successfulEventCount,
            "trigger": trigger
        ])
        return true
    }

    func requestInAppReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return
        }

        ProductAnalytics.shared.capture("rating_prompt_requested", properties: [
            "attempt_index": promptAttemptDates.count
        ])
        SKStoreReviewController.requestReview(in: scene)
    }

    func openFeedbackEmail() {
        guard let url = URL(string: "mailto:support@chillnoteai.com?subject=ChillScript%20Feedback") else {
            return
        }

        UIApplication.shared.open(url)
    }

    func openAppStoreReview() {
        guard let url = URL(string: "https://apps.apple.com/app/id6758427839?action=write-review") else {
            return
        }

        UIApplication.shared.open(url)
    }
}

private extension AppRatingService {
    var successfulEventCount: Int {
        get {
            migrateLegacyVoiceNoteCountIfNeeded()
            return UserDefaults.standard.integer(forKey: successfulEventCountKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: successfulEventCountKey) }
    }

    var hasTriggeredPrompt: Bool {
        UserDefaults.standard.bool(forKey: hasTriggeredPromptKey)
    }

    var promptAttemptDates: [Date] {
        get {
            (UserDefaults.standard.array(forKey: promptAttemptDatesKey) as? [Double] ?? [])
                .map(Date.init(timeIntervalSince1970:))
        }
        set {
            UserDefaults.standard.set(newValue.map(\.timeIntervalSince1970), forKey: promptAttemptDatesKey)
        }
    }

    var lastPromptEventCount: Int {
        get { UserDefaults.standard.integer(forKey: lastPromptEventCountKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastPromptEventCountKey) }
    }

    var countedLinkImportNoteIDs: Set<String> {
        get {
            let ids = UserDefaults.standard.stringArray(forKey: countedLinkImportNoteIDsKey) ?? []
            return Set(ids)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: countedLinkImportNoteIDsKey)
        }
    }

    func migrateLegacyVoiceNoteCountIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: didMigrateLegacyVoiceNoteCountKey) else { return }

        let legacyCount = UserDefaults.standard.integer(forKey: legacySuccessfulVoiceNoteCountKey)
        if legacyCount > UserDefaults.standard.integer(forKey: successfulEventCountKey) {
            UserDefaults.standard.set(legacyCount, forKey: successfulEventCountKey)
        }
        UserDefaults.standard.set(true, forKey: didMigrateLegacyVoiceNoteCountKey)
    }

    func migrateLegacyPromptScheduleIfNeeded(now: Date) {
        guard !UserDefaults.standard.bool(forKey: didMigratePromptScheduleKey) else { return }

        if promptAttemptDates.isEmpty, hasTriggeredPrompt {
            // Older versions permanently stopped after one request. Treat that request as old
            // enough to retry, while still requiring fresh successful activity after updating.
            promptAttemptDates = [now.addingTimeInterval(-AppRatingPromptPolicy.repeatInterval)]
            lastPromptEventCount = successfulEventCount
        }
        UserDefaults.standard.set(true, forKey: didMigratePromptScheduleKey)
    }
}

enum AppRatingPromptPolicy {
    static let repeatInterval: TimeInterval = 30 * 24 * 60 * 60
    static let attemptWindow: TimeInterval = 365 * 24 * 60 * 60
    static let additionalEventsForRetry = 3
    static let maximumAttemptsPerWindow = 3

    static func shouldRequest(
        successfulEventCount: Int,
        attemptDates: [Date],
        lastAttemptEventCount: Int,
        now: Date
    ) -> Bool {
        if attemptDates.isEmpty {
            return successfulEventCount >= 1
        }
        guard attemptDates.count < maximumAttemptsPerWindow,
              let lastAttemptDate = attemptDates.max(),
              now.timeIntervalSince(lastAttemptDate) >= repeatInterval else { return false }

        return successfulEventCount - lastAttemptEventCount >= additionalEventsForRetry
    }
}
