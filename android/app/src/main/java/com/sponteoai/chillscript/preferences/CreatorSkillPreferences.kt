package com.sponteoai.chillscript.preferences

import android.content.Context
import android.content.SharedPreferences
import androidx.annotation.StringRes
import com.sponteoai.chillscript.R
import java.util.Locale
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

enum class TranslateTargetLanguage(val rawValue: String, val promptName: String) {
    SIMPLIFIED_CHINESE("zh-Hans", "Simplified Chinese"),
    TRADITIONAL_CHINESE("zh-Hant", "Traditional Chinese"),
    FRENCH("fr", "French"),
    ENGLISH("en", "English"),
    GERMAN("de", "German"),
    JAPANESE("ja", "Japanese"),
    SPANISH("es", "Spanish"),
    PORTUGUESE("pt-BR", "Portuguese"),
    KOREAN("ko", "Korean");

    val displayName: String
        get() = Locale.forLanguageTag(if (this == PORTUGUESE) "pt" else rawValue).let { locale ->
            val name = locale.getDisplayName(locale)
            if (this == PORTUGUESE) name.replaceFirstChar { it.uppercase() } else name
        }

    companion object {
        fun fromRawValue(value: String?): TranslateTargetLanguage =
            if (value in listOf("pt", "pt-PT", "pt-BR")) PORTUGUESE
            else entries.firstOrNull { it.rawValue == value } ?: ENGLISH
    }
}

enum class CaptionPackOutputStyle(
    val rawValue: String,
    @StringRes val titleRes: Int,
    val fallbackTitle: String,
) {
    CONCISE("concise", R.string.caption_pack_output_style_concise, "Concise"),
    BALANCED("balanced", R.string.caption_pack_output_style_balanced, "Balanced"),
    DETAILED("detailed", R.string.caption_pack_output_style_detailed, "Detailed"),
    ;

    companion object {
        fun fromRawValue(value: String?): CaptionPackOutputStyle =
            entries.firstOrNull { it.rawValue == value } ?: BALANCED
    }
}

enum class CaptionPackGoal(
    val rawValue: String,
    @StringRes val titleRes: Int,
    val fallbackTitle: String,
) {
    START_DISCUSSION("startDiscussion", R.string.caption_pack_goal_start_discussion, "Start discussion"),
    GET_SAVES("getSaves", R.string.caption_pack_goal_get_saves, "Get saves"),
    GET_SHARES("getShares", R.string.caption_pack_goal_get_shares, "Get shares"),
    DRIVE_FOLLOWS("driveFollows", R.string.caption_pack_goal_drive_follows, "Drive follows"),
    ;

    companion object {
        fun fromRawValue(value: String?): CaptionPackGoal =
            entries.firstOrNull { it.rawValue == value } ?: START_DISCUSSION
    }
}

enum class CaptionPackTone(
    val rawValue: String,
    @StringRes val titleRes: Int,
    val fallbackTitle: String,
) {
    CASUAL_USEFUL("casualUseful", R.string.caption_pack_tone_casual_useful, "Casual + useful"),
    EDUCATIONAL("educational", R.string.caption_pack_tone_educational, "Educational"),
    BOLD("bold", R.string.caption_pack_tone_bold, "Bold"),
    STORY_DRIVEN("storyDriven", R.string.caption_pack_tone_story_driven, "Story-driven"),
    CREATOR_VOICE("creatorVoice", R.string.caption_pack_tone_creator_voice, "Creator voice"),
    ;

    companion object {
        val captionOptions = entries.filter { it != STORY_DRIVEN && it != CREATOR_VOICE }

        fun fromCaptionRawValue(value: String?): CaptionPackTone =
            captionOptions.firstOrNull { it.rawValue == value } ?: CASUAL_USEFUL

        fun fromRawValue(value: String?): CaptionPackTone =
            entries.firstOrNull { it.rawValue == value } ?: CASUAL_USEFUL
    }
}

