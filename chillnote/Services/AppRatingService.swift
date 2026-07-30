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
    private let countedLinkImportNoteIDsKey = "app_rating.counted_link_import_note_ids"
    private let promptThreshold = 1

    private init() {}

    func registerSuccessfulVoiceNoteSave() -> Bool {
        registerSuccessfulEvent()
    }

    func registerSuccessfulLinkImportCompletion(noteID: UUID) -> Bool {
        guard !hasTriggeredPrompt else { return false }

        var countedNoteIDs = countedLinkImportNoteIDs
        let noteIDString = noteID.uuidString
        guard !countedNoteIDs.contains(noteIDString) else { return false }

        countedNoteIDs.insert(noteIDString)
        countedLinkImportNoteIDs = countedNoteIDs

        return registerSuccessfulEvent()
    }

    private func registerSuccessfulEvent() -> Bool {
        guard !hasTriggeredPrompt else { return false }

        successfulEventCount += 1

        guard successfulEventCount >= promptThreshold else {
            return false
        }

        hasTriggeredPrompt = true
        return true
    }

    func requestInAppReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return
        }

        SKStoreReviewController.requestReview(in: scene)
    }

    func openFeedbackEmail() {
        guard let url = URL(string: "mailto:support@chillnoteai.com?subject=ChillScript%20Feedback") else {
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
        get { UserDefaults.standard.bool(forKey: hasTriggeredPromptKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasTriggeredPromptKey) }
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
}
