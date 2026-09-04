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
import com.sponteoai.chillscript.onboarding.IOSParityOnboardingScreen
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
    fun onboarding_showsCurrentHeroAndLoginAction() {
        var loginCount = 0
        composeRule.setContent {
            ChillScriptTheme {
                IOSParityOnboardingScreen(
                    onFinish = {},
                    onLogIn = { loginCount += 1 },
                )
            }
        }
        composeRule.enableAccessibilityChecks()

        composeRule.onNodeWithText(resources.getString(R.string.onboarding_page_hero_body)).assertIsDisplayed()
        composeRule.onNodeWithText(resources.getString(R.string.onboarding_action_get_started)).assertIsDisplayed()
        composeRule.onAllNodes(isRoot()).tryPerformAccessibilityChecks()
        val loginLabel = "${resources.getString(R.string.onboarding_login_prompt)} ${resources.getString(R.string.onboarding_login_action)}"
        composeRule.onNodeWithContentDescription(loginLabel).performClick()

        composeRule.runOnIdle { assertEquals(1, loginCount) }
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