enum class CaptionPackPlatform(
    @StringRes val titleRes: Int,
    val displayName: String,
) {
    TIKTOK(R.string.caption_pack_platform_tiktok, "TikTok"),
    INSTAGRAM_REELS(R.string.caption_pack_platform_instagram_reels, "Instagram Reels"),
    YOUTUBE_SHORTS(R.string.caption_pack_platform_youtube_shorts, "YouTube Shorts"),
    YOUTUBE_LONG_VIDEO(R.string.caption_pack_platform_youtube_long_video, "YouTube Long Video"),
    ;

    val platformRule: String
        get() = when (this) {
            TIKTOK -> "- TikTok: Under the platform heading, output ready-to-publish caption text, then a blank line and up to 5 relevant hashtags. Do not include field labels such as Caption or Hashtags (in any language), quotation marks around the caption, or explanatory text. Keep the complete post, including hashtags, under 2,200 characters. Generate hashtags specific to the notes; do not copy template placeholders."
            INSTAGRAM_REELS -> "- Instagram Reels: Under the platform heading, output ready-to-publish caption text, then a blank line and up to 5 relevant hashtags. Do not include field labels such as Caption or Hashtags (in any language), quotation marks around the caption, or explanatory text. Keep the complete post, including hashtags, under 2,200 characters. Generate hashtags specific to the notes; do not copy template placeholders."
            YOUTUBE_SHORTS -> "- YouTube Shorts: Output Title, Description, and Hashtags. Title must be under 100 characters. Description should be compact and mobile-friendly. Hashtags must be 3 or fewer."
            YOUTUBE_LONG_VIDEO -> "- YouTube Long Video: Output SEO Title, Description, Tags, and Pinned Comment. Make the description fuller than Shorts copy, with a clear summary, search-friendly keywords, and a natural CTA. Tags must be comma-separated."
        }

    fun styleInstruction(style: CaptionPackOutputStyle): String = when (this to style) {
        TIKTOK to CaptionPackOutputStyle.CONCISE -> "- TikTok caption target: 120-220 characters."
        TIKTOK to CaptionPackOutputStyle.BALANCED -> "- TikTok caption target: 300-600 characters."
        TIKTOK to CaptionPackOutputStyle.DETAILED -> "- TikTok caption target: 700-1,200 characters."
        INSTAGRAM_REELS to CaptionPackOutputStyle.CONCISE -> "- Instagram Reels caption target: 100-180 characters."
        INSTAGRAM_REELS to CaptionPackOutputStyle.BALANCED -> "- Instagram Reels caption target: 250-500 characters."
        INSTAGRAM_REELS to CaptionPackOutputStyle.DETAILED -> "- Instagram Reels caption target: 600-1,000 characters."
        YOUTUBE_SHORTS to CaptionPackOutputStyle.CONCISE -> "- YouTube Shorts title target: 35-50 characters.\n- YouTube Shorts description target: 80-150 characters."
        YOUTUBE_SHORTS to CaptionPackOutputStyle.BALANCED -> "- YouTube Shorts title target: 50-70 characters.\n- YouTube Shorts description target: 150-300 characters."
        YOUTUBE_SHORTS to CaptionPackOutputStyle.DETAILED -> "- YouTube Shorts title target: 70-90 characters.\n- YouTube Shorts description target: 300-600 characters."
        YOUTUBE_LONG_VIDEO to CaptionPackOutputStyle.CONCISE -> "- YouTube Long Video SEO title target: 55-75 characters.\n- YouTube Long Video description target: 500-900 characters."
        YOUTUBE_LONG_VIDEO to CaptionPackOutputStyle.BALANCED -> "- YouTube Long Video SEO title target: 60-85 characters.\n- YouTube Long Video description target: 900-1,500 characters."
        YOUTUBE_LONG_VIDEO to CaptionPackOutputStyle.DETAILED -> "- YouTube Long Video SEO title target: 70-95 characters.\n- YouTube Long Video description target: 1,500-2,500 characters."
        else -> error("Unsupported caption platform style")
    }

    val outputTemplate: String
        get() = when (this) {
            TIKTOK -> """
                ## TikTok

                [Ready-to-publish caption text]

                [Up to 5 hashtags relevant to the notes]
            """.trimIndent()

            INSTAGRAM_REELS -> """
                ## Instagram Reels

                [Ready-to-publish caption text]

                [Up to 5 hashtags relevant to the notes]
            """.trimIndent()

            YOUTUBE_SHORTS -> """
                ## YouTube Shorts

                Title:
                ...

                Description:
                ...

                Hashtags:
                #Shorts #ContentStrategy #CreatorTips
            """.trimIndent()

            YOUTUBE_LONG_VIDEO -> """
                ## YouTube Long Video

                SEO Title:
                ...

                Description:
                ...

                Tags:
                creator workflow, content strategy, AI tools

                Pinned Comment:
                ...
            """.trimIndent()
        }
}

