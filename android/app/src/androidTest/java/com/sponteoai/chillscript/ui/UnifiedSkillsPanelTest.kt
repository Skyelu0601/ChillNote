package com.sponteoai.chillscript.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeUp
import androidx.compose.ui.test.swipeDown
import com.sponteoai.chillscript.ui.skills.CreatorSkillsSheet
import org.junit.Assert.assertTrue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.test.assertHasNoClickAction
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import com.sponteoai.chillscript.ui.skills.CreatorSkillSettingsDialog
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.ai.BuiltInRecipes
import com.sponteoai.chillscript.ui.skills.CreatorSkillsLibrary
import com.sponteoai.chillscript.ui.theme.ChillScriptTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class UnifiedSkillsPanelTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun scrollingKeepsSheetHeightStable() {
        val heights = mutableListOf<Int>()
        var dismissCount = 0
        composeRule.setContent {
            ChillScriptTheme {
                CreatorSkillsSheet(onDismiss = { dismissCount++ }) {
                    Box(Modifier.fillMaxSize().onSizeChanged { heights += it.height }) {
                        CreatorSkillsLibrary(
                            available = BuiltInRecipes.all, favorites = BuiltInRecipes.all.take(4), onReplaceFavorite = { _, _ -> }, isPro = true,
                            onBack = {}, onToggle = {}, onRequestCustomUpgrade = {},
                            onCreateCustom = { _, _, _ -> }, onDeleteCustom = {}, isSheet = true,
                        )
                    }
                }
            }
        }
        composeRule.waitForIdle()
        val initialHeight = composeRule.runOnIdle {
            val height = heights.last()
            heights.clear()
            height
        }
        repeat(3) {
            composeRule.onNode(hasScrollAction()).performTouchInput { swipeUp(durationMillis = 350) }
            composeRule.waitForIdle()
        }
        // Reverse within the list without deliberately pulling the sheet down to dismiss it.
        composeRule.onNode(hasScrollAction()).performTouchInput {
            swipeDown(startY = centerY, endY = centerY + 100f, durationMillis = 600)
        }
        composeRule.waitForIdle()
        composeRule.runOnIdle {
            assertTrue("Sheet height changed during scrolling: $initialHeight -> $heights",
                heights.all { kotlin.math.abs(it - initialHeight) <= 1 })
            assertEquals(0, dismissCount)
        }
    }

    @Test
    fun repurposeAdditionalPlatformsAreListedWithoutExpanding() {
        val resources = InstrumentationRegistry.getInstrumentation().targetContext.resources
        composeRule.setContent {
            ChillScriptTheme {
                CreatorSkillSettingsDialog(recipeId = "repurpose_pack", onDismiss = {})
            }
        }
        composeRule.onNodeWithText(resources.getString(R.string.repurpose_pack_settings_more_platforms))
            .performScrollTo().assertIsDisplayed().assertHasNoClickAction()
        listOf(
            R.string.repurpose_pack_format_x_post,
            R.string.repurpose_pack_format_threads,
            R.string.repurpose_pack_format_linkedin,
        ).forEach { label ->
            composeRule.onNodeWithText(resources.getString(label))
                .performScrollTo().assertIsDisplayed()
        }
    }

    @Test
    fun managementOnlyPanelConfiguresAndSelectsFavorites() {
        val resources = InstrumentationRegistry.getInstrumentation().targetContext.resources
        val caption = BuiltInRecipes.all.first { it.id == "caption_pack" }
        val installed = mutableStateOf(listOf(caption))
        var closeCount = 0
        composeRule.setContent {
            ChillScriptTheme {
                CreatorSkillsLibrary(
                    available = listOf(caption), favorites = installed.value, onReplaceFavorite = { _, _ -> }, isPro = true,
                    onBack = { closeCount++ },
                    onToggle = { recipe ->
                        installed.value = if (recipe in installed.value) emptyList() else listOf(recipe)
                    },
                    onRequestCustomUpgrade = {}, onCreateCustom = { _, _, _ -> }, onDeleteCustom = {},
                    isSheet = true,
                )
            }
        }
        val panelTitle = resources.getString(R.string.creator_skills_manage)
        val removeLabel = resources.getString(R.string.creator_skills_remove)
        val doneLabel = resources.getString(R.string.common_done)
        val captionName = resources.getString(R.string.recipe_caption_pack_name)
        composeRule.onNodeWithText(panelTitle).assertIsDisplayed()
        composeRule.onNodeWithContentDescription(removeLabel).assertIsDisplayed()
        composeRule.onNodeWithContentDescription(resources.getString(R.string.caption_pack_settings_title)).performClick()
        composeRule.onNodeWithText(doneLabel).performClick()
        composeRule.onNodeWithText(panelTitle).assertIsDisplayed()
        composeRule.onNodeWithText(captionName).assertHasNoClickAction()
        composeRule.onNodeWithContentDescription(removeLabel).performClick()
        composeRule.onNodeWithText(resources.getString(R.string.creator_skills_minimum_favorite)).assertIsDisplayed()
        composeRule.onNodeWithText(resources.getString(R.string.common_ok)).performClick()
        composeRule.runOnIdle {
            assertEquals(listOf(caption), installed.value)
            assertEquals(0, closeCount)
        }
        composeRule.onNodeWithText(captionName).assertHasNoClickAction()
        composeRule.onNodeWithText(resources.getString(R.string.common_close)).performClick()
        composeRule.runOnIdle { assertEquals(1, closeCount) }
    }
}
