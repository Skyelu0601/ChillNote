package com.sponteoai.chillscript.ai

import androidx.annotation.StringRes
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.preferences.CaptionPackPlatform
import com.sponteoai.chillscript.preferences.CreatorSkillPreferences
import com.sponteoai.chillscript.preferences.RepurposePackPreferences
import com.sponteoai.chillscript.preferences.RepurposeFormat
import kotlinx.serialization.Serializable

@Serializable
data class AgentRecipe(
    val id: String,
    val name: String,
    val description: String,
    val prompt: String,
    val isCustom: Boolean = false,
    val systemIcon: String = "sparkles",
)

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
            Analyze the content we are discussing with an evidence-based breakdown of what could make it appealing and shareable. Base every finding on the supplied content, not generic viral-content advice.

            Return exactly three sections, with headings and explanations in the content's language unless the user has requested another language:

            1. What works
            - Identify up to 3 specific strengths across the opening, development, and ending when those parts are present.
            - For each strength, quote a short, exact excerpt and explain how it could attract attention, sustain interest, deliver value, or encourage sharing. Connect the mechanism to this content and its likely audience.

            2. What could improve
            - Identify 1-3 concrete weaknesses or gaps. Quote the relevant sentence or identify the specific passage; for a missing element, say where it is missing.
            - Explain the effect on the reader or viewer, then give a directly usable rewrite example for each issue while preserving the original meaning and supported facts.
            - Do not manufacture weaknesses or force a rewrite when the content does not support one.

            3. What to borrow
            - Extract one reusable content structure from this piece, showing how the opening, development, payoff, and ending fit together when present.
            - Give a short fill-in outline the user can adapt to a different topic. Borrow the structure, not the source author's distinctive wording, claims, or personal experiences.

            Evidence limits:
            - Separate observable textual evidence from hypotheses about audience response. Do not claim proven reasons for virality, actual performance metrics, or guaranteed results.
            - With text or a transcript alone, do not assess unseen visuals, editing, music, or delivery.
            - If the content is too short or incomplete, state the specific limit within the relevant section. Never invent excerpts, missing context, facts, or experiences.
            - Keep the analysis concise and specific. Return only the three-section breakdown, not a full rewrite of the content.
        """.trimIndent()),
        AgentRecipe("summarize", "Summarize", "Turn a note into a clear summary", """
            Summarize only what is in the note. Keep the same language, intent, key facts, decisions, and action items. Use bullets for long or messy notes. Flag ambiguity instead of guessing.
        """.trimIndent()),
        AgentRecipe("translate", "Translate", "Translate while preserving formatting", "Translate the note into the requested target language. Preserve meaning, tone, Markdown, proper nouns, URLs, code, and hashtags. Return only the translation."),
        AgentRecipe("humanizer", "Humanizer", "Make writing sound natural and specific", """
            Make this existing note sound natural, human-written, and specific. Keep the same language, meaning, facts, structure, audience, and useful formatting. Remove stiff, padded, promotional, generic, repetitive, or chatbot-like wording. Do not invent facts, citations, anecdotes, or personality. Return only the revised text.
        """.trimIndent()),
        AgentRecipe("rewrite", "Rewrite Content", "Create an original reusable version", """
            Rewrite this existing note into an original, natural version. Keep the same language, core meaning, facts, intent, and useful structure. Change distinctive wording, sentence structure, transitions, and examples rather than lightly paraphrasing. Remove transcript filler and repetition. Do not invent facts, stats, quotes, or experiences. Return only the rewritten text.
        """.trimIndent()),
        AgentRecipe("style_match", "Brand Voice", "Polish into a consistent creator voice", "Rewrite the note in a natural, consistent writing voice. Keep the same language and preserve every fact, the structure, and purpose. Do not add claims. Return only the rewritten note."),
        AgentRecipe("hook_generator", "Write Hooks", "Generate 8 distinct opening hooks", """
            Generate a mixed Hook Pack with 8 distinct opening lines from this note. Keep the same language. Include pain point, contrarian, curiosity gap, how-to, mistake, story, result-first, and direct statement hooks. Label each type. Keep each concise and speakable. No clickbait, fake urgency, hype, copied distinctive wording, or unsupported claims. Return only the Hook Pack.
        """.trimIndent()),
        AgentRecipe("title_thumbnail", "Titles & Thumbnail Text", "Write titles and thumbnail text.", """
            Create 5 distinct title and thumbnail text pairs based on the provided notes.

            For each pair, include:
            - Title: A clear, specific title that gives viewers a reason to watch.
            - Thumbnail text: A short phrase, ideally 3–8 words, that complements the title without repeating it.
            - Angle: One sentence explaining what the pair emphasizes.

            Rules:
            - Use the same language as the notes unless the user requests another language.
            - Give each pair a different angle, such as a practical benefit, a question, a mistake, a contrast, or a surprising insight. Use only angles supported by the notes.
            - Make the title and thumbnail text work together to communicate one clear idea.
            - Keep thumbnail text easy to read at a glance.
            - Avoid clickbait, fake urgency, exaggerated promises, and unsupported claims.
            - Do not invent numbers, results, quotes, or personal experiences.
            - If the notes contain third-party content, use the underlying ideas without copying distinctive wording.
            - Respect any platform, audience, or tone specified by the user.
            - Return only the 5 numbered pairs.
        """.trimIndent()),
        AgentRecipe("caption_pack", "Write Captions", "Create platform-ready creator captions", """
            Create an original Caption Pack for TikTok, Instagram Reels, and YouTube Shorts. Keep the same language. Treat pasted creator material as private inspiration, not source copy. Do not closely paraphrase distinctive wording or invent claims, stats, experiences, discounts, or results. For each platform provide ready-to-use copy and no more than 5 relevant hashtags. Return only the Caption Pack.
        """.trimIndent()),
        AgentRecipe("repurpose_pack", "Repurpose", "Turn one note into native social posts", """
            Repurpose this long-form note into native posts for X, LinkedIn, and an Instagram carousel outline. Keep the same language and preserve the thesis, facts, and point of view. Rewrite natively for each format instead of truncating the same paragraph. Do not invent facts, stats, quotes, or results. Return only the posts with clear platform headings.
        """.trimIndent()),
    )
}

fun AgentRecipe.requestPrompts(content: String, instruction: String? = null): Pair<String, String> {
    val languageRule = """
        - Keep the output in the same language(s) as the input.
        - If the input is mixed-language, preserve each segment's original language instead of normalizing to a single language.
        - Do NOT translate unless explicitly requested.
    """.trimIndent()

    return when (id) {
        "translate" -> {
            val targetLanguage = instruction?.trim().takeUnless { it.isNullOrBlank() } ?: CreatorSkillPreferences.translateTargetLanguage().promptName
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
                    - Infer the shared tone, vocabulary, sentence rhythm, and expression style across the writing examples. Prioritize the current request over example style.
                    - Treat example posts as style references only. Do not copy their sentences, phrases, claims, or topics.
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
            val threadLengthInstruction = preferences.lengthInstruction

            val userPrompt = buildString {
                appendLine("Adapt this draft for these target platforms: $formatNames.")
                appendLine()
                if (threadLengthInstruction.isNotEmpty()) appendLine(threadLengthInstruction)
                appendLine()
                appendLine("Current draft:")
                append(content)
            }
            val systemPrompt = """
                ${RepurposePackPreferences.adaptationRules}

                Core rules:
                $languageRule
                - First identify the single core thesis and 3-5 key takeaways, then reshape them per platform.
                - Rewrite natively for each format. Do not truncate the same paragraph and paste it everywhere.
                - Do not invent facts, stats, quotes, or results that are not supported by the content.
                - Preserve the author's intent and point of view.
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
