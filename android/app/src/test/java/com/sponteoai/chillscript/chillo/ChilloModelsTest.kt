package com.sponteoai.chillscript.chillo

import kotlinx.serialization.json.Json
import org.junit.Assert.*
import org.junit.Test

class ChilloModelsTest {
    @Test fun durableTurnDecodesSourceAndDraftMetadata() {
        val turn = Json.decodeFromString<ChilloTurn>("""{"id":"turn","request":"Write a script","answer":"A fact [1]","status":"completed","sources":[{"number":1,"noteId":"note","availability":"active","title":"Source","excerpt":"Original text","platform":null}],"sourcesChanged":false,"draftNoteId":"draft"}""")
        assertFalse(turn.active)
        assertEquals("note", turn.sources.first().noteId)
        assertEquals("draft", turn.draftNoteId)
    }
    @Test fun onlyQueuedAndRunningBlockAnotherMessage() {
        for (status in listOf("queued", "running", "completed", "failed", "cancelled")) {
            val turn = ChilloTurn("id", "request", "", status)
            assertEquals(status == "queued" || status == "running", turn.active)
        }
    }
    @Test fun consentIsNeverAssumedWhenLibraryIsUnavailable() {
        assertTrue(ChilloState().needsConsent)
        assertTrue(ChilloState(library = ChilloLibrary(2, 2, 0, 0, 0)).needsConsent)
        assertFalse(ChilloState(library = ChilloLibrary(2, 2, 0, 0, 1)).needsConsent)
    }

    @Test fun citationsNeverAppearInVisibleAnswerText() {
        assertEquals("A fact.", stripChilloCitations("A fact [1](chillo-source://1)."))
        assertEquals("Supported. Unknown.", stripChilloCitations("Supported [1, 3, 9]. Unknown [8]."))
    }

    @Test fun notesUsedAreDeduplicatedByNote() {
        val first = ChilloSource(1, "note", "active", "Source", "First")
        val second = ChilloSource(4, "note", "active", "Source", "Second")
        val third = ChilloSource(8, "other", "active", "Other", "Third")

        assertEquals(listOf("note", "other"), uniqueChilloSources(listOf(first, second, third)).map { it.noteId })
    }
}
