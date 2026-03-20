import Foundation

@MainActor
final class AIConsentManager: ObservableObject {
    static let shared = AIConsentManager()

    static let currentConsentVersion = "v1"
    static let acceptedVersionKey = "ai_data_consent_version_accepted"
    static let acceptedAtKey = "ai_data_consent_accepted_at"

    enum Trigger: Equatable {
        case audio
        case text

        var title: String {
            String(localized: "Before using AI")
        }

        var summary: String {
            switch self {
            case .audio:
                return String(localized: "To transcribe your voice note, ChillNote may send your audio and essential technical details to ChillNote's secure server and to Google Gemini for processing.")
            case .text:
                return String(localized: "To improve your note, ChillNote may send the text you choose to ChillNote's secure server and to Google Gemini for processing.")
            }
        }
    }

    struct Prompt: Identifiable, Equatable {
        let id = UUID()
        let trigger: Trigger
    }

    @Published private(set) var activePrompt: Prompt?

    private let userDefaults: UserDefaults
    private var pendingContinuations: [CheckedContinuation<Bool, Never>] = []

    var hasAcceptedAIDataConsent: Bool {
        userDefaults.string(forKey: Self.acceptedVersionKey) == Self.currentConsentVersion
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        resetIfVersionChanges()
    }

    func resetIfVersionChanges() {
        let acceptedVersion = userDefaults.string(forKey: Self.acceptedVersionKey)
        guard acceptedVersion != Self.currentConsentVersion else { return }
        activePrompt = nil
    }

    func ensureConsentIfNeeded(for trigger: Trigger) async -> Bool {
        resetIfVersionChanges()
        guard !hasAcceptedAIDataConsent else { return true }

        if activePrompt == nil {
            activePrompt = Prompt(trigger: trigger)
        }

        return await withCheckedContinuation { continuation in
            pendingContinuations.append(continuation)
        }
    }

    func acceptAIDataConsent() {
        userDefaults.set(Self.currentConsentVersion, forKey: Self.acceptedVersionKey)
        userDefaults.set(Date().timeIntervalSince1970, forKey: Self.acceptedAtKey)
        completePendingRequests(with: true)
    }

    func declineAIDataConsent() {
        completePendingRequests(with: false)
    }

    private func completePendingRequests(with value: Bool) {
        let continuations = pendingContinuations
        pendingContinuations.removeAll()
        activePrompt = nil
        continuations.forEach { $0.resume(returning: value) }
    }
}
