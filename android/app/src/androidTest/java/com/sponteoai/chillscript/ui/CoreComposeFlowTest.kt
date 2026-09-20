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
import com.sponteoai.chillscript.chillo.ChilloController
import com.sponteoai.chillscript.chillo.ChilloDataSource
import com.sponteoai.chillscript.chillo.ChilloScreen
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.onboarding.OnboardingScreen
import kotlinx.serialization.json.*
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
                OnboardingScreen(
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
    fun chillo_acceptsAndSendsTrimmedMessage() {
        var sentMessage: String? = null
        val controller = ChilloController(object : ChilloDataSource {
            override val json = Json { ignoreUnknownKeys = true }
            override suspend fun request(path: String, method: String, body: JsonObject?): JsonObject {
                val payload = when {
                    path == "/library" -> """{"total":0,"available":0,"indexed":0,"pending":0,"consentVersion":1}"""
                    path == "/conversations" && method == "GET" -> """{"conversations":[],"nextCursor":null}"""
                    path == "/conversations" -> """{"id":"conversation","title":""}"""
                    path.endsWith("/turns") -> {
                        sentMessage = body?.get("message")?.jsonPrimitive?.content
                        """{"id":"turn","request":"$sentMessage","answer":"","status":"cancelled","sources":[],"sourcesChanged":false}"""
                    }
                    else -> error("Unexpected test request: $path")
                }
                return json.parseToJsonElement(payload).jsonObject
            }
        })
        composeRule.setContent {
            ChillScriptTheme {
                ChilloScreen(controller, onBack = {}, onOpenNote = { false })
            }
        }
        composeRule.enableAccessibilityChecks()

        composeRule.waitUntil { !controller.state.value.loading && controller.state.value.library != null }
        composeRule.onNodeWithText(resources.getString(R.string.chillo_empty_title)).assertIsDisplayed()
        composeRule.onAllNodes(isRoot()).tryPerformAccessibilityChecks()
        composeRule.onNodeWithText(resources.getString(R.string.chillo_placeholder))
            .performTextInput("  Help me write a hook  ")
        composeRule.onNodeWithContentDescription(resources.getString(R.string.chillo_send)).performClick()

        composeRule.waitUntil { sentMessage != null }
        composeRule.runOnIdle { assertEquals("Help me write a hook", sentMessage) }
    }
}
