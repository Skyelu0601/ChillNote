import Foundation
import StoreKit
import UIKit

@MainActor
final class AppRatingService: ObservableObject {
    static let shared = AppRatingService()

    private let successfulVoiceNoteCountKey = "app_rating.successful_voice_note_count"
    private let hasTriggeredPromptKey = "app_rating.has_triggered_prompt"
    private let voiceNotePromptThreshold = 3

    private init() {}

    func registerSuccessfulVoiceNoteSave() -> Bool {
        guard !hasTriggeredPrompt else { return false }

        successfulVoiceNoteCount += 1

        guard successfulVoiceNoteCount >= voiceNotePromptThreshold else {
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
        guard let url = URL(string: "mailto:support@chillnoteai.com?subject=ChillNote%20Feedback") else {
            return
        }

        UIApplication.shared.open(url)
    }
}

private extension AppRatingService {
    var successfulVoiceNoteCount: Int {
        get { UserDefaults.standard.integer(forKey: successfulVoiceNoteCountKey) }
        set { UserDefaults.standard.set(newValue, forKey: successfulVoiceNoteCountKey) }
    }

    var hasTriggeredPrompt: Bool {
        get { UserDefaults.standard.bool(forKey: hasTriggeredPromptKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasTriggeredPromptKey) }
    }
}
