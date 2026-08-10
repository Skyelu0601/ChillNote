package com.sponteoai.chillscript.ai

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentRecipeTest {
    @Test fun builtInLibraryMatchesIosSkillSet() {
        assertEquals(10, BuiltInRecipes.all.size)
        assertTrue(BuiltInRecipes.defaultIds.all { id -> BuiltInRecipes.all.any { it.id == id } })
    }

    @Test fun selectionApplicationSupportsEveryIosApplyMode() {
        val source = "one two three"
        val selection = TextSelection(4, 7)
        assertEquals("one NEW three", AISkillTextApplication.apply(source, "NEW", selection, AISkillApplyMode.REPLACE_SELECTION))
        assertEquals("one two\n\nNEW three", AISkillTextApplication.apply(source, "NEW", selection, AISkillApplyMode.INSERT_BELOW_SELECTION))
        assertEquals("one two three\n\nNEW", AISkillTextApplication.apply(source, "NEW", selection, AISkillApplyMode.APPEND_TO_END))
        assertEquals("NEW", AISkillTextApplication.apply(source, "NEW", selection, AISkillApplyMode.REPLACE_ALL))
    }

    @Test fun collapsedSelectionUsesCursorModes() {
        val selection = TextSelection(4, 4)
        assertEquals("one NEWtwo", AISkillTextApplication.apply("one two", "NEW", selection, AISkillApplyMode.INSERT_AT_CURSOR))
        assertEquals(
            listOf(AISkillApplyMode.INSERT_AT_CURSOR, AISkillApplyMode.APPEND_TO_END, AISkillApplyMode.REPLACE_ALL),
            AISkillTextApplication.availableModes(selection),
        )
    }

    @Test fun translateInstructionIsIncludedAtRuntime() {
        val recipe = BuiltInRecipes.all.first { it.id == "translate" }
        val (prompt, _) = recipe.requestPrompts("你好", "French")
        assertTrue(prompt.contains("Target language: French"))
    }
}
