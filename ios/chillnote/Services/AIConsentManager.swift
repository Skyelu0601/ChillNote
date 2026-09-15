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
            L10n.text("ai_consent.before_using_ai")
        }

        var summary: String {
            switch self {
            case .audio:
                return L10n.text("ai_consent.trigger.audio_summary")
            case .text:
                return L10n.text("ai_consent.trigger.text_summary")
            }
        }
    }

    struct Prompt: Identifiable, Equatable {
        let id = UUID()
        let trigger: Trigger
    }

    @Published private(set) var activePrompt: Prompt?

    private let userDefaults: UserDefaults
    private var pendingContinuations: [UUID: CheckedContinuation<Bool, Never>] = [:]
    private let capture: @MainActor (String, [String: Any]) -> Void

    var hasAcceptedAIDataConsent: Bool {
        userDefaults.string(forKey: Self.acceptedVersionKey) == Self.currentConsentVersion
    }

    init(
        userDefaults: UserDefaults = .standard,
        capture: @escaping @MainActor (String, [String: Any]) -> Void = {
            ProductAnalytics.shared.capture($0, properties: $1)
        }
    ) {
        self.userDefaults = userDefaults
        self.capture = capture
    }

    func ensureConsentIfNeeded(for trigger: Trigger) async -> Bool {
        guard !Task.isCancelled else { return false }
        guard !hasAcceptedAIDataConsent else { return true }
        let requestID = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(returning: false)
                    return
                }
                pendingContinuations[requestID] = continuation
                if activePrompt == nil {
                    let prompt = Prompt(trigger: trigger)
                    activePrompt = prompt
                    capture("ai_consent_prompted", properties(for: prompt))
                }
            }
        } onCancel: {
            Task { @MainActor in self.cancelRequest(requestID) }
        }
    }

    func acceptAIDataConsent(promptID: UUID? = nil) {
        guard let prompt = activePrompt, promptID == nil || promptID == prompt.id else { return }
        userDefaults.set(Self.currentConsentVersion, forKey: Self.acceptedVersionKey)
        userDefaults.set(Date().timeIntervalSince1970, forKey: Self.acceptedAtKey)
        capture("ai_consent_accepted", properties(for: prompt))
        completePendingRequests(with: true)
    }

    func declineAIDataConsent(promptID: UUID? = nil) {
        guard let prompt = activePrompt, promptID == nil || promptID == prompt.id else { return }
        capture("ai_consent_declined", properties(for: prompt))
        completePendingRequests(with: false)
    }

    private func properties(for prompt: Prompt) -> [String: Any] {
        ["trigger": prompt.trigger == .audio ? "audio" : "text",
         "consent_version": Self.currentConsentVersion, "diagnostic_schema": 2]
    }

    private func cancelRequest(_ id: UUID) {
        let continuation = pendingContinuations.removeValue(forKey: id)
        if pendingContinuations.isEmpty { activePrompt = nil }
        continuation?.resume(returning: false)
    }

    private func completePendingRequests(with value: Bool) {
        let continuations = Array(pendingContinuations.values)
        pendingContinuations.removeAll()
        activePrompt = nil
        continuations.forEach { $0.resume(returning: value) }
    }
}
