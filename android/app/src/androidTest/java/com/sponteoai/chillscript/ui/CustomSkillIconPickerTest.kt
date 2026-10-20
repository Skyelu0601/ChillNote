package com.sponteoai.chillscript.ui

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.ui.skills.CustomRecipeDialog
import com.sponteoai.chillscript.ui.theme.ChillScriptTheme
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class CustomSkillIconPickerTest {
    @get:Rule val rule = createComposeRule()
    private val resources get() = InstrumentationRegistry.getInstrumentation().targetContext.resources
    @Test fun chosenIconIsPassedWithNameAndPromptWhenSaving() {
        var saved: List<String>? = null
        var dismissCount = 0
        rule.setContent {
            ChillScriptTheme {
                CustomRecipeDialog(onDismiss = { dismissCount++ }, onCreate = { name, prompt, icon -> saved = listOf(name, prompt, icon) })
            }
        }
        rule.onNodeWithContentDescription(resources.getString(R.string.creator_skills_custom_name)).performTextInput("Test skill")
        rule.onNodeWithText(resources.getString(R.string.creator_skills_custom_icon)).performScrollTo().performClick()
        rule.onNode(hasScrollAction() and hasAnyDescendant(hasContentDescription(resources.getString(R.string.creator_skills_icon_option, 1))))
            .performScrollToIndex(21)
        rule.onNodeWithContentDescription(resources.getString(R.string.creator_skills_icon_option, 22)).performClick()
        rule.onNodeWithContentDescription(resources.getString(R.string.creator_skills_custom_instruction)).performScrollTo().performTextInput("Rewrite naturally")
        rule.onNodeWithText(resources.getString(R.string.common_save)).performClick()
        rule.runOnIdle {
            assertEquals(listOf("Test skill", "Rewrite naturally", "lightbulb.fill"), saved)
            assertEquals(0, dismissCount)
        }
    }
}
