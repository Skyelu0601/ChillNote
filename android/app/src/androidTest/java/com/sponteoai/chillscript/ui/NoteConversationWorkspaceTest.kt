package com.sponteoai.chillscript.ui

import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.ai.*
import com.sponteoai.chillscript.ui.editor.NoteConversationWorkspace
import com.sponteoai.chillscript.ui.theme.ChillScriptTheme
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class NoteConversationWorkspaceTest {
    @get:Rule val rule = createComposeRule()
    private val resources get() = InstrumentationRegistry.getInstrumentation().targetContext.resources
    private fun text(id: Int) = resources.getString(id)
    private lateinit var controller: NoteConversationController

    private fun show(history: List<NoteConversationTurn> = emptyList()) {
        rule.setContent {
            val scope = rememberCoroutineScope()
            controller = androidx.compose.runtime.remember {
                NoteConversationController(scope, { history }, {}, { true }, { true },
                    { _, _, _ -> "Generated answer" }, {}, {}, { _, _ -> })
            }
            ChillScriptTheme {
                NoteConversationWorkspace(controller = controller, content = "Original note",
                    recipes = listOf("rewrite", "hook_generator", "caption_pack", "repurpose_pack").map { id -> BuiltInRecipes.all.first { it.id == id } },
                    enabled = true, onReplace = { true }, onSkillSelected = {}, onFirstSkillBounds = {},
                    skillsPanelContent = { TextForTest() })
            }
        }
    }

    @Test fun undoAppearsBesideAppliedReplyAndRestoresOriginal() {
        val turn = NoteConversationTurn(message = "Rewrite", answer = "First paragraph\n\n\nSecond paragraph", noteFingerprint = "hash")
        rule.setContent {
            val scope = rememberCoroutineScope()
            val content = androidx.compose.runtime.remember { androidx.compose.runtime.mutableStateOf("Original\n\nKeep this") }
            controller = androidx.compose.runtime.remember {
                NoteConversationController(scope, { listOf(turn) }, {}, { true }, { true },
                    { _, _, _ -> "Unused" }, {}, {}, { _, _ -> })
            }
            ChillScriptTheme {
                NoteConversationWorkspace(controller = controller, content = content.value,
                    recipes = emptyList(), enabled = true,
                    onReplace = { content.value = it; true }, onSkillSelected = {}, onFirstSkillBounds = {},
                    skillsPanelContent = { TextForTest() })
            }
        }
        val replace = rule.onNodeWithText(text(R.string.note_chat_replace))
        replace.performScrollTo().performClick()
        val undo = rule.onNodeWithText(text(R.string.common_undo))
        undo.assertIsDisplayed()
        val replaceBounds = replace.fetchSemanticsNode().boundsInRoot
        val undoBounds = undo.fetchSemanticsNode().boundsInRoot
        assertEquals(replaceBounds.center.y, undoBounds.center.y, 3f)
        rule.runOnIdle {
            assertEquals("First paragraph\nSecond paragraph", controller.state.value.appliedContent)
            assertEquals(turn.id, controller.state.value.appliedTurnId)
        }
        undo.performClick()
        undo.assertDoesNotExist()
        rule.runOnIdle { assertNull(controller.state.value.undoContent) }
    }

    @Test fun suggestionFillsComposerWithoutSendingAndMenuIsAlwaysAvailable() {
        show()
        rule.onNodeWithText(text(R.string.note_chat_quick_skill_rewrite_description)).assertIsDisplayed()
        val prompt = text(R.string.note_chat_suggestions_script)
        rule.onNodeWithText(prompt).performScrollTo().performClick()
        rule.onNode(hasSetTextAction()).assertTextEquals(prompt)
        rule.runOnIdle { assertTrue(controller.state.value.turns.isEmpty()) }
        rule.onNodeWithContentDescription(text(R.string.note_chat_menu)).performClick()
        rule.onNodeWithText(text(R.string.note_chat_all_skills)).assertIsDisplayed()
        rule.onNodeWithText(text(R.string.note_chat_clear_action)).assertDoesNotExist()
    }

    @Test fun clearRequiresConfirmationAndKeepsUnsentText() {
        show(listOf(NoteConversationTurn(message = "Question", answer = "Answer", noteFingerprint = "hash")))
        rule.runOnIdle { controller.input("Unsent draft") }
        rule.onNodeWithContentDescription(text(R.string.note_chat_menu)).performClick()
        rule.onNodeWithText(text(R.string.note_chat_clear_action)).performClick()
        rule.onNodeWithText(text(R.string.note_chat_clear_message)).assertIsDisplayed()
        rule.onNodeWithText(text(R.string.common_cancel)).performClick()
        rule.runOnIdle { assertEquals(1, controller.state.value.turns.size) }
        rule.onNodeWithContentDescription(text(R.string.note_chat_menu)).performClick()
        rule.onNodeWithText(text(R.string.note_chat_clear_action)).performClick()
        rule.onNodeWithText(text(R.string.note_chat_clear_action)).performClick()
        rule.runOnIdle {
            assertTrue(controller.state.value.turns.isEmpty())
            assertEquals("Unsent draft", controller.state.value.input)
        }
    }
}

@androidx.compose.runtime.Composable
private fun TextForTest() { androidx.compose.material3.Text("Test skills panel") }
