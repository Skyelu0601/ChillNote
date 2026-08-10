package com.sponteoai.chillscript.ai

import com.sponteoai.chillscript.data.local.NoteEntity
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ContextChatTest {
    private val note = NoteEntity(
        id = "n1", userId = "u1", content = "The launch is Friday.",
        createdAt = "2026-07-13T00:00:00Z", updatedAt = "2026-07-13T00:00:00Z",
    )

    @Test fun promptNumbersNotesForCitations() {
        val (prompt, _) = ContextChatPrompt.build(listOf(note), emptyList(), "When is launch?", emptyList())
        assertTrue(prompt.contains("Note [1]"))
        assertTrue(prompt.contains("The launch is Friday."))
    }

    @Test fun slashCommandUsesInstalledRecipe() {
        val recipe = BuiltInRecipes.all.first { it.id == "summarize" }
        val (prompt, _) = ContextChatPrompt.build(listOf(note), emptyList(), "/summarize briefly", listOf(recipe))
        assertTrue(prompt.contains("Skill: Summarize"))
        assertTrue(prompt.contains("briefly"))
        assertFalse(prompt.contains("Current User Question"))
    }

    @Test fun sanitizerRemovesProviderSourcePrefix() {
        assertTrue(ContextChatPrompt.sanitize("Source: notes\nAnswer [1]") == "Answer [1]")
    }
}
