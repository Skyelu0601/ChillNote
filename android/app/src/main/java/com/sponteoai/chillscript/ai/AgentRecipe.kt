package com.sponteoai.chillscript.ai

import androidx.annotation.StringRes
import com.sponteoai.chillscript.R
import kotlinx.serialization.Serializable

@Serializable
data class AgentRecipe(
    val id: String,
    val name: String,
    val description: String,
    val prompt: String,
    val category: RecipeCategory,
    val isCustom: Boolean = false,
)

@Serializable
enum class RecipeCategory { THINK, SHAPE, PUBLISH }

enum class AISkillApplyMode(@StringRes val title: Int) {
    REPLACE_SELECTION(R.string.ai_skill_apply_replace_selection),
    INSERT_AT_CURSOR(R.string.ai_skill_apply_insert_at_cursor),
    INSERT_BELOW_SELECTION(R.string.ai_skill_apply_insert_below_selection),
    APPEND_TO_END(R.string.ai_skill_apply_append),
    REPLACE_ALL(R.string.ai_skill_apply_replace_all),
}

data class TextSelection(val start: Int, val end: Int) {
    fun normalized(text: String): TextSelection {
        val safeStart = start.coerceIn(0, text.length)
        val safeEnd = end.coerceIn(safeStart, text.length)
        return TextSelection(safeStart, safeEnd)
    }

    val isCollapsed: Boolean get() = start == end
}

object AISkillTextApplication {
    fun availableModes(selection: TextSelection): List<AISkillApplyMode> = if (selection.isCollapsed) {
        listOf(AISkillApplyMode.INSERT_AT_CURSOR, AISkillApplyMode.APPEND_TO_END, AISkillApplyMode.REPLACE_ALL)
    } else {
        listOf(
            AISkillApplyMode.REPLACE_SELECTION,
            AISkillApplyMode.INSERT_BELOW_SELECTION,
            AISkillApplyMode.APPEND_TO_END,
            AISkillApplyMode.REPLACE_ALL,
        )
    }

    fun apply(source: String, result: String, selection: TextSelection, mode: AISkillApplyMode): String {
        val safe = selection.normalized(source)
        return when (mode) {
            AISkillApplyMode.REPLACE_SELECTION -> source.replaceRange(safe.start, safe.end, result)
            AISkillApplyMode.INSERT_AT_CURSOR -> source.replaceRange(safe.start, safe.start, result)
            AISkillApplyMode.INSERT_BELOW_SELECTION -> source.replaceRange(safe.end, safe.end, "\n\n$result")
            AISkillApplyMode.APPEND_TO_END -> source + if (source.isBlank()) result else "\n\n$result"
            AISkillApplyMode.REPLACE_ALL -> result
        }
    }
}

