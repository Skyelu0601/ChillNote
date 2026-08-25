package com.sponteoai.chillscript.ai

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentRecipeTest {
    @Test fun builtInLibraryMatchesIosSkillSet() {
        assertEquals(10, BuiltInRecipes.all.size)
        assertTrue(BuiltInRecipes.defaultIds.all { id -> BuiltInRecipes.all.any { it.id == id } })
    }

    @Test fun skillResultOnlyOffersAppendAndReplaceEntireNote() {
        val source = "one two three"
        val selection = TextSelection(4, 7)
        assertEquals("one two three\n\nNEW", AISkillTextApplication.apply(source, "NEW", selection, AISkillApplyMode.APPEND_TO_END))
        assertEquals("NEW", AISkillTextApplication.apply(source, "NEW", selection, AISkillApplyMode.REPLACE_ALL))
        assertEquals(
            listOf(
                AISkillApplyMode.APPEND_TO_END,
                AISkillApplyMode.REPLACE_ALL,
            ),
            AISkillTextApplication.availableModes(selection),
        )
    }

    @Test fun collapsedSelectionOffersTheSameTwoModes() {
        val selection = TextSelection(4, 4)
        assertEquals(
            listOf(AISkillApplyMode.APPEND_TO_END, AISkillApplyMode.REPLACE_ALL),
            AISkillTextApplication.availableModes(selection),
        )
    }

    @Test fun translateInstructionIsIncludedAtRuntime() {
        val recipe = BuiltInRecipes.all.first { it.id == "translate" }
        val (prompt, _) = recipe.requestPrompts("你好", "French")
        assertTrue(prompt.contains("Target language: French"))
    }
}
