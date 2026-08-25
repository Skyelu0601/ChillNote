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

    func testUpdateTimestampAndDismissSyncsChecklistStructureAfterManualEdit() {
        let note = Note(content: "old", userId: "u1")
        context.insert(note)

        let viewModel = NoteDetailViewModel(note: note)
        viewModel.configureForTesting(modelContext: context)

        note.content = "- [ ] Buy milk\n- [x] Walk home"
        viewModel.updateTimestampAndDismiss()

        XCTAssertTrue(note.isChecklist)
        XCTAssertEqual(note.checklistItems.count, 2)
        XCTAssertEqual(note.checklistItems.sorted { $0.sortOrder < $1.sortOrder }.map(\.text), ["Buy milk", "Walk home"])
        XCTAssertEqual(note.checklistItems.sorted { $0.sortOrder < $1.sortOrder }.map(\.isDone), [false, true])
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

        let notes = (try? context.fetch(FetchDescriptor<Note>())) ?? []
        XCTAssertEqual(notes.count, 0)
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

    func testConfirmTagUsesExistingTagOnlyOnce() {
        let note = Note(content: "content", userId: "u1")
        let existingTag = Tag(name: "Work", userId: "u1")
        context.insert(note)
        context.insert(existingTag)

        let viewModel = NoteDetailViewModel(note: note)
        viewModel.configureForTesting(modelContext: context)

        viewModel.confirmTag("Work")
        viewModel.confirmTag("Work")

        XCTAssertEqual(note.tags.filter { $0.id == existingTag.id }.count, 1)
    }

    func testConfirmTagDoesNotReuseSameNameTagFromAnotherUser() throws {
        let note = Note(content: "content", userId: "u1")
        let otherUserTag = Tag(name: "Work", userId: "u2")
        context.insert(note)
        context.insert(otherUserTag)

        let viewModel = NoteDetailViewModel(note: note)
        viewModel.configureForTesting(modelContext: context)

        viewModel.confirmTag("Work")

        let tags = try context.fetch(FetchDescriptor<Tag>())
        let currentUserTags = tags.filter { $0.userId == "u1" }
        XCTAssertEqual(currentUserTags.count, 1)
        XCTAssertEqual(currentUserTags.first?.name, "Work")
        XCTAssertEqual(note.tags.map(\.id), currentUserTags.map(\.id))
        XCTAssertFalse(note.tags.contains { $0.id == otherUserTag.id })
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

    func testAISkillPreviewOnlyOffersAppendAndReplaceEntireNote() {
        let recipe = AgentRecipe(
            id: "test",
            systemIcon: "sparkles",
            name: "Test",
            description: "Test",
            prompt: "Test",
            category: .shape
        )

        for selection in [
            RichTextEditorSelection(location: 0, length: 0, selectedText: ""),
            RichTextEditorSelection(location: 0, length: 4, selectedText: "Text")
        ] {
            let preview = NoteAISkillPreview(
                recipe: recipe,
                result: "Result",
                sourceContent: "Text",
                sourceSelection: selection,
                instruction: nil
            )

            XCTAssertEqual(preview.availableApplyModes, [.appendToEnd, .replaceAll])
        }
    }
}
