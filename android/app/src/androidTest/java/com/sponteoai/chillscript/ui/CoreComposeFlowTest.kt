package com.sponteoai.chillscript.ui

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.isRoot
import androidx.compose.ui.test.junit4.accessibility.enableAccessibilityChecks
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.tryPerformAccessibilityChecks
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.sponteoai.chillscript.ContextChatUiState
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.onboarding.OnboardingScreen
import com.sponteoai.chillscript.ui.chat.ContextChatScreen
import com.sponteoai.chillscript.ui.theme.ChillScriptTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class CoreComposeFlowTest {
    @get:Rule
    val composeRule = createComposeRule()

    private val resources = InstrumentationRegistry.getInstrumentation().targetContext.resources

    @Test
    fun onboarding_walksThroughEveryPageAndFinishes() {
        var finishCount = 0
        composeRule.setContent {
            ChillScriptTheme {
                OnboardingScreen(onFinish = { finishCount += 1 })
            }
        }
        composeRule.enableAccessibilityChecks()

        val titles = listOf(
            R.string.onboarding_page_hero_title,
            R.string.onboarding_page_save_video_title,
            R.string.onboarding_page_extract_title,
            R.string.onboarding_page_capture_title,
            R.string.onboarding_page_hooks_title,
            R.string.onboarding_page_skills_title,
        ).map(resources::getString)

        composeRule.onNodeWithText(titles.first()).assertIsDisplayed()
        composeRule.onAllNodes(isRoot()).tryPerformAccessibilityChecks()
        composeRule.onNodeWithText(resources.getString(R.string.onboarding_action_get_started)).performClick()
        titles.drop(1).forEachIndexed { index, title ->
            composeRule.onNodeWithText(title).assertIsDisplayed()
            composeRule.onAllNodes(isRoot()).tryPerformAccessibilityChecks()
            val action = if (index == titles.size - 2) {
                resources.getString(R.string.onboarding_action_start_creating)
            } else {
                resources.getString(R.string.common_next)
            }
            composeRule.onNodeWithText(action).performClick()
        }

        composeRule.runOnIdle { assertEquals(1, finishCount) }
    }

    @Test
    fun contextChat_acceptsAndSendsTrimmedMessage() {
        var sentMessage: String? = null
        composeRule.setContent {
            ChillScriptTheme {
                ContextChatScreen(
                    state = ContextChatUiState(isOpen = true),
                    onClose = {},
                    onClear = {},
                    onSend = { sentMessage = it },
                    onSave = {},
                    onDismissError = {},
                )
            }
        }
        composeRule.enableAccessibilityChecks()

        composeRule.onNodeWithText(resources.getString(R.string.ai_chat_empty_no_notes_title)).assertIsDisplayed()
        composeRule.onAllNodes(isRoot()).tryPerformAccessibilityChecks()
        composeRule.onNodeWithText(resources.getString(R.string.ai_chat_input_placeholder))
            .performTextInput("  Help me write a hook  ")
        composeRule.onNodeWithContentDescription(resources.getString(R.string.ai_chat_send)).performClick()

        composeRule.runOnIdle { assertEquals("Help me write a hook", sentMessage) }
    }
}
