package com.sponteoai.chillscript.ai

import com.sponteoai.chillscript.preferences.TranslateTargetLanguage
import com.sponteoai.chillscript.preferences.CreatorSkillPreferences
import kotlinx.serialization.json.*
import android.content.SharedPreferences
import java.lang.reflect.Proxy
import com.sponteoai.chillscript.preferences.RepurposeFormat
import com.sponteoai.chillscript.preferences.RepurposePackPreferences
import org.junit.Assert.assertFalse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentRecipeTest {
    @Test fun builtInLibraryMatchesIosSkillSet() {
        assertEquals(10, BuiltInRecipes.all.size)
        assertTrue(BuiltInRecipes.all.none { it.id == "timed_script" })
        assertEquals(BuiltInRecipes.all.size, BuiltInRecipes.all.map { it.id }.toSet().size)
    }

    @Test fun legacySkillCategoriesAreIgnoredAndNotSavedAgain() {
        val json = Json { ignoreUnknownKeys = true }
        for (category in listOf("THINK", "SHAPE", "PUBLISH")) {
            val legacy = buildJsonObject {
                put("id", "custom_legacy")
                put("name", "My skill")
                put("description", "My description")
                put("prompt", "Keep my instructions")
                put("category", category)
                put("isCustom", true)
            }
            val recipe = json.decodeFromString<List<AgentRecipe>>(JsonArray(listOf(legacy)).toString()).single()
            assertTrue(recipe.isCustom)
            assertEquals("Keep my instructions", recipe.prompt)
            val encoded = json.encodeToString(AgentRecipe.serializer(), recipe)
            assertFalse(Json.parseToJsonElement(encoded).jsonObject.containsKey("category"))
            assertEquals(recipe, json.decodeFromString<AgentRecipe>(encoded))

            val legacyTurn = buildJsonObject {
                put("message", "My skill")
                put("recipe", legacy)
                put("answer", "Saved result")
                put("noteFingerprint", "old")
            }
            val turn = json.decodeFromString<List<NoteConversationTurn>>(JsonArray(listOf(legacyTurn)).toString()).single()
            assertEquals(recipe, turn.recipe)
            assertEquals("Saved result", turn.answer)
            val saved = json.encodeToString(NoteConversationTurn.serializer(), turn)
            assertFalse(Json.parseToJsonElement(saved).jsonObject["recipe"]!!.jsonObject.containsKey("category"))
        }
    }

    @Test fun titleThumbnailUsesApprovedPromptInStandaloneAndConversation() {
        val recipe = BuiltInRecipes.all.first { it.id == "title_thumbnail" }
        val source = "A tutorial about organizing saved ideas"
        val standalone = recipe.requestPrompts(source)
        assertTrue(standalone.first.contains(recipe.prompt))
        assertTrue(standalone.first.contains(source))
        val history = listOf(NoteConversationTurn(
            message = "Use a calm tone for beginners", answer = "Agreed",
            noteFingerprint = NoteConversationPrompt.fingerprint(source),
        ))
        val (prompt, system) = NoteConversationPrompt.build(source, history, recipe.name, recipe)
        val payload = Json.parseToJsonElement(prompt).jsonObject
        assertEquals(recipe.prompt, payload["request"]!!.jsonPrimitive.content)
        assertEquals(source, payload["currentNote"]!!.jsonPrimitive.content)
        assertTrue(prompt.contains("Use a calm tone for beginners"))
        assertTrue(system.contains("Follow the latest user request"))
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

    @Test fun translateDefaultIsSharedByStandaloneAndConversation() {
        val recipe = BuiltInRecipes.all.first { it.id == "translate" }
        val language = CreatorSkillPreferences.translateTargetLanguage().promptName
        assertTrue(recipe.requestPrompts("Hello").first.contains("into $language"))
        val (prompt, _) = NoteConversationPrompt.build("Hello", emptyList(), "Translate", recipe)
        val payload = Json.parseToJsonElement(prompt).jsonObject
        assertEquals("Default target language: $language.", payload["savedDefaults"]!!.jsonPrimitive.content)
        assertTrue(recipe.requestPrompts("Hello", "Japanese").first.contains("into Japanese"))
    }

    @Test fun translateLanguageMergesPortugueseVariantsAndFallsBackSafely() {
        assertEquals(TranslateTargetLanguage.ENGLISH, TranslateTargetLanguage.fromRawValue("invalid"))
        assertEquals(TranslateTargetLanguage.ENGLISH, TranslateTargetLanguage.fromRawValue(null))
        assertEquals("Traditional Chinese", TranslateTargetLanguage.fromRawValue("zh-Hant").promptName)
        assertEquals("Portuguese", TranslateTargetLanguage.fromRawValue("pt-PT").promptName)
        assertEquals("Portuguese", TranslateTargetLanguage.fromRawValue("pt-BR").promptName)
        assertEquals("Português", TranslateTargetLanguage.fromRawValue("pt-PT").displayName)
        assertEquals(1, TranslateTargetLanguage.entries.count { it.promptName == "Portuguese" })
    }

    private fun repurposeSettings(values: Map<String, Any>): SharedPreferences =
        Proxy.newProxyInstance(SharedPreferences::class.java.classLoader, arrayOf(SharedPreferences::class.java)) { _, method, args ->
            when (method.name) {
                "getBoolean", "getString", "getInt" -> values[args!![0] as String] ?: args[1]
                else -> error("Unexpected preferences call: ${method.name}")
            }
        } as SharedPreferences

    @Test fun brandVoiceExamplesMigrateAndStayDeleted() {
        val legacy = com.sponteoai.chillscript.preferences.BrandVoicePreferences.load(repurposeSettings(mapOf(
            "brandVoiceSample" to "Legacy writing", "brandVoiceTone" to "Old tone",
        )))
        assertEquals(listOf("Legacy writing"), legacy.samples)
        val multiple = com.sponteoai.chillscript.preferences.BrandVoicePreferences.load(repurposeSettings(mapOf(
            "brandVoiceSamples" to "[\"First example\",\"  \",\"Second example\"]",
        )))
        assertEquals(listOf("First example", "Second example"), multiple.samples)
        assertTrue(multiple.promptProfile.contains("Writing example 2:\nSecond example"))
        assertTrue(!multiple.promptProfile.contains("Old tone"))
        val deleted = com.sponteoai.chillscript.preferences.BrandVoicePreferences.load(repurposeSettings(mapOf(
            "brandVoiceSamples" to "[]", "brandVoiceSample" to "Legacy writing",
        )))
        assertTrue(!deleted.isConfigured)
    }

    @Test fun repurposeDefaultsAndLegacySelectionsArePreserved() {
        val defaults = listOf(RepurposeFormat.TIKTOK, RepurposeFormat.INSTAGRAM_REELS)
        assertEquals(defaults, RepurposePackPreferences.load(null).selectedFormats)
        assertEquals(defaults, RepurposePackPreferences.load(repurposeSettings(mapOf("repurposePackFormatInstagramCarousel" to true))).selectedFormats)
        val previous = RepurposePackPreferences.load(repurposeSettings(mapOf(
            "repurposePackFormatXPost" to true, "repurposePackFormatInstagramCarousel" to true,
        )))
        assertEquals(listOf(RepurposeFormat.X_POST), previous.selectedFormats)
        val selected = RepurposePackPreferences.load(repurposeSettings(mapOf(
            "repurposePackFormatYouTubeShorts" to true, "repurposePackFormatNewsletter" to true,
            "repurposePackShortVideoSeconds" to 90, "repurposePackIncludeCTA" to false,
            "repurposePackTone" to "bold", "repurposePackLongVideoMinutes" to 8,
        )))
        assertEquals(listOf(RepurposeFormat.YOUTUBE_SHORTS, RepurposeFormat.NEWSLETTER), selected.selectedFormats)
        assertEquals(8, selected.longVideoMinutes)
        assertEquals("", selected.lengthInstruction)
    }

    @Test fun repurposeDefaultsReachStandaloneAndConversationAsVideoScripts() {
        val recipe = BuiltInRecipes.all.first { it.id == "repurpose_pack" }
        val (prompt, system) = recipe.requestPrompts("My edited draft")
        assertTrue(prompt.contains("TikTok, Instagram Reels"))
        assertTrue(!prompt.contains("Short video target:"))
        assertTrue(!prompt.contains("Tone:"))
        assertTrue(!system.contains("call to action"))
        assertTrue(system.contains("ready-to-record video script"))
        val (chat, _) = NoteConversationPrompt.build("My edited draft", emptyList(), "Repurpose", recipe)
        val saved = Json.parseToJsonElement(chat).jsonObject["savedDefaults"]!!.jsonPrimitive.content
        assertTrue(!saved.contains("Short video target:"))
        assertTrue(!saved.contains("Tone:"))
        assertTrue(!saved.contains("Include CTA"))
        assertTrue(saved.contains("ready-to-record video script"))
        assertTrue(saved.contains("## Instagram Reels"))
    }

    @Test fun translateInstructionIsIncludedAtRuntime() {
        val recipe = BuiltInRecipes.all.first { it.id == "translate" }
        val (prompt, _) = recipe.requestPrompts("你好", "French")
        assertTrue(prompt.contains("Target language: French"))
    }
    @org.junit.Test fun customIconSerializationRemainsCompatibleWithExistingSkills() {
        val old = """{"id":"custom_old","name":"Old","description":"Custom skill","prompt":"Rewrite","isCustom":true}"""
        val json = kotlinx.serialization.json.Json
        val legacy = json.decodeFromString<AgentRecipe>(old)
        org.junit.Assert.assertEquals("sparkles", legacy.systemIcon)
        val chosen = legacy.copy(systemIcon = "lightbulb.fill")
        org.junit.Assert.assertEquals(chosen, json.decodeFromString<AgentRecipe>(json.encodeToString(AgentRecipe.serializer(), chosen)))
    }

}
