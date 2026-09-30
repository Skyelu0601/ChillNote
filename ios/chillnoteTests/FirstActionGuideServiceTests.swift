import XCTest
@testable import chillnote

@MainActor
final class FirstActionGuideServiceTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "FirstActionGuideServiceTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testFreshAccountStartsWithSharePrompt() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let service = makeService(now: now)

        service.configure(
            userId: "new-user",
            accountCreatedAt: now.addingTimeInterval(-60)
        )

        XCTAssertEqual(service.stage, .sharePrompt)
    }

    func testExistingAccountDoesNotReceiveGuide() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let service = makeService(now: now)

        service.configure(
            userId: "existing-user",
            accountCreatedAt: now.addingTimeInterval(-(25 * 60 * 60))
        )

        XCTAssertEqual(service.stage, .inactive)
    }

    func testSharedVideoAdvancesOnlyAfterImportCompletes() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let service = makeService(now: now)
        let noteID = UUID()

        service.configure(userId: "new-user", accountCreatedAt: now)
        service.acknowledgeSharePrompt()
        service.registerSharedVideoImport(noteID: noteID)

        XCTAssertEqual(service.stage, .waitingForImport)
        XCTAssertEqual(service.targetNoteID, noteID)

        service.updateTargetImportStatus(.processing)
        XCTAssertEqual(service.stage, .waitingForImport)

        service.updateTargetImportStatus(.completed)
        XCTAssertEqual(service.stage, .openImportedNote)
    }

    func testGuideCompletesInOrderAndPersists() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let noteID = UUID()
        let service = makeService(now: now)

        service.configure(userId: "new-user", accountCreatedAt: now)
        service.registerSharedVideoImport(noteID: noteID)
        service.updateTargetImportStatus(.completed)
        service.markImportedNoteOpened(noteID)
        service.markTranscriptReviewed(in: noteID)
        service.markCreateTabTapped(in: noteID)
        service.markAISkillsTapped(in: noteID)
        service.reconcileConversation(in: noteID, hasReply: true)
        XCTAssertEqual(service.stage, .tapRecordTab)
        service.markRecordTabTapped(in: noteID)
        service.markTeleprompterTapped(in: noteID)

        XCTAssertEqual(service.stage, .completed)

        let restored = makeService(now: now)
        restored.configure(userId: "new-user", accountCreatedAt: now)
        XCTAssertEqual(restored.stage, .completed)
        XCTAssertEqual(restored.targetNoteID, noteID)
    }

    func testNewEditorGuideRequiresWorkspaceTabsInOrder() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let noteID = UUID()
        let service = makeService(now: now)

        service.configure(userId: "new-user", accountCreatedAt: now)
        service.registerSharedVideoImport(noteID: noteID)
        service.updateTargetImportStatus(.completed)
        service.markImportedNoteOpened(noteID)

        XCTAssertEqual(service.stage, .reviewTranscript)
        service.markCreateTabTapped(in: noteID)
        XCTAssertEqual(service.stage, .reviewTranscript)

        service.markTranscriptReviewed(in: noteID)
        XCTAssertEqual(service.stage, .tapCreateTab)
        service.markAISkillsTapped(in: noteID)
        XCTAssertEqual(service.stage, .tapCreateTab)

        service.markCreateTabTapped(in: noteID)
        service.markAISkillsTapped(in: noteID)
        service.reconcileConversation(in: noteID, hasReply: true)
        XCTAssertEqual(service.stage, .tapRecordTab)
        XCTAssertEqual(service.stage, .tapRecordTab)

        service.markTeleprompterTapped(in: noteID)
        XCTAssertEqual(service.stage, .tapRecordTab)

        service.markRecordTabTapped(in: noteID)
        service.markTeleprompterTapped(in: noteID)
        XCTAssertEqual(service.stage, .completed)
    }

    func testFailedOrCancelledReplyCanRetryAndSuccessAdvancesDirectlyToRecord() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let noteID = UUID()
        let service = makeService(now: now)
        service.configure(userId: "new-user", accountCreatedAt: now)
        service.registerSharedVideoImport(noteID: noteID)
        service.updateTargetImportStatus(.completed)
        service.markImportedNoteOpened(noteID)
        service.markTranscriptReviewed(in: noteID)
        service.markCreateTabTapped(in: noteID)
        service.markAISkillsTapped(in: noteID)
        XCTAssertEqual(service.stage, .waitingForAISkillsDismissal)
        service.reconcileConversation(in: noteID, hasReply: false)
        XCTAssertEqual(service.stage, .tapAISkills)
        // Retrying the failed chat turn and a freeform first message both bypass the skill button.
        service.reconcileConversation(in: noteID, hasReply: true)
        XCTAssertEqual(service.stage, .tapRecordTab)
        service.reconcileConversation(in: noteID, hasReply: true)
        XCTAssertEqual(service.stage, .tapRecordTab)
    }

    func testRestoresLegacyWaitingStateAndRecoversMissingLocalReply() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let noteID = UUID()
        defaults.set(["new-user": "waitingForAISkillsDismissal"], forKey: "onboarding.firstAction.stageByUserId")
        defaults.set(["new-user": noteID.uuidString], forKey: "onboarding.firstAction.noteByUserId")
        let service = makeService(now: now)
        service.configure(userId: "new-user", accountCreatedAt: now)
        XCTAssertEqual(service.stage, .waitingForAISkillsDismissal)
        service.reconcileConversation(in: noteID, hasReply: true)
        let restored = makeService(now: now)
        restored.configure(userId: "new-user", accountCreatedAt: now)
        XCTAssertEqual(restored.stage, .tapRecordTab)
        // A previous build's removed review step is reconciled without showing its banner.
        for hasReply in [false, true] {
            defaults.set(["new-user": "reviewAIReply"], forKey: "onboarding.firstAction.stageByUserId")
            let legacy = makeService(now: now)
            legacy.configure(userId: "new-user", accountCreatedAt: now)
            legacy.reconcileConversation(in: noteID, hasReply: hasReply)
            XCTAssertEqual(legacy.stage, hasReply ? .tapRecordTab : .tapAISkills)
        }
    }

    func testOtherNotesAndDismissedGuideCannotAdvance() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let service = makeService(now: now)
        service.configure(userId: "new-user", accountCreatedAt: now)
        let noteID = UUID()
        service.registerSharedVideoImport(noteID: noteID)
        service.reconcileConversation(in: UUID(), hasReply: true)
        XCTAssertEqual(service.stage, .waitingForImport)
        service.dismiss()
        service.reconcileConversation(in: noteID, hasReply: true)
        XCTAssertEqual(service.stage, .dismissed)
    }

    private func makeService(now: Date) -> FirstActionGuideService {
        FirstActionGuideService(
            defaults: defaults,
            newAccountWindow: 24 * 60 * 60,
            now: { now }
        )
    }
}
