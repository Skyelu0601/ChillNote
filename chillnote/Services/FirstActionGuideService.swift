import Foundation
import Combine

@MainActor
final class FirstActionGuideService: ObservableObject {
    enum Stage: String, Equatable {
        case inactive
        case sharePrompt
        case awaitingShare
        case waitingForImport
        case openImportedNote
        case reviewTranscript
        case tapCreateTab
        case tapAISkills
        case waitingForAISkillsDismissal
        case tapRecordTab
        case tapTeleprompter
        case completed
        case dismissed
    }

    static let shared = FirstActionGuideService()

    @Published private(set) var stage: Stage = .inactive
    @Published private(set) var targetNoteID: UUID?

    private let defaults: UserDefaults
    private let now: () -> Date
    private let newAccountWindow: TimeInterval
    private var currentUserId: String?

    private let stageMapKey = "onboarding.firstAction.stageByUserId"
    private let noteMapKey = "onboarding.firstAction.noteByUserId"

    init(
        defaults: UserDefaults = .standard,
        newAccountWindow: TimeInterval = 24 * 60 * 60,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.newAccountWindow = newAccountWindow
        self.now = now
    }

    var isWaitingForSharedVideo: Bool {
        stage == .sharePrompt || stage == .awaitingShare
    }

    func configure(userId: String, accountCreatedAt: Date?) {
        if currentUserId == userId {
            activateForFreshAccountIfNeeded(accountCreatedAt: accountCreatedAt)
            return
        }

        currentUserId = userId
        targetNoteID = storedTargetNoteID(for: userId)

        if let storedStage = storedStage(for: userId) {
            stage = storedStage
            return
        }

        stage = .inactive
        activateForFreshAccountIfNeeded(accountCreatedAt: accountCreatedAt)
    }

    func acknowledgeSharePrompt() {
        guard stage == .sharePrompt else { return }
        transition(to: .awaitingShare)
    }

    func registerSharedVideoImport(noteID: UUID) {
        guard isWaitingForSharedVideo else { return }
        targetNoteID = noteID
        transition(to: .waitingForImport)
    }

    func updateTargetImportStatus(_ status: NoteImportStatus) {
        guard stage == .waitingForImport, targetNoteID != nil else { return }

        switch status {
        case .completed:
            transition(to: .openImportedNote)
        case .failed:
            targetNoteID = nil
            transition(to: .sharePrompt)
        case .none, .queued, .processing:
            break
        }
    }

    func markImportedNoteOpened(_ noteID: UUID) {
        guard stage == .openImportedNote, targetNoteID == noteID else { return }
        transition(to: .reviewTranscript)
    }

    func markTranscriptReviewed(in noteID: UUID) {
        guard stage == .reviewTranscript, targetNoteID == noteID else { return }
        transition(to: .tapCreateTab)
    }

    func markCreateTabTapped(in noteID: UUID) {
        guard stage == .tapCreateTab, targetNoteID == noteID else { return }
        transition(to: .tapAISkills)
    }

    func markAISkillsTapped(in noteID: UUID) {
        guard stage == .tapAISkills, targetNoteID == noteID else { return }
        transition(to: .waitingForAISkillsDismissal)
    }

    func markAISkillsFlowDismissed(in noteID: UUID) {
        guard stage == .waitingForAISkillsDismissal, targetNoteID == noteID else { return }
        transition(to: .tapRecordTab)
    }

    func markRecordTabTapped(in noteID: UUID) {
        guard stage == .tapRecordTab, targetNoteID == noteID else { return }
        transition(to: .tapTeleprompter)
    }

    func markTeleprompterTapped(in noteID: UUID) {
        guard stage == .tapTeleprompter, targetNoteID == noteID else { return }
        transition(to: .completed)
    }

    func dismiss() {
        transition(to: .dismissed)
    }

    func resetForSignedOutUser() {
        currentUserId = nil
        stage = .inactive
        targetNoteID = nil
    }

    private func activateForFreshAccountIfNeeded(accountCreatedAt: Date?) {
        guard stage == .inactive, storedStage(for: currentUserId) == nil else { return }
        guard let accountCreatedAt else { return }

        let accountAge = now().timeIntervalSince(accountCreatedAt)
        guard accountAge >= 0, accountAge <= newAccountWindow else { return }
        transition(to: .sharePrompt)
    }

    private func transition(to newStage: Stage) {
        stage = newStage
        persistCurrentState()
    }

    private func storedStage(for userId: String?) -> Stage? {
        guard let userId,
              let map = defaults.dictionary(forKey: stageMapKey) as? [String: String],
              let rawValue = map[userId] else {
            return nil
        }
        return Stage(rawValue: rawValue)
    }

    private func storedTargetNoteID(for userId: String) -> UUID? {
        guard let map = defaults.dictionary(forKey: noteMapKey) as? [String: String],
              let rawValue = map[userId] else {
            return nil
        }
        return UUID(uuidString: rawValue)
    }

    private func persistCurrentState() {
        guard let currentUserId else { return }

        var stageMap = defaults.dictionary(forKey: stageMapKey) as? [String: String] ?? [:]
        stageMap[currentUserId] = stage.rawValue
        defaults.set(stageMap, forKey: stageMapKey)

        var noteMap = defaults.dictionary(forKey: noteMapKey) as? [String: String] ?? [:]
        if let targetNoteID {
            noteMap[currentUserId] = targetNoteID.uuidString
        } else {
            noteMap.removeValue(forKey: currentUserId)
        }
        defaults.set(noteMap, forKey: noteMapKey)
    }
}
