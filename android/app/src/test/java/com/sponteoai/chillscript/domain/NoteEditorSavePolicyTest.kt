package com.sponteoai.chillscript.domain

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NoteEditorSavePolicyTest {
    @Test
    fun unchangedExistingNoteDoesNotSaveWhenClosed() {
        assertFalse(
            shouldPersistEditorContentOnClose(
                hasExistingNote = true,
                currentContent = "Existing note",
                persistedContent = "Existing note",
                isVoiceProcessing = false,
            ),
        )
    }

    @Test
    fun changedExistingNoteSavesWhenClosed() {
        assertTrue(
            shouldPersistEditorContentOnClose(
                hasExistingNote = true,
                currentContent = "Updated note",
                persistedContent = "Existing note",
                isVoiceProcessing = false,
            ),
        )
    }

    @Test
    fun newNoteSavesWhenClosed() {
        assertTrue(
            shouldPersistEditorContentOnClose(
                hasExistingNote = false,
                currentContent = "New note",
                persistedContent = "",
                isVoiceProcessing = false,
            ),
        )
    }

    @Test
    fun voiceProcessingDoesNotSaveWhenClosed() {
        assertFalse(
            shouldPersistEditorContentOnClose(
                hasExistingNote = true,
                currentContent = "Processing",
                persistedContent = "Existing note",
                isVoiceProcessing = true,
            ),
        )
    }
}
