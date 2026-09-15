package com.sponteoai.chillscript.domain

import com.sponteoai.chillscript.data.local.NoteEntity
import org.junit.Assert.assertEquals
import org.junit.Test

class NoteEditorDraftSessionTest {
    @Test
    fun clearingExistingTranscriptSavesInsteadOfDeletingItsVideoSource() {
        val note = note("Original transcript").copy(
            sourceUrl = "https://www.tiktok.com/@example/video/123",
            importStatus = "completed",
            importJobId = "video-import",
        )
        val session = NoteEditorDraftSession(note)

        assertEquals(NoteEditorCloseAction.Save, session.closeAction(note, "", note.content))
    }

    @Test
    fun clearingExistingTextNoteSavesEmptyContent() {
        val note = note("Saved text")

        assertEquals(
            NoteEditorCloseAction.Save,
            NoteEditorDraftSession(note).closeAction(note, " \n", note.content),
        )
    }

    @Test
    fun blankAutosaveDoesNotTurnAnExistingNoteIntoADisposableDraft() {
        val note = note("Original transcript")
        val session = NoteEditorDraftSession(note)
        session.recordContent("")
        val autosaved = note.copy(content = "")

        assertEquals(NoteEditorCloseAction.None, session.closeAction(autosaved, "", ""))
    }

    @Test
    fun returningFromAnotherAppThenClearingAndPastingSavesReplacement() {
        val note = note("Original transcript")
        val session = NoteEditorDraftSession(note)
        session.recordContent(note.content)
        session.recordContent("")
        session.recordContent("Replacement text")

        assertEquals(
            NoteEditorCloseAction.Save,
            session.closeAction(note, "Replacement text", note.content),
        )
    }

    @Test
    fun pastingAfterAnEmptyAutosaveStillSavesTheReplacement() {
        val note = note("Original transcript")
        val session = NoteEditorDraftSession(note)
        session.recordContent("")
        val autosaved = note.copy(content = "")
        session.recordContent("Replacement text")

        assertEquals(
            NoteEditorCloseAction.Save,
            session.closeAction(autosaved, "Replacement text", ""),
        )
    }

    @Test
    fun reopeningAnEmptyNoteNeverEnablesDraftCleanup() {
        val note = note("")

        assertEquals(NoteEditorCloseAction.None, NoteEditorDraftSession(note).closeAction(note, "", ""))
    }

    @Test
    fun untouchedNewBlankDraftCanBeDiscardedOnClose() {
        val note = note("")
        val session = NoteEditorDraftSession(note, isNewBlankDraft = true)
        session.recordContent("")

        assertEquals(NoteEditorCloseAction.DiscardEmptyDraft, session.closeAction(note, "", ""))
    }

    @Test
    fun newDraftThatHadTextRemainsSavedAfterBeingClearedAndAutosaved() {
        val note = note("")
        val session = NoteEditorDraftSession(note, isNewBlankDraft = true)
        session.recordContent("First saved text")
        session.recordContent("")

        assertEquals(NoteEditorCloseAction.None, session.closeAction(note, "", ""))
    }

    @Test
    fun clearingNewDraftBeforeItsNextAutosaveSavesTheClearing() {
        val note = note("")
        val session = NoteEditorDraftSession(note, isNewBlankDraft = true)
        session.recordContent("First saved text")

        assertEquals(
            NoteEditorCloseAction.Save,
            session.closeAction(note.copy(content = "First saved text"), "", "First saved text"),
        )
    }

    @Test
    fun lastPasteBeforeClosingCannotBeDiscardedEvenBeforeItsChangeCallback() {
        val note = note("")
        val session = NoteEditorDraftSession(note, isNewBlankDraft = true)

        assertEquals(NoteEditorCloseAction.Save, session.closeAction(note, "Last paste", ""))
    }

    @Test
    fun newNoteCreatedFromSharedTextIsNotABlankDraft() {
        val note = note("Shared text")

        assertEquals(
            NoteEditorCloseAction.Save,
            NoteEditorDraftSession(note, isNewBlankDraft = true).closeAction(note, "", note.content),
        )
    }

    @Test
    fun blankNoteWithSourceIsNeverDisposable() {
        val note = note("").copy(sourceUrl = "https://www.tiktok.com/@example/video/123")

        assertEquals(
            NoteEditorCloseAction.None,
            NoteEditorDraftSession(note, isNewBlankDraft = true).closeAction(note, "", ""),
        )
    }

    @Test
    fun sourceArrivingWhileEditorIsOpenPreventsDraftCleanup() {
        val note = note("")
        val session = NoteEditorDraftSession(note, isNewBlankDraft = true)
        val latest = note.copy(sourceUrl = "https://www.tiktok.com/@example/video/123")

        assertEquals(NoteEditorCloseAction.None, session.closeAction(latest, "", ""))
    }

    @Test
    fun importProgressAndRecoveryMetadataProtectEmptyDrafts() {
        val note = note("")
        val protectedNotes = listOf(
            note.copy(importStatus = "queued"),
            note.copy(importStatus = "processing"),
            note.copy(importStatus = "completed"),
            note.copy(importStatus = "failed"),
            note.copy(importJobId = "pending-import"),
        )
        for (latest in protectedNotes) {
            val session = NoteEditorDraftSession(note, isNewBlankDraft = true)
            assertEquals(NoteEditorCloseAction.None, session.closeAction(latest, "", ""))
        }
    }

    @Test
    fun draftCleanupPermissionCannotLeakToADifferentNote() {
        val note = note("")
        val session = NoteEditorDraftSession(note, isNewBlankDraft = true)

        assertEquals(
            NoteEditorCloseAction.None,
            session.closeAction(note.copy(id = "another-note"), "", ""),
        )
    }

    @Test
    fun voiceProcessingAndRecoveryKeepTheirExistingProtection() {
        val note = note("")
        val session = NoteEditorDraftSession(note, isNewBlankDraft = true)

        assertEquals(
            NoteEditorCloseAction.None,
            session.closeAction(note, "", "", hasVoiceState = true),
        )
        assertEquals(
            NoteEditorCloseAction.None,
            session.closeAction(note, "Partial transcript", "", isVoiceProcessing = true),
        )
    }

    @Test
    fun closingTrashedNoteDoesNotSaveOrPermanentlyDeleteIt() {
        val note = note("")

        assertEquals(
            NoteEditorCloseAction.None,
            NoteEditorDraftSession(note, isNewBlankDraft = true).closeAction(
                note.copy(deletedAt = "2026-09-14T00:00:00Z"), "", "",
            ),
        )
    }

    @Test
    fun unsavedEditorOnlyCreatesANoteWhenItHasText() {
        val session = NoteEditorDraftSession()

        assertEquals(NoteEditorCloseAction.None, session.closeAction(null, "", ""))
        assertEquals(NoteEditorCloseAction.Save, session.closeAction(null, "New text", ""))
    }

    private fun note(content: String) = NoteEntity(
        id = "note-1",
        userId = "test-user",
        content = content,
        createdAt = "2026-09-14T00:00:00Z",
        updatedAt = "2026-09-14T00:00:00Z",
    )
}