data class CaptionPackPreferences(
    val includeTikTok: Boolean = true,
    val includeYouTubeShorts: Boolean = true,
    val includeYouTubeLongVideo: Boolean = true,
    val includeInstagramReels: Boolean = true,
    val goal: CaptionPackGoal = CaptionPackGoal.START_DISCUSSION,
    val tone: CaptionPackTone = CaptionPackTone.CASUAL_USEFUL,
    val outputStyle: CaptionPackOutputStyle = CaptionPackOutputStyle.BALANCED,
) {
    val selectedPlatforms: List<CaptionPackPlatform>
        get() = buildList {
            if (includeTikTok) add(CaptionPackPlatform.TIKTOK)
            if (includeInstagramReels) add(CaptionPackPlatform.INSTAGRAM_REELS)
            if (includeYouTubeShorts) add(CaptionPackPlatform.YOUTUBE_SHORTS)
            if (includeYouTubeLongVideo) add(CaptionPackPlatform.YOUTUBE_LONG_VIDEO)
        }.ifEmpty { CaptionPackPlatform.entries }
}

data class BrandVoicePreferences(val samples: List<String> = emptyList()) {
    val isConfigured: Boolean get() = samples.any { it.isNotBlank() }
    val promptProfile: String
        get() = samples.map { it.trim() }.filter { it.isNotEmpty() }
            .mapIndexed { index, sample -> "Writing example ${index + 1}:\n$sample" }
            .joinToString("\n\n")

    companion object {
        fun load(preferences: SharedPreferences?): BrandVoicePreferences {
            val stored = preferences?.getString("brandVoiceSamples", null)
            val samples = stored?.let { runCatching { Json.decodeFromString<List<String>>(it) }.getOrNull() }
                ?: listOf(preferences?.getString("brandVoiceSample", "").orEmpty())
            return BrandVoicePreferences(samples.filter { it.isNotBlank() })
        }
    }
}

enum class RepurposeThreadLength(
    val rawValue: String,
    val tweetCountRange: String,
    @StringRes val titleRes: Int,
) {
    SHORT("short", "3-5", R.string.repurpose_pack_thread_length_short),
    MEDIUM("medium", "6-8", R.string.repurpose_pack_thread_length_medium),
    LONG("long", "9-12", R.string.repurpose_pack_thread_length_long),
    ;

    companion object {
        fun fromRawValue(value: String?): RepurposeThreadLength =
            entries.firstOrNull { it.rawValue == value } ?: MEDIUM
    }
}

enum class RepurposeFormat(val preferenceKey: String, @StringRes val titleRes: Int, val displayName: String) {
    TIKTOK("repurposePackFormatTikTok", R.string.caption_pack_platform_tiktok, "TikTok"),
    INSTAGRAM_REELS("repurposePackFormatInstagramReels", R.string.caption_pack_platform_instagram_reels, "Instagram Reels"),
    YOUTUBE_SHORTS("repurposePackFormatYouTubeShorts", R.string.caption_pack_platform_youtube_shorts, "YouTube Shorts"),
    YOUTUBE_VIDEO("repurposePackFormatYouTubeVideo", R.string.caption_pack_platform_youtube_long_video, "YouTube Video"),
    NEWSLETTER("repurposePackFormatNewsletter", R.string.repurpose_pack_format_newsletter, "Newsletter"),
    X_POST("repurposePackFormatXPost", R.string.repurpose_pack_format_x_post, "X Post"),
    THREADS("repurposePackFormatThreads", R.string.repurpose_pack_format_threads, "Threads"),
    LINKEDIN("repurposePackFormatLinkedIn", R.string.repurpose_pack_format_linkedin, "LinkedIn"),
    ;
    companion object {
        val defaultFormats = listOf(TIKTOK, INSTAGRAM_REELS)
        val primaryFormats = entries.take(5)
        val additionalFormats = entries.takeLast(3)
    }
    val formatRule: String get() = when (this) {
        TIKTOK -> "- TikTok: a ready-to-record video script with a direct, conversational opening, a tightly focused progression, and a natural ending. Reshape the content rather than writing a caption."
        INSTAGRAM_REELS -> "- Instagram Reels: a ready-to-record video script with a relatable opening, clear progression, and a memorable takeaway. Do not output carousel slides or a publishing caption."
        YOUTUBE_SHORTS -> "- YouTube Shorts: a ready-to-record short video script focused on one clear question or insight, delivering its promised answer before a complete ending. Do not output a description or tags."
        YOUTUBE_VIDEO -> "- YouTube Video: a complete long-video script with an introduction, clearly titled chapters, transitions, substantive explanations, and a conclusion. Expand supported ideas, not invented facts. Do not return only an outline."
        NEWSLETTER -> "- Newsletter: a complete email with a subject line, an opening, substantial body sections, and a closing. Target 600-1,000 English words, 1,200-2,000 Chinese characters, or a comparable reading length in other languages when the material supports it. Never return only an intro blurb or pad the email with repetition. Use a shorter complete email if evidence is limited; do not invent anecdotes, statistics, or links."
        X_POST -> "- X Post: one standalone post, 280 characters or fewer, leading with the strongest takeaway."
        THREADS -> "- Threads: numbered posts (1/, 2/, ...). Each post must be 500 characters or fewer, with a conversational progression."
        LINKEDIN -> "- LinkedIn: open with the core insight, use short scannable paragraphs, professional and credible, no hype."
    }
    val outputTemplate: String get() = "## $displayName\n\n..."
}

