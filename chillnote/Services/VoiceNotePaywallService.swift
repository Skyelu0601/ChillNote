import Foundation

@MainActor
final class VoiceNotePaywallService: ObservableObject {
    static let shared = VoiceNotePaywallService()

    @Published private(set) var shouldShowPaywall = false

    private let hasCompletedFirstVoiceSaveKey = "has_completed_first_voice_save"

    private init() {}

    func registerSuccessfulVoiceNoteSave() {
        guard !hasCompletedFirstVoiceSave else { return }

        hasCompletedFirstVoiceSave = true

        Task {
            await StoreService.shared.ensureSubscriptionStatusReadyForFeatureGate()
            guard StoreService.shared.currentTier == .free else { return }
            shouldShowPaywall = true
        }
    }

    func consumePaywallRequest() {
        shouldShowPaywall = false
    }

    private var hasCompletedFirstVoiceSave: Bool {
        get { UserDefaults.standard.bool(forKey: hasCompletedFirstVoiceSaveKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasCompletedFirstVoiceSaveKey) }
    }
}
