package com.sponteoai.chillscript.domain

import org.junit.Assert.assertEquals
import org.junit.Test

class ImportedTranscriptFormattingTest {
    @Test
    fun creatorMediaTranscriptRemovesBlankAndWhitespaceOnlyLines() {
        val content = "## Transcript\n\nFirst paragraph.\n  \nSecond paragraph.\n"

        assertEquals(
            "## Transcript\nFirst paragraph.\nSecond paragraph.",
            normalizeImportedTranscriptMarkdown(content, "https://www.tiktok.com/t/example", "tiktok"),
        )
    }

    @Test
    fun creatorMediaTranscriptNormalizesUnicodeParagraphSeparators() {
        val content = "## Transcript\u2029\u2029First paragraph.\u2028\u2028Second paragraph."

        assertEquals(
            "## Transcript\nFirst paragraph.\nSecond paragraph.",
            normalizeImportedTranscriptMarkdown(content, "https://youtu.be/example", null),
        )
    }

    @Test
    fun ordinaryNotesAndLegacyMultiSectionImportsStayUntouched() {
        val ordinary = "First paragraph.\n\nSecond paragraph."
        val legacy = "## Description\nText\n\n## Transcript\nWords"

        assertEquals(ordinary, normalizeImportedTranscriptMarkdown(ordinary, null, null))
        assertEquals(
            legacy,
            normalizeImportedTranscriptMarkdown(legacy, "https://www.instagram.com/reel/example", "instagram"),
        )
    }
}
