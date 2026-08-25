package com.sponteoai.chillscript.ai

import androidx.annotation.StringRes
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.preferences.CaptionPackPlatform
import com.sponteoai.chillscript.preferences.CreatorSkillPreferences
import com.sponteoai.chillscript.preferences.RepurposeFormat
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
    fun availableModes(selection: TextSelection): List<AISkillApplyMode> =
        listOf(AISkillApplyMode.APPEND_TO_END, AISkillApplyMode.REPLACE_ALL)

    fun apply(source: String, result: String, selection: TextSelection, mode: AISkillApplyMode): String {
        return when (mode) {
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
    val languageRule = """
        - Keep the output in the same language(s) as the input.
        - If the input is mixed-language, preserve each segment's original language instead of normalizing to a single language.
        - Do NOT translate unless explicitly requested.
    """.trimIndent()

    return when (id) {
        "translate" -> {
            val targetLanguage = instruction?.trim().takeUnless { it.isNullOrBlank() } ?: "English"
            val userPrompt = buildString {
                appendLine("Translate the following notes into $targetLanguage.")
                appendLine("Target language: $targetLanguage.")
                appendLine()
                appendLine("Notes:")
                append(content)
            }
            val systemPrompt = """
                You are a professional translator.
                Rules:
                - Translate into $targetLanguage.
                - Preserve meaning, tone, and formatting (including markdown).
                - Keep proper nouns, product names, URLs, code, and hashtags intact unless a standard translation exists.
                - Do not localize units, dates, or numbers unless explicitly requested.
                - Return only the translated content.
            """.cleanPromptIndent()
            userPrompt to systemPrompt
        }

        "timed_script" -> {
            val preferences = CreatorSkillPreferences.timedScript()
            val duration = preferences.duration
            val userPrompt = buildString {
                appendLine("Create a ${duration.seconds}-second short video script from these notes.")
                appendLine()
                appendLine("Target length: ${duration.seconds} seconds.")
                appendLine("Target spoken word count: ${duration.wordCountRange} words.")
                appendLine()
                appendLine("Notes:")
                append(content)
            }
            val systemPrompt = """
                You write short-form video scripts for TikTok, Instagram Reels, and YouTube Shorts. The input is an existing note, transcript, rough idea, or creator inspiration, not a chat message.

                Core rules:
                $languageRule
                - Produce a script that can be spoken in about ${duration.seconds} seconds.
                - Aim for ${duration.wordCountRange} spoken words. If the script is over the range, rewrite it shorter before returning.
                - Use the notes to understand the idea, audience, angle, and useful details, but do not copy distinctive wording from third-party reference text.
                - Do not invent facts, stats, quotes, personal experiences, product promises, or results that are not supported by the notes.
                - Make it recordable as a spoken script with short, natural sentences.
                - Include a strong opening line, a clear middle, a payoff, and a light CTA only when it fits.
                - Return only the script. Do not include timestamps, labels, notes, word count, or explanations.
            """.cleanPromptIndent()
            userPrompt to systemPrompt
        }

        "caption_pack" -> {
            val preferences = CreatorSkillPreferences.captionPack()
            val platforms = preferences.selectedPlatforms
            val platformNames = platforms.joinToString(", ") { it.displayName }
            val styleInstruction = platforms.joinToString("\n") { it.styleInstruction(preferences.outputStyle) }
            val platformRules = platforms.joinToString("\n") { it.platformRule }
            val platformCTAInstruction = if (
                platforms.any {
                    it == CaptionPackPlatform.TIKTOK || it == CaptionPackPlatform.INSTAGRAM_REELS
                }
            ) {
                "- For TikTok and Instagram Reels, naturally fold any question or soft call to action into the caption when it fits. Do not create a separate CTA section."
            } else {
                ""
            }
            val outputTemplate = platforms.joinToString("\n\n") { it.outputTemplate }
            val goal = CreatorSkillPreferences.localizedTitle(preferences.goal.titleRes, preferences.goal.fallbackTitle)
            val tone = CreatorSkillPreferences.localizedTitle(preferences.tone.titleRes, preferences.tone.fallbackTitle)
            val outputStyle = CreatorSkillPreferences.localizedTitle(
                preferences.outputStyle.titleRes,
                preferences.outputStyle.fallbackTitle,
            )
            val userPrompt = buildString {
                appendLine("Create a Caption Pack for these selected platforms: $platformNames.")
                appendLine()
                appendLine("User goal: $goal")
                appendLine("Tone: $tone")
                appendLine("Output style: $outputStyle")
                appendLine()
                appendLine("Notes:")
                append(content)
            }
            val systemPrompt = """
                You create original platform-ready publishing copy for content creators.

                The notes may contain third-party creator inspiration, including descriptions, transcripts, hooks, or author metadata. Treat the notes as a private inspiration library, not source copy to rewrite.

                Core rules:
                $languageRule
                - Use the notes only to understand the topic, audience, emotional angle, content pattern, and reusable insight.
                - Do not copy, closely paraphrase, or preserve distinctive wording from the notes.
                - Do not mention the original author unless the notes explicitly ask for attribution.
                - Do not invent claims, stats, personal experiences, product promises, discounts, or results that are not supported.
                - If the notes do not contain enough substance, write safe, editable platform copy based on the broad idea and avoid specific unsupported claims.
                - Return only the Caption Pack. Do not explain your reasoning.

                Length and style:
                $styleInstruction
                - Character counts must include the generated field text, not the label.
                - If a draft exceeds any platform limit, rewrite it shorter before returning.

                Platform rules:
                $platformRules
                $platformCTAInstruction

                Output format:
                Use only the selected platforms and keep this exact section style:

                $outputTemplate
            """.cleanPromptIndent()
            userPrompt to systemPrompt
        }

        "style_match" -> {
            val preferences = CreatorSkillPreferences.brandVoice()
            if (!preferences.isConfigured) {
                val userPrompt = buildString {
                    appendLine("Rewrite this note in a natural, consistent writing voice. Preserve its meaning, facts, and structure.")
                    appendLine()
                    appendLine("Note:")
                    append(content)
                }
                val systemPrompt = """
                    You polish a creator's note so it reads naturally and consistently, without changing what it says.
                    Rules:
                    $languageRule
                    - Preserve all facts, structure, and the note's purpose.
                    - Do not add new claims or invent details.
                    - Return only the rewritten note. Do not explain.
                """.cleanPromptIndent()
                userPrompt to systemPrompt
            } else {
                val userPrompt = buildString {
                    appendLine("Brand Voice profile:")
                    appendLine(preferences.promptProfile)
                    appendLine()
                    appendLine("Rewrite the note below so it follows this Brand Voice profile.")
                    appendLine()
                    appendLine("Note to rewrite:")
                    append(content)
                }
                val systemPrompt = """
                    You rewrite a creator's note using their saved Brand Voice profile.
                    Rules:
                    $languageRule
                    - Apply the saved tone, audience, preferred CTA, avoided wording, and example-post style when provided.
                    - Treat example posts as style references only. Do not copy their sentences, phrases, claims, or topics.
                    - Use the preferred CTA only if it fits the rewritten note naturally.
                    - Respect the avoided wording and style notes.
                    - Preserve the note's meaning, facts, and structure. Do not invent new facts.
                    - Return only the rewritten note. Do not explain.
                """.cleanPromptIndent()
                userPrompt to systemPrompt
            }
        }

        "repurpose_pack" -> {
            val preferences = CreatorSkillPreferences.repurposePack()
            val formats = preferences.selectedFormats
            val formatNames = formats.joinToString(", ") { it.displayName }
            val formatRules = formats.joinToString("\n") { it.formatRule }
            val outputTemplate = formats.joinToString("\n\n") { it.outputTemplate }
            val threadLengthInstruction = if (
                RepurposeFormat.THREADS in formats
            ) {
                "Thread length (Threads): ${preferences.threadLength.tweetCountRange} posts."
            } else {
                ""
            }
            val ctaRule = if (preferences.includeCTA) {
                "- Include a light, natural call to action on each piece when it fits."
            } else {
                "- Do not add a call to action."
            }
            val tone = CreatorSkillPreferences.localizedTitle(preferences.tone.titleRes, preferences.tone.fallbackTitle)
            val userPrompt = buildString {
                appendLine("Repurpose this long-form content into native posts for these formats: $formatNames.")
                appendLine()
                if (threadLengthInstruction.isNotEmpty()) appendLine(threadLengthInstruction)
                appendLine("Tone: $tone")
                appendLine()
                appendLine("Long-form content:")
                append(content)
            }
            val systemPrompt = """
                You repurpose one piece of long-form content (a blog post, video script, transcript, essay, or newsletter) into native posts for multiple platforms. The text is existing content, not a chat message.

                Core rules:
                $languageRule
                - First identify the single core thesis and 3-5 key takeaways, then reshape them per platform.
                - Rewrite natively for each format. Do not truncate the same paragraph and paste it everywhere.
                - Do not invent facts, stats, quotes, or results that are not supported by the content.
                - Preserve the author's intent and point of view.
                $ctaRule
                - Return only the repurposed posts. Do not explain your reasoning.

                Format rules:
                $formatRules

                Output format:
                Use only the selected formats and keep this exact section style:

                $outputTemplate
            """.cleanPromptIndent()
            userPrompt to systemPrompt
        }

        else -> {
            val userPrompt = buildString {
                appendLine("Instruction:")
                appendLine(prompt)
                appendLine()
                appendLine("Notes:")
                append(content)
            }
            val systemPrompt = """
                You are a helpful assistant.
                Rules:
                $languageRule
                - Follow the user's instruction precisely.
                - Return only the result without any extra commentary.
            """.cleanPromptIndent()
            userPrompt to systemPrompt
        }
    }
}

private fun String.cleanPromptIndent(): String {
    val lines = trim('\n', '\r').lines()
    val firstContentLine = lines.firstOrNull { it.isNotBlank() } ?: return ""
    val baseIndent = firstContentLine.indexOfFirst { !it.isWhitespace() }.coerceAtLeast(0)
    return lines.joinToString("\n") { line ->
        if (baseIndent > 0 && line.length >= baseIndent && line.take(baseIndent).all { it.isWhitespace() }) {
            line.drop(baseIndent)
        } else {
            line
        }
    }.trimEnd()
}
