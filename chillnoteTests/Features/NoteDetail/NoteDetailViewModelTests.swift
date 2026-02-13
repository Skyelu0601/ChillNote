import XCTest
import SwiftData
@testable import chillnote

@MainActor
final class NoteDetailViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([Note.self, Tag.self, ChecklistItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    func testUpdateTimestampAndDismissWhenContentChanged() {
        let originalTime = Date(timeIntervalSince1970: 100)
        let updatedTime = Date(timeIntervalSince1970: 200)
        let note = Note(content: "old", userId: "u1")
        note.updatedAt = originalTime
        context.insert(note)

        var didDismiss = false
        var deps = NoteDetailViewModel.Dependencies()
        deps.now = { updatedTime }

        let viewModel = NoteDetailViewModel(note: note, dependencies: deps)
        viewModel.configureForTesting(modelContext: context) {
            didDismiss = true
        }

        note.content = "new"
        viewModel.updateTimestampAndDismiss()

        XCTAssertEqual(note.updatedAt, updatedTime)
        XCTAssertTrue(didDismiss)
    }

    func testUpdateTimestampAndDismissDeletesWhenContentEmpty() {
        let note = Note(content: "text", userId: "u1")
        context.insert(note)

        var didDismiss = false
        let viewModel = NoteDetailViewModel(note: note)
        viewModel.configureForTesting(modelContext: context) {
            didDismiss = true
        }

        note.content = "   \n"
        viewModel.updateTimestampAndDismiss()

        XCTAssertNotNil(note.deletedAt)
        XCTAssertTrue(didDismiss)
    }

    func testUpdateTimestampAndDismissForDeletedNoteDismissesDirectly() {
        let note = Note(content: "x", userId: "u1")
        note.deletedAt = Date()
        context.insert(note)

        var didDismiss = false
        let viewModel = NoteDetailViewModel(note: note)
        viewModel.configureForTesting(modelContext: context) {
            didDismiss = true
        }

        viewModel.updateTimestampAndDismiss()
        XCTAssertTrue(didDismiss)
    }

    func testExecuteTidyActionSuccessShowsToolbarAndUpdatesContent() async {
        let note = Note(content: "messy", userId: "u1")
        context.insert(note)

        var deps = NoteDetailViewModel.Dependencies()
        deps.executeTidy = { _ in "tidy" }

        let viewModel = NoteDetailViewModel(note: note, dependencies: deps)
        viewModel.configureForTesting(modelContext: context)

        await viewModel.executeTidyAction()

        XCTAssertEqual(note.content, "tidy")
        XCTAssertTrue(viewModel.showAIToolbar)
        XCTAssertEqual(viewModel.aiOriginalContent, "messy")
    }

    func testExecuteTidyActionLimitErrorShowsUpgradeSheet() async {
        let note = Note(content: "messy", userId: "u1")
        context.insert(note)

        var deps = NoteDetailViewModel.Dependencies()
        deps.executeTidy = { _ in
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "daily free tidy limit reached"])
        }

        let viewModel = NoteDetailViewModel(note: note, dependencies: deps)
        viewModel.configureForTesting(modelContext: context)

        await viewModel.executeTidyAction()

        XCTAssertTrue(viewModel.showUpgradeSheet)
        XCTAssertEqual(viewModel.upgradeTitle, "Daily Tidy limit reached")
    }

    func testHandleAIInputWithEmptyInputSkipsRequest() async {
        let note = Note(content: "original", userId: "u1")
        context.insert(note)

        var didCallAI = false
        var deps = NoteDetailViewModel.Dependencies()
        deps.generateAIEdit = { _, _ in
            didCallAI = true
            return "unused"
        }

        let viewModel = NoteDetailViewModel(note: note, dependencies: deps)
        viewModel.configureForTesting(modelContext: context)
        viewModel.inputText = "   "

        await viewModel.handleAIInput()

        XCTAssertFalse(didCallAI)
        XCTAssertEqual(note.content, "original")
    }

    func testHandleAIInputSuccessUpdatesContent() async {
        let note = Note(content: "original", userId: "u1")
        context.insert(note)

        var deps = NoteDetailViewModel.Dependencies()
        deps.generateAIEdit = { _, _ in "rewritten" }

        let viewModel = NoteDetailViewModel(note: note, dependencies: deps)
        viewModel.configureForTesting(modelContext: context)
        viewModel.inputText = "make it better"

        await viewModel.handleAIInput()

        XCTAssertEqual(note.content, "rewritten")
        XCTAssertFalse(viewModel.isProcessing)
    }

    func testHandleAIInputFailureResetsProcessing() async {
        let note = Note(content: "original", userId: "u1")
        context.insert(note)

        var deps = NoteDetailViewModel.Dependencies()
        deps.generateAIEdit = { _, _ in
            throw NSError(domain: "Test", code: 2, userInfo: nil)
        }

        let viewModel = NoteDetailViewModel(note: note, dependencies: deps)
        viewModel.configureForTesting(modelContext: context)
        viewModel.inputText = "edit"

        await viewModel.handleAIInput()

        XCTAssertEqual(note.content, "original")
        XCTAssertFalse(viewModel.isProcessing)
    }

    func testConfirmTagUsesExistingTagAndRemovesSuggestion() {
        let note = Note(content: "content", userId: "u1")
        let existingTag = Tag(name: "Work", userId: "u1")
        note.suggestedTags = ["Work"]
        context.insert(note)
        context.insert(existingTag)

        let viewModel = NoteDetailViewModel(note: note)
        viewModel.configureForTesting(modelContext: context)

        viewModel.confirmTag("Work")
        viewModel.confirmTag("Work")

        XCTAssertFalse(note.suggestedTags.contains("Work"))
        XCTAssertEqual(note.tags.filter { $0.id == existingTag.id }.count, 1)
    }

    func testMakeExportFilenameSanitizesAndLimitsLength() {
        let note = Note(content: "content", userId: "u1")
        let viewModel = NoteDetailViewModel(note: note)

        let longTitle = String(repeating: "a", count: 80) + "/:*?\"<>|"
        let markdown = "\(longTitle)\nbody"
        let fileName = viewModel.makeExportFilename(
            from: markdown,
            createdAt: Date(timeIntervalSince1970: 0),
            noteId: UUID(uuidString: "12345678-1234-1234-1234-123456789abc")!
        )

        XCTAssertTrue(fileName.hasSuffix("-123456.md"))
        XCTAssertFalse(fileName.contains("/"))
        XCTAssertFalse(fileName.contains(":"))
        XCTAssertLessThanOrEqual(fileName.count, 60 + "-19700101-000000-123456.md".count)
    }
}
