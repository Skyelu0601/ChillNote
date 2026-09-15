import XCTest
import SwiftUI
import SwiftData
@testable import chillnote

@MainActor
final class RichTextEditorLifecycleTests: XCTestCase {
    func testTeardownStagesPendingTextWithoutReadingOrWritingBindings() async {
        var isDetached = false
        var markdown = "Original"
        var finalMarkdown: String?
        var previousMarkdown: String?
        let editor = RichTextEditorView(
            text: Binding(get: { XCTAssertFalse(isDetached); return markdown }, set: { XCTAssertFalse(isDetached); markdown = $0 }),
            selection: Binding(get: { XCTAssertFalse(isDetached); return .init() }, set: { _ in XCTAssertFalse(isDetached) }),
            controller: RichTextEditorController(),
            isEditing: Binding(get: { XCTAssertFalse(isDetached); return false }, set: { _ in XCTAssertFalse(isDetached) }),
            onFinalTextCommit: { finalMarkdown = $0; previousMarkdown = $1 }
        )
        let coordinator = editor.makeCoordinator()
        let textView = InteractiveTextView(usingTextLayoutManager: true)
        coordinator.textView = textView
        textView.delegate = coordinator
        let snapshot = coordinator.editorSession.applyExternalMarkdown(markdown, to: textView, markdownSelection: nil)
        coordinator.acceptExternalMarkdown(markdown, snapshot: snapshot)
        textView.attributedText = NSAttributedString(string: "Last keystroke")
        coordinator.textViewDidChange(textView)
        isDetached = true
        RichTextEditorView.dismantleUIView(textView, coordinator: coordinator)
        coordinator.textViewDidEndEditing(textView)
        coordinator.textViewDidChangeSelection(textView)
        coordinator.flushPendingChanges()
        XCTAssertNil(textView.delegate)
        XCTAssertNil(coordinator.textView)
        XCTAssertEqual(finalMarkdown, "Last keystroke")
        XCTAssertEqual(previousMarkdown, "Original")
        XCTAssertEqual(markdown, "Original")
        // Exercise both deferred commit and selection work after removal.
        try? await Task.sleep(for: .milliseconds(550))
    }

    func testUninitializedEditorNeverErasesExistingNote() {
        var markdown = "Existing content"
        let editor = RichTextEditorView(text: Binding(get: { markdown }, set: { markdown = $0 }),
                                       controller: RichTextEditorController(),
                                       onFinalTextCommit: { _, _ in XCTFail("Uninitialized editor cannot commit") })
        let coordinator = editor.makeCoordinator()
        let textView = InteractiveTextView(usingTextLayoutManager: true)
        coordinator.textView = textView
        coordinator.flushPendingChanges()
        RichTextEditorView.dismantleUIView(textView, coordinator: coordinator)
        XCTAssertEqual(markdown, "Existing content")
    }

    func testStagedKeystrokeIsSavedBeforeEmptyNoteCleanup() throws {
        let container = try ModelContainer(for: Note.self, Tag.self, ChecklistItem.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let note = Note(content: "", userId: "test")
        container.mainContext.insert(note)
        let model = NoteDetailViewModel(note: note)
        model.configureForTesting(modelContext: container.mainContext)
        model.stageFinalEditorText("First keystroke", "")
        XCTAssertEqual(note.content, "")
        XCTAssertTrue(model.commitPendingEdits())
        XCTAssertEqual(note.content, "First keystroke")
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Note>()), 1)
        XCTAssertFalse(container.mainContext.hasChanges)
    }

    func testStaleEditorCannotOverwriteNewerContent() throws {
        let note = Note(content: "Original", userId: "test")
        let model = NoteDetailViewModel(note: note)
        model.stageFinalEditorText("Old editor value", "Original")
        note.updateContent("Newer content")
        model.commitPendingEdits()
        XCTAssertEqual(note.content, "Newer content")
    }
}