data class RepurposePackPreferences(
    val formats: List<RepurposeFormat> = RepurposeFormat.defaultFormats,
    val threadLength: RepurposeThreadLength = RepurposeThreadLength.MEDIUM,
    val longVideoMinutes: Int = 5,
) {
    val selectedFormats: List<RepurposeFormat> get() = formats.ifEmpty { RepurposeFormat.defaultFormats }
    val lengthInstruction: String get() = listOfNotNull(
        if (RepurposeFormat.YOUTUBE_VIDEO in selectedFormats) "YouTube Video target: $longVideoMinutes minutes. Use complete spoken sections with chapter headings." else null,
        if (RepurposeFormat.THREADS in selectedFormats) "Thread length (Threads): ${threadLength.tweetCountRange} posts." else null,
    ).joinToString("\n")
    companion object {
        val longVideoOptions = listOf(5, 8, 12)
        fun load(preferences: SharedPreferences?): RepurposePackPreferences {
            val savedFormats = RepurposeFormat.entries.filter { preferences?.getBoolean(it.preferenceKey, false) == true }
            val minutes = preferences?.getInt("repurposePackLongVideoMinutes", 5) ?: 5
            return RepurposePackPreferences(
                formats = savedFormats.ifEmpty { RepurposeFormat.defaultFormats },
                threadLength = RepurposeThreadLength.fromRawValue(preferences?.getString("repurposePackThreadLength", null)),
                longVideoMinutes = minutes.takeIf { it in longVideoOptions } ?: 5,
            )
        }
        val adaptationRules = """

            Adapt the current draft into content for the requested platforms. Use the latest edited draft or the draft selected in our conversation, not the original imported transcript when a revised draft is available.
            - Preserve the core ideas and supported facts. Treat imported creators' personal experiences as reference material, not as the user's own experiences.
            - For video targets, return ready-to-record scripts; publishing captions belong to a separate task.
            - Adapt openings, information order, pacing, detail, and endings to each requested target. Do not repeat the same script with different platform headings, and do not claim that a platform guarantees reach.
            - Expand or condense the content to the requested length only when the available material supports it. Do not invent facts, quotes, results, personal anecdotes, visual details, or links to fill space.
            - For Newsletter, write a complete substantial email, not a teaser or a brief introduction.
            - Return only the requested adapted content, with ## headings reserved for target platforms and ### headings for internal chapters or email sections. Follow explicit conversation preferences over saved defaults.
        """.trimIndent()
    }
}

/** SharedPreferences mirror of the iOS AppStorage values used by configurable Creator Skills. */
object CreatorSkillPreferences {
    @Volatile
    private var sharedPreferences: SharedPreferences? = null

    fun initialize(context: Context) {
        applicationContext = context.applicationContext
        if (sharedPreferences != null) return
        synchronized(this) {
            if (sharedPreferences == null) {
                sharedPreferences = context.applicationContext.getSharedPreferences(FILE_NAME, Context.MODE_PRIVATE)
            }
        }
    }

