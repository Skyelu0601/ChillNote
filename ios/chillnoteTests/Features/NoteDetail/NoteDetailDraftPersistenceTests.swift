import XCTest
import SwiftUI
import SwiftData
@testable import chillnote

@MainActor
final class NoteDetailDraftPersistenceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var userID: String!

    override func setUpWithError() throws {
        container = try ModelContainer(for: Note.self, Tag.self, ChecklistItem.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = container.mainContext
        userID = "draft-persistence-test-\(UUID().uuidString)"
    }

    override func tearDownWithError() throws {
        HardDeleteQueueStore.dequeue(noteIDs: HardDeleteQueueStore.noteIDs(for: userID), for: userID)
        context = nil
        container = nil
    }

    func testClearTranscriptBackgroundThenPasteAndClosePreservesNote() throws {
        try verifyTranscriptReplacement(backgroundBeforeClearing: false, autosaveWhileEmpty: true)
    }

    func testBackgroundThenClearAndPasteTranscriptPreservesNote() throws {
        try verifyTranscriptReplacement(backgroundBeforeClearing: true, autosaveWhileEmpty: false)
    }

    func testBackgroundThenClearAndPasteWithInterveningAutosavePreservesNote() throws {
        try verifyTranscriptReplacement(backgroundBeforeClearing: true, autosaveWhileEmpty: true)
    }

    private func verifyTranscriptReplacement(backgroundBeforeClearing: Bool, autosaveWhileEmpty: Bool) throws {
        let note = try makeNote(content: "Original transcript")
        let sourceURL = "https://www.tiktok.com/@example/video/123"
        note.sourceURL = sourceURL
        note.sourcePlatformID = "tiktok"
        note.importStatus = .completed
        note.importJobId = "completed-import"
        try context.save()
        let noteID = note.id
        let model = NoteDetailViewModel(note: note)
        var didDismiss = false
        model.configureForTesting(modelContext: context) { didDismiss = true }

        let editor = RichTextEditorView(
            text: Binding(get: { note.content }, set: { note.updateContent($0) }),
            controller: RichTextEditorController(),
            onFinalTextCommit: model.stageFinalEditorText
        )
        let coordinator = editor.makeCoordinator()
        let textView = InteractiveTextView(usingTextLayoutManager: true)
        coordinator.textView = textView
        textView.delegate = coordinator
        let snapshot = coordinator.editorSession.applyExternalMarkdown(note.content, to: textView, markdownSelection: nil)
        coordinator.acceptExternalMarkdown(note.content, snapshot: snapshot)
        defer { coordinator.dismantle(textView) }

        if backgroundBeforeClearing {
            coordinator.flushPendingChanges()
            XCTAssertFalse(model.commitPendingEdits())
            coordinator.textViewDidEndEditing(textView)
            coordinator.textViewDidBeginEditing(textView)
            XCTAssertEqual(try persistedNote().content, "Original transcript")
        }

        textView.attributedText = NSAttributedString(string: "")
        coordinator.textViewDidChange(textView)
        coordinator.flushPendingChanges()
        if autosaveWhileEmpty {
            // Backgrounding or system interruptions may save between edits.
            XCTAssertTrue(model.commitPendingEdits())
            XCTAssertFalse(model.commitPendingEdits())
            let blank = try persistedNote()
            XCTAssertEqual(blank.id, noteID)
            XCTAssertEqual(blank.content, "")
            XCTAssertEqual(blank.sourceURL, sourceURL)
        }
        XCTAssertFalse(didDismiss)
        XCTAssertTrue(HardDeleteQueueStore.noteIDs(for: userID).isEmpty)

        coordinator.editorSession.pastePlainText("Replacement text", into: textView)
        coordinator.flushPendingChanges()
        model.updateTimestampAndDismiss()

        let saved = try persistedNote()
        XCTAssertEqual(saved.id, noteID)
        XCTAssertEqual(saved.content, "Replacement text")
        XCTAssertEqual(saved.sourceURL, sourceURL)
        XCTAssertEqual(saved.importJobId, "completed-import")
        XCTAssertEqual(saved.importStatus, .completed)
        XCTAssertNil(saved.deletedAt)
        XCTAssertTrue(didDismiss)
        XCTAssertTrue(HardDeleteQueueStore.noteIDs(for: userID).isEmpty)
    }

    func testClearedExistingNoteStaysSavedAfterBackgroundAndBack() throws {
        let note = try makeNote(content: "Saved content")
        let model = NoteDetailViewModel(note: note)
        model.configureForTesting(modelContext: context)
        note.updateContent("")

        XCTAssertTrue(model.commitPendingEdits())
        XCTAssertEqual(model.initialContent, "")
        model.updateTimestampAndDismiss()

        XCTAssertEqual(try persistedNote().content, "")
        XCTAssertTrue(HardDeleteQueueStore.noteIDs(for: userID).isEmpty)
    }

    func testReopenedEmptyNoteIsNeverTreatedAsNewDraft() throws {
        let note = try makeNote(content: "")
        let model = NoteDetailViewModel(note: note)
        model.configureForTesting(modelContext: context)
        model.updateTimestampAndDismiss()

        XCTAssertEqual(try persistedNote().id, note.id)
        XCTAssertTrue(HardDeleteQueueStore.noteIDs(for: userID).isEmpty)
    }

    func testNewBlankDraftSurvivesAutosaveAndIsDiscardedOnlyOnExplicitBack() throws {
        let note = try makeNote(content: "")
        let noteID = note.id.uuidString
        let model = NoteDetailViewModel(note: note, isNewBlankDraft: true)
        model.configureForTesting(modelContext: context)

        XCTAssertFalse(model.commitPendingEdits())
        XCTAssertEqual(try persistedNote().id.uuidString, noteID)
        XCTAssertTrue(HardDeleteQueueStore.noteIDs(for: userID).isEmpty)

        model.updateTimestampAndDismiss()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Note>()), 0)
        XCTAssertEqual(HardDeleteQueueStore.noteIDs(for: userID), [noteID])

        // SwiftUI teardown can arrive after the explicit back action.
        model.stageFinalEditorText("", "")
        XCTAssertFalse(model.commitPendingEdits())
        XCTAssertTrue(model.isDeleted)
    }

    func testNewDraftWithSavedTextDoesNotBecomeDisposableWhenClearedLater() throws {
        let note = try makeNote(content: "")
        let model = NoteDetailViewModel(note: note, isNewBlankDraft: true)
        model.configureForTesting(modelContext: context)

        note.updateContent("Saved during this editing session")
        XCTAssertTrue(model.commitPendingEdits())
        note.updateContent("")
        XCTAssertTrue(model.commitPendingEdits())
        model.updateTimestampAndDismiss()

        XCTAssertEqual(try persistedNote().content, "")
        XCTAssertTrue(HardDeleteQueueStore.noteIDs(for: userID).isEmpty)
    }

    func testNewDraftWithSourceIsRetainedWithoutTranscript() throws {
        let note = try makeNote(content: "")
        let model = NoteDetailViewModel(note: note, isNewBlankDraft: true)
        model.configureForTesting(modelContext: context)
        note.sourceURL = "https://www.tiktok.com/@example/video/123"
        try context.save()

        model.updateTimestampAndDismiss()

        XCTAssertEqual(try persistedNote().sourceURL, note.sourceURL)
        XCTAssertTrue(HardDeleteQueueStore.noteIDs(for: userID).isEmpty)
    }

    func testNewDraftWithImportJobIsRetainedWhileWaitingForContent() throws {
        let note = try makeNote(content: "")
        let model = NoteDetailViewModel(note: note, isNewBlankDraft: true)
        model.configureForTesting(modelContext: context)
        note.importStatus = .processing
        note.importJobId = "pending-import"
        try context.save()

        model.updateTimestampAndDismiss()

        XCTAssertEqual(try persistedNote().importJobId, "pending-import")
        XCTAssertTrue(HardDeleteQueueStore.noteIDs(for: userID).isEmpty)
    }

    func testFinalEditorTextIsAppliedBeforeNewDraftCleanup() throws {
        let note = try makeNote(content: "")
        let model = NoteDetailViewModel(note: note, isNewBlankDraft: true)
        model.configureForTesting(modelContext: context)
        model.stageFinalEditorText("Last edit before leaving", "")

        model.updateTimestampAndDismiss()

        XCTAssertEqual(try persistedNote().content, "Last edit before leaving")
        XCTAssertTrue(HardDeleteQueueStore.noteIDs(for: userID).isEmpty)
    }

    private func makeNote(content: String) throws -> Note {
        let note = Note(content: content, userId: userID)
        context.insert(note)
        try context.save()
        return note
    }

    private func persistedNote() throws -> Note {
        XCTAssertFalse(context.hasChanges)
        let saved = try context.fetch(FetchDescriptor<Note>())
        XCTAssertEqual(saved.count, 1)
        return try XCTUnwrap(saved.first)
    }
}
