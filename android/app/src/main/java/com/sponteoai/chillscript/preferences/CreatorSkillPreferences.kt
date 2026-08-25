package com.sponteoai.chillscript.preferences

import android.content.Context
import android.content.SharedPreferences
import androidx.annotation.StringRes
import com.sponteoai.chillscript.R

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
            TIKTOK -> "- TikTok: Output Caption and Hashtags. Caption must be under 2,200 characters. Hashtags must be 5 or fewer."
            INSTAGRAM_REELS -> "- Instagram Reels: Output Caption and Hashtags. Caption must be under 2,200 characters. Hashtags must be 5 or fewer."
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

                Caption:
                ...

                Hashtags:
                #creatorworkflow #contentstrategy #shortformvideo #tiktoktips #contentideas
            """.trimIndent()

            INSTAGRAM_REELS -> """
                ## Instagram Reels

                Caption:
                ...

                Hashtags:
                #contentcreator #creatorworkflow #reelstips #contentstrategy #socialmediatips
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

data class BrandVoicePreferences(
    val sample: String = "",
    val tone: String = "",
    val audience: String = "",
    val cta: String = "",
    val avoid: String = "",
) {
    val isConfigured: Boolean
        get() = listOf(sample, tone, audience, cta, avoid).any { it.isNotBlank() }

    val promptProfile: String
        get() = buildList {
            tone.trim().takeIf { it.isNotEmpty() }?.let { add("Tone / voice style:\n$it") }
            audience.trim().takeIf { it.isNotEmpty() }?.let { add("Audience:\n$it") }
            cta.trim().takeIf { it.isNotEmpty() }?.let { add("Preferred CTA:\n$it") }
            avoid.trim().takeIf { it.isNotEmpty() }?.let { add("Avoid:\n$it") }
            sample.trim().takeIf { it.isNotEmpty() }?.let { add("Example posts / writing samples:\n$it") }
        }.joinToString("\n\n")
}

enum class TimedScriptDuration(
    val rawValue: String,
    val seconds: Int,
    val wordCountRange: String,
    @StringRes val titleRes: Int,
) {
    SECONDS_30("seconds30", 30, "70-90", R.string.timed_script_duration_30),
    SECONDS_45("seconds45", 45, "105-130", R.string.timed_script_duration_45),
    SECONDS_60("seconds60", 60, "140-170", R.string.timed_script_duration_60),
    ;

    companion object {
        fun fromRawValue(value: String?): TimedScriptDuration =
            entries.firstOrNull { it.rawValue == value } ?: SECONDS_45
    }
}

data class TimedScriptPreferences(
    val duration: TimedScriptDuration = TimedScriptDuration.SECONDS_45,
)

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

enum class RepurposeFormat(
    @StringRes val titleRes: Int,
    val displayName: String,
) {
    X_POST(R.string.repurpose_pack_format_x_post, "X Post"),
    LINKEDIN(R.string.repurpose_pack_format_linkedin, "LinkedIn"),
    THREADS(R.string.repurpose_pack_format_threads, "Threads"),
    FACEBOOK_PAGE(R.string.repurpose_pack_format_facebook_page, "Facebook Page"),
    NEWSLETTER(R.string.repurpose_pack_format_newsletter, "Newsletter"),
    INSTAGRAM_CAROUSEL(R.string.repurpose_pack_format_instagram_carousel, "Instagram Carousel Outline"),
    PINTEREST_PIN(R.string.repurpose_pack_format_pinterest_pin, "Pinterest Pin"),
    YOUTUBE_COMMUNITY(R.string.repurpose_pack_format_youtube_community, "YouTube Community Post"),
    ;

    val formatRule: String
        get() = when (this) {
            X_POST -> "- X Post: one standalone post, 280 characters or fewer, leading with the strongest takeaway."
            LINKEDIN -> "- LinkedIn: open with the core insight, use short scannable paragraphs, professional and credible, no hype."
            THREADS -> "- Threads: numbered posts (1/, 2/, ...). Each post must be 500 characters or fewer, conversational tone."
            FACEBOOK_PAGE -> "- Facebook Page: clear, approachable page post for a broader audience. Make it easy to understand and share."
            NEWSLETTER -> "- Newsletter: a 2-3 sentence intro blurb that teases the piece, ending with a [link] placeholder."
            INSTAGRAM_CAROUSEL -> "- Instagram Carousel Outline: 6-8 slide outline with one short headline and one supporting line per slide."
            PINTEREST_PIN -> "- Pinterest Pin: SEO-friendly Title, Description, and Keywords. Make it searchable and evergreen."
            YOUTUBE_COMMUNITY -> "- YouTube Community Post: a short community update, question, or teaser that invites comments without sounding spammy."
        }

    val outputTemplate: String
        get() = when (this) {
            X_POST -> "## X Post\n\n..."
            LINKEDIN -> "## LinkedIn\n\n..."
            THREADS -> "## Threads\n\n1/ ...\n2/ ..."
            FACEBOOK_PAGE -> "## Facebook Page\n\n..."
            NEWSLETTER -> "## Newsletter\n\n..."
            INSTAGRAM_CAROUSEL -> "## Instagram Carousel Outline\n\nSlide 1: ...\nSlide 2: ..."
            PINTEREST_PIN -> "## Pinterest Pin\n\nTitle:\n...\n\nDescription:\n...\n\nKeywords:\n..."
            YOUTUBE_COMMUNITY -> "## YouTube Community Post\n\n..."
        }
}

