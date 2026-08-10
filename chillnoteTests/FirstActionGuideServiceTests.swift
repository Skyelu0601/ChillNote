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
        service.markAISkillsTapped(in: noteID)
        service.markAISkillsFlowDismissed(in: noteID)
        service.markTeleprompterTapped(in: noteID)

        XCTAssertEqual(service.stage, .completed)

        let restored = makeService(now: now)
        restored.configure(userId: "new-user", accountCreatedAt: now)
        XCTAssertEqual(restored.stage, .completed)
        XCTAssertEqual(restored.targetNoteID, noteID)
    }

    private func makeService(now: Date) -> FirstActionGuideService {
        FirstActionGuideService(
            defaults: defaults,
            newAccountWindow: 24 * 60 * 60,
            now: { now }
        )
    }
}