object BuiltInRecipes {
    val all = listOf(
        AgentRecipe("why_viral", "Why Viral", "Analyze why an idea could spread", """
            Analyze why this content might spread without pretending you have real platform metrics.
            Keep the output in the same language. Identify the promise, emotional trigger, audience, tension, novelty, and shareability. Separate strengths from weaknesses and give 3 truthful, concrete improvements.
            Output: 1. Viral thesis 2. Why it could spread 3. What holds it back 4. How to strengthen it.
        """.trimIndent(), RecipeCategory.THINK),
        AgentRecipe("summarize", "Summarize", "Turn a note into a clear summary", """
            Summarize only what is in the note. Keep the same language, intent, key facts, decisions, and action items. Use bullets for long or messy notes. Flag ambiguity instead of guessing.
        """.trimIndent(), RecipeCategory.THINK),
        AgentRecipe("translate", "Translate", "Translate while preserving formatting", "Translate the note into the requested target language. Preserve meaning, tone, Markdown, proper nouns, URLs, code, and hashtags. Return only the translation.", RecipeCategory.SHAPE),
        AgentRecipe("humanizer", "Humanizer", "Make writing sound natural and specific", """
            Make this existing note sound natural, human-written, and specific. Keep the same language, meaning, facts, structure, audience, and useful formatting. Remove stiff, padded, promotional, generic, repetitive, or chatbot-like wording. Do not invent facts, citations, anecdotes, or personality. Return only the revised text.
        """.trimIndent(), RecipeCategory.SHAPE),
        AgentRecipe("rewrite", "Rewrite", "Create an original reusable version", """
            Rewrite this existing note into an original, natural version. Keep the same language, core meaning, facts, intent, and useful structure. Change distinctive wording, sentence structure, transitions, and examples rather than lightly paraphrasing. Remove transcript filler and repetition. Do not invent facts, stats, quotes, or experiences. Return only the rewritten text.
        """.trimIndent(), RecipeCategory.SHAPE),
        AgentRecipe("style_match", "Brand Voice", "Polish into a consistent creator voice", "Rewrite the note in a natural, consistent writing voice. Keep the same language and preserve every fact, the structure, and purpose. Do not add claims. Return only the rewritten note.", RecipeCategory.SHAPE),
        AgentRecipe("hook_generator", "Hook", "Generate 8 distinct opening hooks", """
            Generate a mixed Hook Pack with 8 distinct opening lines from this note. Keep the same language. Include pain point, contrarian, curiosity gap, how-to, mistake, story, result-first, and direct statement hooks. Label each type. Keep each concise and speakable. No clickbait, fake urgency, hype, copied distinctive wording, or unsupported claims. Return only the Hook Pack.
        """.trimIndent(), RecipeCategory.SHAPE),
        AgentRecipe("caption_pack", "Caption", "Create platform-ready creator captions", """
            Create an original Caption Pack for TikTok, Instagram Reels, and YouTube Shorts. Keep the same language. Treat pasted creator material as private inspiration, not source copy. Do not closely paraphrase distinctive wording or invent claims, stats, experiences, discounts, or results. For each platform provide ready-to-use copy and no more than 5 relevant hashtags. Return only the Caption Pack.
        """.trimIndent(), RecipeCategory.PUBLISH),
        AgentRecipe("timed_script", "Timed Script", "Create a 45-second short video script", """
            Create a recordable 45-second short video script of about 105-130 spoken words. Keep the same language. Use a strong opening, clear middle, payoff, and a light CTA only when it fits. Do not copy distinctive reference wording or invent facts. Return only the script without labels, timestamps, word count, or explanation.
        """.trimIndent(), RecipeCategory.PUBLISH),
        AgentRecipe("repurpose_pack", "Repurpose", "Turn one note into native social posts", """
            Repurpose this long-form note into native posts for X, LinkedIn, and an Instagram carousel outline. Keep the same language and preserve the thesis, facts, and point of view. Rewrite natively for each format instead of truncating the same paragraph. Do not invent facts, stats, quotes, or results. Return only the posts with clear platform headings.
        """.trimIndent(), RecipeCategory.PUBLISH),
    )

    val defaultIds = setOf("hook_generator", "caption_pack", "rewrite", "repurpose_pack")
}

fun AgentRecipe.requestPrompts(content: String, instruction: String? = null): Pair<String, String> {
    val languageRule = "Detect the main language of the supplied note and return the result in that same language unless translation is explicitly requested. Preserve mixed-language names and quoted text."
    val effectiveInstruction = when (id) {
        "translate" -> "$prompt\nTarget language: ${instruction?.trim().takeUnless { it.isNullOrBlank() } ?: "English"}."
        else -> prompt
    }
    val userPrompt = "Instruction:\n$effectiveInstruction\n\nNotes:\n$content"
    val systemPrompt = """
        You are a creator writing assistant working on an existing note, not answering a chat message.
        Rules:
        - $languageRule
        - Follow the instruction precisely.
        - Preserve Markdown, code blocks, and line breaks when useful.
        - Return only the requested result without commentary or a preamble.
    """.trimIndent()
    return userPrompt to systemPrompt
}