data class RepurposePackPreferences(
    val includeXPost: Boolean = true,
    val includeLinkedIn: Boolean = true,
    val includeThreads: Boolean = false,
    val includeFacebookPage: Boolean = false,
    val includeNewsletter: Boolean = false,
    val includeInstagramCarousel: Boolean = true,
    val includePinterestPin: Boolean = false,
    val includeYouTubeCommunity: Boolean = false,
    val threadLength: RepurposeThreadLength = RepurposeThreadLength.MEDIUM,
    val tone: CaptionPackTone = CaptionPackTone.CREATOR_VOICE,
    val includeCTA: Boolean = true,
) {
    val selectedFormats: List<RepurposeFormat>
        get() = buildList {
            if (includeXPost) add(RepurposeFormat.X_POST)
            if (includeLinkedIn) add(RepurposeFormat.LINKEDIN)
            if (includeThreads) add(RepurposeFormat.THREADS)
            if (includeFacebookPage) add(RepurposeFormat.FACEBOOK_PAGE)
            if (includeNewsletter) add(RepurposeFormat.NEWSLETTER)
            if (includeInstagramCarousel) add(RepurposeFormat.INSTAGRAM_CAROUSEL)
            if (includePinterestPin) add(RepurposeFormat.PINTEREST_PIN)
            if (includeYouTubeCommunity) add(RepurposeFormat.YOUTUBE_COMMUNITY)
        }.ifEmpty { listOf(RepurposeFormat.X_POST, RepurposeFormat.LINKEDIN, RepurposeFormat.INSTAGRAM_CAROUSEL) }
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

    fun captionPack(): CaptionPackPreferences {
        val preferences = sharedPreferences
        return CaptionPackPreferences(
            includeTikTok = preferences?.getBoolean(KEY_CAPTION_TIKTOK, true) ?: true,
            includeYouTubeShorts = preferences?.getBoolean(KEY_CAPTION_YOUTUBE_SHORTS, true) ?: true,
            includeYouTubeLongVideo = preferences?.getBoolean(KEY_CAPTION_YOUTUBE_LONG_VIDEO, true) ?: true,
            includeInstagramReels = preferences?.getBoolean(KEY_CAPTION_INSTAGRAM_REELS, true) ?: true,
            goal = CaptionPackGoal.fromRawValue(preferences?.getString(KEY_CAPTION_GOAL, null)),
            tone = CaptionPackTone.fromRawValue(preferences?.getString(KEY_CAPTION_TONE, null)),
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

    fun brandVoice(): BrandVoicePreferences {
        val preferences = sharedPreferences
        return BrandVoicePreferences(
            sample = preferences?.getString(KEY_BRAND_SAMPLE, "").orEmpty(),
            tone = preferences?.getString(KEY_BRAND_TONE, "").orEmpty(),
            audience = preferences?.getString(KEY_BRAND_AUDIENCE, "").orEmpty(),
            cta = preferences?.getString(KEY_BRAND_CTA, "").orEmpty(),
            avoid = preferences?.getString(KEY_BRAND_AVOID, "").orEmpty(),
        )
    }

    fun saveBrandVoice(value: BrandVoicePreferences) {
        sharedPreferences?.edit()
            ?.putString(KEY_BRAND_SAMPLE, value.sample)
            ?.putString(KEY_BRAND_TONE, value.tone)
            ?.putString(KEY_BRAND_AUDIENCE, value.audience)
            ?.putString(KEY_BRAND_CTA, value.cta)
            ?.putString(KEY_BRAND_AVOID, value.avoid)
            ?.apply()
    }

    fun timedScript(): TimedScriptPreferences = TimedScriptPreferences(
        duration = TimedScriptDuration.fromRawValue(
            sharedPreferences?.getString(KEY_TIMED_SCRIPT_DURATION, null),
        ),
    )

    fun saveTimedScript(value: TimedScriptPreferences) {
        sharedPreferences?.edit()?.putString(KEY_TIMED_SCRIPT_DURATION, value.duration.rawValue)?.apply()
    }

    fun repurposePack(): RepurposePackPreferences {
        val preferences = sharedPreferences
        return RepurposePackPreferences(
            includeXPost = preferences?.getBoolean(KEY_REPURPOSE_X_POST, true) ?: true,
            includeLinkedIn = preferences?.getBoolean(KEY_REPURPOSE_LINKEDIN, true) ?: true,
            includeThreads = preferences?.getBoolean(KEY_REPURPOSE_THREADS, false) ?: false,
            includeFacebookPage = preferences?.getBoolean(KEY_REPURPOSE_FACEBOOK_PAGE, false) ?: false,
            includeNewsletter = preferences?.getBoolean(KEY_REPURPOSE_NEWSLETTER, false) ?: false,
            includeInstagramCarousel = preferences?.getBoolean(KEY_REPURPOSE_INSTAGRAM_CAROUSEL, true) ?: true,
            includePinterestPin = preferences?.getBoolean(KEY_REPURPOSE_PINTEREST_PIN, false) ?: false,
            includeYouTubeCommunity = preferences?.getBoolean(KEY_REPURPOSE_YOUTUBE_COMMUNITY, false) ?: false,
            threadLength = RepurposeThreadLength.fromRawValue(preferences?.getString(KEY_REPURPOSE_THREAD_LENGTH, null)),
            tone = CaptionPackTone.fromRawValue(
                preferences?.getString(KEY_REPURPOSE_TONE, CaptionPackTone.CREATOR_VOICE.rawValue)
                    ?: CaptionPackTone.CREATOR_VOICE.rawValue,
            ),
            includeCTA = preferences?.getBoolean(KEY_REPURPOSE_INCLUDE_CTA, true) ?: true,
        )
    }

    fun saveRepurposePack(value: RepurposePackPreferences) {
        sharedPreferences?.edit()
            ?.putBoolean(KEY_REPURPOSE_X_POST, value.includeXPost)
            ?.putBoolean(KEY_REPURPOSE_LINKEDIN, value.includeLinkedIn)
            ?.putBoolean(KEY_REPURPOSE_THREADS, value.includeThreads)
            ?.putBoolean(KEY_REPURPOSE_FACEBOOK_PAGE, value.includeFacebookPage)
            ?.putBoolean(KEY_REPURPOSE_NEWSLETTER, value.includeNewsletter)
            ?.putBoolean(KEY_REPURPOSE_INSTAGRAM_CAROUSEL, value.includeInstagramCarousel)
            ?.putBoolean(KEY_REPURPOSE_PINTEREST_PIN, value.includePinterestPin)
            ?.putBoolean(KEY_REPURPOSE_YOUTUBE_COMMUNITY, value.includeYouTubeCommunity)
            ?.putString(KEY_REPURPOSE_THREAD_LENGTH, value.threadLength.rawValue)
            ?.putString(KEY_REPURPOSE_TONE, value.tone.rawValue)
            ?.putBoolean(KEY_REPURPOSE_INCLUDE_CTA, value.includeCTA)
            ?.apply()
    }

    fun localizedTitle(@StringRes resource: Int, fallback: String): String =
        runCatching { applicationContext?.getString(resource) }.getOrNull() ?: fallback

    @Volatile
    private var applicationContext: Context? = null

    private const val FILE_NAME = "creator_skill_settings"

    private const val KEY_CAPTION_TIKTOK = "captionPackPlatformTikTok"
    private const val KEY_CAPTION_YOUTUBE_SHORTS = "captionPackPlatformYouTubeShorts"
    private const val KEY_CAPTION_YOUTUBE_LONG_VIDEO = "captionPackPlatformYouTubeLongVideo"
    private const val KEY_CAPTION_INSTAGRAM_REELS = "captionPackPlatformInstagramReels"
    private const val KEY_CAPTION_GOAL = "captionPackGoal"
    private const val KEY_CAPTION_TONE = "captionPackTone"
    private const val KEY_CAPTION_OUTPUT_STYLE = "captionPackOutputStyle"

    private const val KEY_BRAND_SAMPLE = "brandVoiceSample"
    private const val KEY_BRAND_TONE = "brandVoiceTone"
    private const val KEY_BRAND_AUDIENCE = "brandVoiceAudience"
    private const val KEY_BRAND_CTA = "brandVoiceCTA"
    private const val KEY_BRAND_AVOID = "brandVoiceAvoid"

    private const val KEY_TIMED_SCRIPT_DURATION = "timedScriptDuration"

    private const val KEY_REPURPOSE_X_POST = "repurposePackFormatXPost"
    private const val KEY_REPURPOSE_LINKEDIN = "repurposePackFormatLinkedIn"
    private const val KEY_REPURPOSE_THREADS = "repurposePackFormatThreads"
    private const val KEY_REPURPOSE_FACEBOOK_PAGE = "repurposePackFormatFacebookPage"
    private const val KEY_REPURPOSE_NEWSLETTER = "repurposePackFormatNewsletter"
    private const val KEY_REPURPOSE_INSTAGRAM_CAROUSEL = "repurposePackFormatInstagramCarousel"
    private const val KEY_REPURPOSE_PINTEREST_PIN = "repurposePackFormatPinterestPin"
    private const val KEY_REPURPOSE_YOUTUBE_COMMUNITY = "repurposePackFormatYouTubeCommunity"
    private const val KEY_REPURPOSE_THREAD_LENGTH = "repurposePackThreadLength"
    private const val KEY_REPURPOSE_TONE = "repurposePackTone"
    private const val KEY_REPURPOSE_INCLUDE_CTA = "repurposePackIncludeCTA"
}