    fun translateTargetLanguage(): TranslateTargetLanguage =
        TranslateTargetLanguage.fromRawValue(sharedPreferences?.getString(KEY_TRANSLATE_LANGUAGE, null))

    fun saveTranslateTargetLanguage(value: TranslateTargetLanguage) {
        sharedPreferences?.edit()?.putString(KEY_TRANSLATE_LANGUAGE, value.rawValue)?.apply()
    }

    fun captionPack(): CaptionPackPreferences {
        val preferences = sharedPreferences
        return CaptionPackPreferences(
            includeTikTok = preferences?.getBoolean(KEY_CAPTION_TIKTOK, true) ?: true,
            includeYouTubeShorts = preferences?.getBoolean(KEY_CAPTION_YOUTUBE_SHORTS, true) ?: true,
            includeYouTubeLongVideo = preferences?.getBoolean(KEY_CAPTION_YOUTUBE_LONG_VIDEO, true) ?: true,
            includeInstagramReels = preferences?.getBoolean(KEY_CAPTION_INSTAGRAM_REELS, true) ?: true,
            goal = CaptionPackGoal.fromRawValue(preferences?.getString(KEY_CAPTION_GOAL, null)),
            tone = CaptionPackTone.fromCaptionRawValue(preferences?.getString(KEY_CAPTION_TONE, null)),
            outputStyle = CaptionPackOutputStyle.fromRawValue(preferences?.getString(KEY_CAPTION_OUTPUT_STYLE, null)),
        )
    }

    fun saveCaptionPack(value: CaptionPackPreferences) {
        sharedPreferences?.edit()
            ?.putBoolean(KEY_CAPTION_TIKTOK, value.includeTikTok)
            ?.putBoolean(KEY_CAPTION_YOUTUBE_SHORTS, value.includeYouTubeShorts)
            ?.putBoolean(KEY_CAPTION_YOUTUBE_LONG_VIDEO, value.includeYouTubeLongVideo)
            ?.putBoolean(KEY_CAPTION_INSTAGRAM_REELS, value.includeInstagramReels)
            ?.putString(KEY_CAPTION_GOAL, value.goal.rawValue)
            ?.putString(KEY_CAPTION_TONE, value.tone.rawValue)
            ?.putString(KEY_CAPTION_OUTPUT_STYLE, value.outputStyle.rawValue)
            ?.apply()
    }

    fun brandVoice(): BrandVoicePreferences = BrandVoicePreferences.load(sharedPreferences)

    fun saveBrandVoice(value: BrandVoicePreferences) {
        sharedPreferences?.edit()
            ?.putString("brandVoiceSamples", Json.encodeToString(value.samples.filter { it.isNotBlank() }))
            ?.apply()
    }

    fun repurposePack(): RepurposePackPreferences = RepurposePackPreferences.load(sharedPreferences)

    fun saveRepurposePack(value: RepurposePackPreferences) {
        val editor = sharedPreferences?.edit() ?: return
        for (format in RepurposeFormat.entries) {
            editor.putBoolean(format.preferenceKey, format in value.selectedFormats)
        }
        editor.putString("repurposePackThreadLength", value.threadLength.rawValue)
            .putInt("repurposePackLongVideoMinutes", value.longVideoMinutes)
            .apply()
    }

    fun localizedTitle(@StringRes resource: Int, fallback: String): String =
        runCatching { applicationContext?.getString(resource) }.getOrNull() ?: fallback

    @Volatile
    private var applicationContext: Context? = null

    private const val FILE_NAME = "creator_skill_settings"
    private const val KEY_TRANSLATE_LANGUAGE = "translateTargetLanguage"

    private const val KEY_CAPTION_TIKTOK = "captionPackPlatformTikTok"
    private const val KEY_CAPTION_YOUTUBE_SHORTS = "captionPackPlatformYouTubeShorts"
    private const val KEY_CAPTION_YOUTUBE_LONG_VIDEO = "captionPackPlatformYouTubeLongVideo"
    private const val KEY_CAPTION_INSTAGRAM_REELS = "captionPackPlatformInstagramReels"
    private const val KEY_CAPTION_GOAL = "captionPackGoal"
    private const val KEY_CAPTION_TONE = "captionPackTone"
    private const val KEY_CAPTION_OUTPUT_STYLE = "captionPackOutputStyle"
}
