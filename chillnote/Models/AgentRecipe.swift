import Foundation
import SwiftUI

struct AgentRecipe: Identifiable, Hashable, Codable {
    let id: String
    let icon: String // Emoji for display
    let systemIcon: String // SF Symbol for buttons
    let name: String
    let description: String
    let prompt: String
    let category: AgentRecipeCategory
    let isCustom: Bool
    
    var isMedia: Bool {
        return category == .publish
    }

    var localizedName: String {
        isCustom ? name : L10n.text("agent_recipe.\(id).name")
    }

    var localizedDescription: String {
        isCustom ? description : L10n.text("agent_recipe.\(id).description")
    }

    var localizedPrompt: String {
        isCustom ? prompt : NSLocalizedString(prompt, comment: "")
    }

    init(
        id: String,
        icon: String,
        systemIcon: String,
        name: String,
        description: String,
        prompt: String,
        category: AgentRecipeCategory,
        isCustom: Bool = false
    ) {
        self.id = id
        self.icon = icon
        self.systemIcon = systemIcon
        self.name = name
        self.description = description
        self.prompt = prompt
        self.category = category
        self.isCustom = isCustom
    }

    enum CodingKeys: String, CodingKey {
        case id
        case icon
        case systemIcon
        case name
        case description
        case prompt
        case category
        case isCustom
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        icon = try container.decode(String.self, forKey: .icon)
        systemIcon = try container.decode(String.self, forKey: .systemIcon)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        prompt = try container.decode(String.self, forKey: .prompt)
        category = try container.decode(AgentRecipeCategory.self, forKey: .category)
        isCustom = (try? container.decode(Bool.self, forKey: .isCustom)) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(icon, forKey: .icon)
        try container.encode(systemIcon, forKey: .systemIcon)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(prompt, forKey: .prompt)
        try container.encode(category, forKey: .category)
        try container.encode(isCustom, forKey: .isCustom)
    }
}

enum CaptionPackOutputStyle: String, CaseIterable, Identifiable {
    case concise
    case balanced
    case detailed

    var id: String { rawValue }

    var localizedTitle: String {
        L10n.text("caption_pack.output_style.\(rawValue)")
    }
}

enum CaptionPackGoal: String, CaseIterable, Identifiable {
    case startDiscussion
    case getSaves
    case getShares
    case driveFollows

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .startDiscussion:
            return L10n.text("caption_pack.goal.start_discussion")
        case .getSaves:
            return L10n.text("caption_pack.goal.get_saves")
        case .getShares:
            return L10n.text("caption_pack.goal.get_shares")
        case .driveFollows:
            return L10n.text("caption_pack.goal.drive_follows")
        }
    }
}

enum CaptionPackTone: String, CaseIterable, Identifiable {
    case casualUseful
    case educational
    case bold
    case storyDriven
    case creatorVoice

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .casualUseful:
            return L10n.text("caption_pack.tone.casual_useful")
        case .educational:
            return L10n.text("caption_pack.tone.educational")
        case .bold:
            return L10n.text("caption_pack.tone.bold")
        case .storyDriven:
            return L10n.text("caption_pack.tone.story_driven")
        case .creatorVoice:
            return L10n.text("caption_pack.tone.creator_voice")
        }
    }
}

enum CaptionPackPlatform: CaseIterable, Equatable {
    case tiktok
    case instagramReels
    case youtubeShorts
    case youtubeLongVideo

    var displayName: String {
        switch self {
        case .tiktok: return "TikTok"
        case .instagramReels: return "Instagram Reels"
        case .youtubeShorts: return "YouTube Shorts"
        case .youtubeLongVideo: return "YouTube Long Video"
        }
    }

    var platformRule: String {
        switch self {
        case .tiktok:
            return "- TikTok: Output Caption and Hashtags. Caption must be under 2,200 characters. Hashtags must be 5 or fewer."
        case .instagramReels:
            return "- Instagram Reels: Output Caption and Hashtags. Caption must be under 2,200 characters. Hashtags must be 5 or fewer."
        case .youtubeShorts:
            return "- YouTube Shorts: Output Title, Description, and Hashtags. Title must be under 100 characters. Description should be compact and mobile-friendly. Hashtags must be 3 or fewer."
        case .youtubeLongVideo:
            return "- YouTube Long Video: Output SEO Title, Description, Tags, and Pinned Comment. Make the description fuller than Shorts copy, with a clear summary, search-friendly keywords, and a natural CTA. Tags must be comma-separated."
        }
    }

    func styleInstruction(for style: CaptionPackOutputStyle) -> String {
        switch (self, style) {
        case (.tiktok, .concise):
            return "- TikTok caption target: 120-220 characters."
        case (.tiktok, .balanced):
            return "- TikTok caption target: 300-600 characters."
        case (.tiktok, .detailed):
            return "- TikTok caption target: 700-1,200 characters."
        case (.instagramReels, .concise):
            return "- Instagram Reels caption target: 100-180 characters."
        case (.instagramReels, .balanced):
            return "- Instagram Reels caption target: 250-500 characters."
        case (.instagramReels, .detailed):
            return "- Instagram Reels caption target: 600-1,000 characters."
        case (.youtubeShorts, .concise):
            return """
            - YouTube Shorts title target: 35-50 characters.
            - YouTube Shorts description target: 80-150 characters.
            """
        case (.youtubeShorts, .balanced):
            return """
            - YouTube Shorts title target: 50-70 characters.
            - YouTube Shorts description target: 150-300 characters.
            """
        case (.youtubeShorts, .detailed):
            return """
            - YouTube Shorts title target: 70-90 characters.
            - YouTube Shorts description target: 300-600 characters.
            """
        case (.youtubeLongVideo, .concise):
            return """
            - YouTube Long Video SEO title target: 55-75 characters.
            - YouTube Long Video description target: 500-900 characters.
            """
        case (.youtubeLongVideo, .balanced):
            return """
            - YouTube Long Video SEO title target: 60-85 characters.
            - YouTube Long Video description target: 900-1,500 characters.
            """
        case (.youtubeLongVideo, .detailed):
            return """
            - YouTube Long Video SEO title target: 70-95 characters.
            - YouTube Long Video description target: 1,500-2,500 characters.
            """
        }
    }

    var outputTemplate: String {
        switch self {
        case .tiktok:
            return """
            ## TikTok

            Caption:
            ...

            Hashtags:
            #creatorworkflow #contentstrategy #shortformvideo #tiktoktips #contentideas
            """
        case .instagramReels:
            return """
            ## Instagram Reels

            Caption:
            ...

            Hashtags:
            #contentcreator #creatorworkflow #reelstips #contentstrategy #socialmediatips
            """
        case .youtubeShorts:
            return """
            ## YouTube Shorts

            Title:
            ...

            Description:
            ...

            Hashtags:
            #Shorts #ContentStrategy #CreatorTips
            """
        case .youtubeLongVideo:
            return """
            ## YouTube Long Video

            SEO Title:
            ...

            Description:
            ...

            Tags:
            creator workflow, content strategy, AI tools

            Pinned Comment:
            ...
            """
        }
    }
}

struct CaptionPackPreferences {
    static let tiktokKey = "captionPackPlatformTikTok"
    static let youtubeShortsKey = "captionPackPlatformYouTubeShorts"
    static let youtubeLongVideoKey = "captionPackPlatformYouTubeLongVideo"
    static let instagramReelsKey = "captionPackPlatformInstagramReels"
    static let goalKey = "captionPackGoal"
    static let toneKey = "captionPackTone"
    static let outputStyleKey = "captionPackOutputStyle"

    var includeTikTok: Bool
    var includeYouTubeShorts: Bool
    var includeYouTubeLongVideo: Bool
    var includeInstagramReels: Bool
    var goal: CaptionPackGoal
    var tone: CaptionPackTone
    var outputStyle: CaptionPackOutputStyle

    static var current: CaptionPackPreferences {
        let defaults = UserDefaults.standard
        return CaptionPackPreferences(
            includeTikTok: defaults.object(forKey: tiktokKey) as? Bool ?? true,
            includeYouTubeShorts: defaults.object(forKey: youtubeShortsKey) as? Bool ?? true,
            includeYouTubeLongVideo: defaults.object(forKey: youtubeLongVideoKey) as? Bool ?? true,
            includeInstagramReels: defaults.object(forKey: instagramReelsKey) as? Bool ?? true,
            goal: CaptionPackGoal(rawValue: defaults.string(forKey: goalKey) ?? "") ?? .startDiscussion,
            tone: CaptionPackTone(rawValue: defaults.string(forKey: toneKey) ?? "") ?? .casualUseful,
            outputStyle: CaptionPackOutputStyle(rawValue: defaults.string(forKey: outputStyleKey) ?? "") ?? .balanced
        )
    }

    var selectedPlatforms: [CaptionPackPlatform] {
        var platforms: [CaptionPackPlatform] = []
        if includeTikTok { platforms.append(.tiktok) }
        if includeInstagramReels { platforms.append(.instagramReels) }
        if includeYouTubeShorts { platforms.append(.youtubeShorts) }
        if includeYouTubeLongVideo { platforms.append(.youtubeLongVideo) }
        return platforms.isEmpty ? [.tiktok, .instagramReels, .youtubeShorts, .youtubeLongVideo] : platforms
    }

    var selectedPlatformNames: [String] {
        selectedPlatforms.map(\.displayName)
    }

    var selectedPlatformRules: String {
        selectedPlatforms.map(\.platformRule).joined(separator: "\n")
    }

    var selectedStyleInstruction: String {
        selectedPlatforms
            .map { $0.styleInstruction(for: outputStyle) }
            .joined(separator: "\n")
    }

    var selectedOutputTemplate: String {
        selectedPlatforms.map(\.outputTemplate).joined(separator: "\n\n")
    }

    var platformSpecificCTAInstruction: String {
        selectedPlatforms.contains(.tiktok) || selectedPlatforms.contains(.instagramReels)
            ? "- For TikTok and Instagram Reels, naturally fold any question or soft call to action into the caption when it fits. Do not create a separate CTA section."
            : ""
    }
}

struct BrandVoicePreferences {
    static let sampleKey = "brandVoiceSample"
    static let toneKey = "brandVoiceTone"
    static let audienceKey = "brandVoiceAudience"
    static let ctaKey = "brandVoiceCTA"
    static let avoidKey = "brandVoiceAvoid"

    var sample: String
    var tone: String
    var audience: String
    var cta: String
    var avoid: String

    static var current: BrandVoicePreferences {
        let defaults = UserDefaults.standard
        return BrandVoicePreferences(
            sample: defaults.string(forKey: sampleKey) ?? "",
            tone: defaults.string(forKey: toneKey) ?? "",
            audience: defaults.string(forKey: audienceKey) ?? "",
            cta: defaults.string(forKey: ctaKey) ?? "",
            avoid: defaults.string(forKey: avoidKey) ?? ""
        )
    }

    var isConfigured: Bool {
        ![sample, tone, audience, cta, avoid]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .allSatisfy(\.isEmpty)
    }

    var promptProfile: String {
        var sections: [String] = []

        let trimmedTone = tone.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTone.isEmpty {
            sections.append("Tone / voice style:\n\(trimmedTone)")
        }

        let trimmedAudience = audience.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAudience.isEmpty {
            sections.append("Audience:\n\(trimmedAudience)")
        }

        let trimmedCTA = cta.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCTA.isEmpty {
            sections.append("Preferred CTA:\n\(trimmedCTA)")
        }

        let trimmedAvoid = avoid.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAvoid.isEmpty {
            sections.append("Avoid:\n\(trimmedAvoid)")
        }

        let trimmedSample = sample.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSample.isEmpty {
            sections.append("Example posts / writing samples:\n\(trimmedSample)")
        }

        return sections.joined(separator: "\n\n")
    }
}

enum TimedScriptDuration: String, CaseIterable, Identifiable {
    case seconds30
    case seconds45
    case seconds60

    var id: String { rawValue }

    var seconds: Int {
        switch self {
        case .seconds30: return 30
        case .seconds45: return 45
        case .seconds60: return 60
        }
    }

    var wordCountRange: String {
        switch self {
        case .seconds30: return "70-90"
        case .seconds45: return "105-130"
        case .seconds60: return "140-170"
        }
    }

    var localizedTitle: String {
        switch self {
        case .seconds30: return L10n.text("timed_script.duration.30")
        case .seconds45: return L10n.text("timed_script.duration.45")
        case .seconds60: return L10n.text("timed_script.duration.60")
        }
    }
}

struct TimedScriptPreferences {
    static let durationKey = "timedScriptDuration"

    var duration: TimedScriptDuration

    static var current: TimedScriptPreferences {
        TimedScriptPreferences(
            duration: TimedScriptDuration(rawValue: UserDefaults.standard.string(forKey: durationKey) ?? "") ?? .seconds45
        )
    }
}

enum RepurposeThreadLength: String, CaseIterable, Identifiable {
    case short
    case medium
    case long

    var id: String { rawValue }

    var localizedTitle: String {
        L10n.text("repurpose_pack.thread_length.\(rawValue)")
    }

    var tweetCountRange: String {
        switch self {
        case .short: return "3-5"
        case .medium: return "6-8"
        case .long: return "9-12"
        }
    }
}

enum RepurposeFormat: CaseIterable, Equatable {
    case xPost
    case linkedin
    case threads
    case facebookPage
    case newsletter
    case instagramCarousel
    case pinterestPin
    case youtubeCommunity

    var displayName: String {
        switch self {
        case .xPost: return "X Post"
        case .linkedin: return "LinkedIn"
        case .threads: return "Threads"
        case .facebookPage: return "Facebook Page"
        case .newsletter: return "Newsletter"
        case .instagramCarousel: return "Instagram Carousel Outline"
        case .pinterestPin: return "Pinterest Pin"
        case .youtubeCommunity: return "YouTube Community Post"
        }
    }

    var formatRule: String {
        switch self {
        case .xPost:
            return "- X Post: one standalone post, 280 characters or fewer, leading with the strongest takeaway."
        case .linkedin:
            return "- LinkedIn: open with the core insight, use short scannable paragraphs, professional and credible, no hype."
        case .threads:
            return "- Threads: numbered posts (1/, 2/, ...). Each post must be 500 characters or fewer, conversational tone."
        case .facebookPage:
            return "- Facebook Page: clear, approachable page post for a broader audience. Make it easy to understand and share."
        case .newsletter:
            return "- Newsletter: a 2-3 sentence intro blurb that teases the piece, ending with a [link] placeholder."
        case .instagramCarousel:
            return "- Instagram Carousel Outline: 6-8 slide outline with one short headline and one supporting line per slide."
        case .pinterestPin:
            return "- Pinterest Pin: SEO-friendly Title, Description, and Keywords. Make it searchable and evergreen."
        case .youtubeCommunity:
            return "- YouTube Community Post: a short community update, question, or teaser that invites comments without sounding spammy."
        }
    }

    var outputTemplate: String {
        switch self {
        case .xPost:
            return """
            ## X Post

            ...
            """
        case .linkedin:
            return """
            ## LinkedIn

            ...
            """
        case .threads:
            return """
            ## Threads

            1/ ...
            2/ ...
            """
        case .facebookPage:
            return """
            ## Facebook Page

            ...
            """
        case .newsletter:
            return """
            ## Newsletter

            ...
            """
        case .instagramCarousel:
            return """
            ## Instagram Carousel Outline

            Slide 1: ...
            Slide 2: ...
            """
        case .pinterestPin:
            return """
            ## Pinterest Pin

            Title:
            ...

            Description:
            ...

            Keywords:
            ...
            """
        case .youtubeCommunity:
            return """
            ## YouTube Community Post

            ...
            """
        }
    }
}

struct RepurposePackPreferences {
    static let xPostKey = "repurposePackFormatXPost"
    static let linkedinKey = "repurposePackFormatLinkedIn"
    static let threadsKey = "repurposePackFormatThreads"
    static let facebookPageKey = "repurposePackFormatFacebookPage"
    static let newsletterKey = "repurposePackFormatNewsletter"
    static let instagramCarouselKey = "repurposePackFormatInstagramCarousel"
    static let pinterestPinKey = "repurposePackFormatPinterestPin"
    static let youtubeCommunityKey = "repurposePackFormatYouTubeCommunity"
    static let threadLengthKey = "repurposePackThreadLength"
    static let toneKey = "repurposePackTone"
    static let ctaKey = "repurposePackIncludeCTA"

    var includeXPost: Bool
    var includeLinkedIn: Bool
    var includeThreads: Bool
    var includeFacebookPage: Bool
    var includeNewsletter: Bool
    var includeInstagramCarousel: Bool
    var includePinterestPin: Bool
    var includeYouTubeCommunity: Bool
    var threadLength: RepurposeThreadLength
    var tone: CaptionPackTone
    var includeCTA: Bool

    static var current: RepurposePackPreferences {
        let defaults = UserDefaults.standard
        return RepurposePackPreferences(
            includeXPost: defaults.object(forKey: xPostKey) as? Bool ?? true,
            includeLinkedIn: defaults.object(forKey: linkedinKey) as? Bool ?? true,
            includeThreads: defaults.object(forKey: threadsKey) as? Bool ?? false,
            includeFacebookPage: defaults.object(forKey: facebookPageKey) as? Bool ?? false,
            includeNewsletter: defaults.object(forKey: newsletterKey) as? Bool ?? false,
            includeInstagramCarousel: defaults.object(forKey: instagramCarouselKey) as? Bool ?? true,
            includePinterestPin: defaults.object(forKey: pinterestPinKey) as? Bool ?? false,
            includeYouTubeCommunity: defaults.object(forKey: youtubeCommunityKey) as? Bool ?? false,
            threadLength: RepurposeThreadLength(rawValue: defaults.string(forKey: threadLengthKey) ?? "") ?? .medium,
            tone: CaptionPackTone(rawValue: defaults.string(forKey: toneKey) ?? "") ?? .creatorVoice,
            includeCTA: defaults.object(forKey: ctaKey) as? Bool ?? true
        )
    }

    var selectedFormats: [RepurposeFormat] {
        var formats: [RepurposeFormat] = []
        if includeXPost { formats.append(.xPost) }
        if includeLinkedIn { formats.append(.linkedin) }
        if includeThreads { formats.append(.threads) }
        if includeFacebookPage { formats.append(.facebookPage) }
        if includeNewsletter { formats.append(.newsletter) }
        if includeInstagramCarousel { formats.append(.instagramCarousel) }
        if includePinterestPin { formats.append(.pinterestPin) }
        if includeYouTubeCommunity { formats.append(.youtubeCommunity) }
        return formats.isEmpty ? [.xPost, .linkedin, .instagramCarousel] : formats
    }

    var selectedFormatNames: [String] {
        selectedFormats.map(\.displayName)
    }

    var selectedFormatRules: String {
        selectedFormats.map(\.formatRule).joined(separator: "\n")
    }

    var selectedOutputTemplate: String {
        selectedFormats.map(\.outputTemplate).joined(separator: "\n\n")
    }

    var threadLengthInstruction: String {
        selectedFormats.contains(.threads)
            ? "Thread length (Threads): \(threadLength.tweetCountRange) posts."
            : ""
    }
}

enum AgentRecipeCategory: String, CaseIterable, Identifiable, Codable {
    case think = "Think"
    case shape = "Shape"
    case publish = "Publish"
    
    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .think: return L10n.text("agent_recipe.category.think")
        case .shape: return L10n.text("agent_recipe.category.shape")
        case .publish: return L10n.text("agent_recipe.category.publish")
        }
    }
    
    var icon: String {
        switch self {
        case .think: return "brain.head.profile"
        case .shape: return "wand.and.stars"
        case .publish: return "megaphone"
        }
    }
}

extension AgentRecipe {
    static let allRecipes: [AgentRecipe] = [
        // MARK: - Think
        AgentRecipe(
            id: "why_viral",
            icon: "📈",
            systemIcon: "chart.line.uptrend.xyaxis",
            name: "Why Viral",
            description: "agent_recipe.why_viral.description",
            prompt: """
            You are analyzing why a piece of content might spread based on a user’s existing note (not a chat message). Explain the likely viral mechanics without pretending you have real platform metrics.

            - Keep the output in the same language as the note.
            - Identify the core promise, emotional trigger, audience, tension, novelty, and shareability.
            - Separate what is strong from what is weak or missing.
            - Give 3 concrete ways to make the idea more shareable while staying truthful.
            - Avoid vague advice like "make it more engaging"; be specific.

            Output as:
            1. Viral thesis
            2. Why it could spread
            3. What holds it back
            4. How to strengthen it
            """,
            category: .think
        ),
        AgentRecipe(
            id: "summarize",
            icon: "📝",
            systemIcon: "doc.text",
            name: "Summarize",
            description: "agent_recipe.summarize.description",
            prompt: """
            You are summarizing a user’s existing note (not a chat message). Keep the note’s original intent and tone, and summarize only what’s actually in the note.

            - Write in the same language as the note.
            - Keep key facts, decisions, and action items.
            - If the note is short, give a one-sentence summary or a tightened rewrite.
            - If the note is long or messy, use bullets to make it easier to scan.
            - If something is unclear or conflicting, flag it briefly instead of guessing.
            """,
            category: .think
        ),
        AgentRecipe(
            id: "translate",
            icon: "🌍",
            systemIcon: "globe",
            name: "Translate",
            description: "agent_recipe.translate.description",
            prompt: "(Built-in Logic) Uses a dynamic translation engine. The target language is selected at runtime.",
            category: .shape
        ),
        AgentRecipe(
            id: "humanizer",
            icon: "✍️",
            systemIcon: "person.text.rectangle",
            name: "Humanizer",
            description: "agent_recipe.humanizer.description",
            prompt: """
            You are editing a user’s existing note (not a chat message) to make it sound more natural, human-written, and specific.

            Work privately in two passes:
            1. Scan the note for the 29 AI-writing patterns below and rewrite the affected parts.
            2. Ask yourself what still sounds obviously AI-generated, then revise once more.

            - Keep the output in the same language as the note.
            - Preserve the note’s core meaning, facts, structure, and intended audience.
            - Replace stiff, padded, promotional, or over-polished phrasing with simpler, more concrete wording.
            - Vary sentence rhythm where it helps, but do not add fake personality, fake citations, fake anecdotes, or unsupported claims.
            - Keep useful first-person voice, uncertainty, humor, and rough edges when they fit the original note.
            - Preserve formatting (headings, lists, line breaks).
            - If the note is already natural, make only light edits.

            Check and remove these 29 AI-writing patterns:
            1. Inflated significance, legacy, or broader-trend claims: "pivotal moment", "testament", "underscores its importance", "reflects broader", "sets the stage", "evolving landscape".
            2. Notability name-dropping: lists of media outlets, experts, or social proof without a concrete point.
            3. Superficial "-ing" analysis: dangling phrases like "highlighting", "reflecting", "showcasing", "contributing to", "ensuring", "fostering".
            4. Promotional language: "boasts", "vibrant", "rich", "profound", "renowned", "breathtaking", "must-visit", "stunning", "nestled", "in the heart of".
            5. Vague attribution: "experts argue", "observers note", "industry reports suggest", "some critics say" unless the source is specific in the note.
            6. Formulaic challenges/future sections: "Despite these challenges...", "continues to thrive", "future outlook", "challenges and legacy".
            7. Overused AI vocabulary: actually, additionally, align with, crucial, delve, enduring, enhance, garner, highlight, interplay, intricate, key, landscape, pivotal, showcase, tapestry, testament, underscore, valuable, vibrant.
            8. Copula avoidance: replace "serves as", "stands as", "functions as", "represents", "features", "boasts", "offers" with simpler "is", "has", or a direct verb when clearer.
            9. Negative parallelisms and tailing negations: "not only... but...", "not just X, it is Y", and clipped endings like ", no guessing" or ", no wasted motion".
            10. Forced rule of three: lists or adjective triples that exist only to sound complete.
            11. Synonym cycling: using many labels for the same thing when repeating the clearest term would be better.
            12. False ranges: "from X to Y" pairs that are not a real scale or useful contrast.
            13. Passive voice and subjectless fragments: clarify the actor when it improves the sentence, especially lines like "No configuration needed" or "The results are preserved automatically."
            14. Em dash overuse: replace unnecessary em dashes with commas, periods, parentheses, or cleaner sentence breaks.
            15. Boldface overuse: remove mechanical bolding unless it genuinely helps the note.
            16. Inline-header vertical lists: avoid repetitive bullets like "**Performance:** Performance improved"; convert to natural prose or cleaner bullets.
            17. Title Case headings: use natural sentence-style headings unless the original format requires title case.
            18. Decorative emojis: remove emoji decoration unless it is clearly part of the user’s voice or original meaning.
            19. Curly quotation marks: prefer straight quotes unless the note’s language or format clearly expects typographic quotes.
            20. Chatbot artifacts: remove "Of course", "Certainly", "Great question", "I hope this helps", "let me know", and "Would you like me to..." when pasted into content.
            21. Knowledge-cutoff disclaimers: remove "as of my last update", "based on available information", "details are limited" unless the uncertainty is genuinely part of the note.
            22. Sycophantic tone: remove excessive agreement or flattery such as "You're absolutely right" and "excellent point."
            23. Filler phrases: shorten "in order to" to "to", "due to the fact that" to "because", "at this point in time" to "now", and similar padding.
            24. Excessive hedging: reduce stacked qualifiers like "could potentially possibly be argued" to a single honest qualifier.
            25. Generic positive conclusions: remove vague endings like "the future looks bright", "exciting times lie ahead", and "journey toward excellence."
            26. Hyphenated word-pair overuse: remove unnecessary hyphens from common word pairs when grammar allows it, while keeping technical or required compounds.
            27. Persuasive authority tropes: simplify "the real question is", "at its core", "fundamentally", "the heart of the matter", and similar ceremony.
            28. Signposting announcements: remove "let's dive in", "let's explore", "let's break this down", "here's what you need to know", and "without further ado."
            29. Fragmented headers: remove one-line warmups after headings when they only restate the heading.

            Output only the humanized text.
            """,
            category: .shape
        ),
        AgentRecipe(
            id: "rewrite",
            icon: "",
            systemIcon: "pencil.and.scribble",
            name: "Rewrite",
            description: "agent_recipe.rewrite.description",
            prompt: """
            You are rewriting a user’s existing note (not a chat message) into an original, natural version they can reuse.

            The note may include a pasted transcript, copied reference, rough draft, or creator inspiration. Your job is to preserve the useful idea while changing the expression enough that it does not feel copied.

            - Keep the output in the same language as the note.
            - Preserve the core meaning, facts, intent, and useful structure.
            - Do not add unsupported facts, stats, quotes, personal experiences, or claims.
            - Rewrite distinctive wording, sentence structure, transitions, and examples instead of lightly paraphrasing.
            - Make the result clear, natural, and ready to edit or publish.
            - If the note is a messy transcript, remove filler and repetition while keeping the speaker’s point.
            - Preserve formatting when it helps readability.

            Output only the rewritten text.
            """,
            category: .shape
        ),
        AgentRecipe(
            id: "style_match",
            icon: "🎙️",
            systemIcon: "waveform",
            name: "Brand Voice",
            description: "agent_recipe.style_match.description",
            prompt: "(Built-in Logic) Rewrites the note in the creator's saved brand voice.",
            category: .shape
        ),
        // MARK: - Shape
        AgentRecipe(
            id: "hook_generator",
            icon: "",
            systemIcon: "link",
            name: "Hook",
            description: "agent_recipe.hook_generator.description",
            prompt: """
            You are an expert short-form copywriter looking at a user’s raw note (not a chat message). Generate a mixed Hook Pack with 8 distinct opening lines based on the content.

            - Keep the output in the same language as the note.
            - Make every hook usable as the first line of a TikTok, Reel, Short, X post, or creator caption.
            - Give a variety of hook types: pain point, contrarian, curiosity gap, how-to, mistake, story, result-first, and direct statement.
            - Label each hook by type so the user can quickly compare options.
            - Do not use clickbait, fake urgency, hype, or unsupported claims.
            - Do not copy distinctive wording from pasted reference text; use the note for the idea and angle.
            - Keep each hook concise, specific, and easy to say out loud.

            Output only the Hook Pack.
            """,
            category: .shape
        ),
        AgentRecipe(
            id: "caption_pack",
            icon: "",
            systemIcon: "megaphone",
            name: "Caption",
            description: "agent_recipe.caption_pack.description",
            prompt: "(Built-in Logic) Generates platform-ready captions from creator inspiration notes.",
            category: .publish
        ),
        AgentRecipe(
            id: "timed_script",
            icon: "⏱️",
            systemIcon: "timer",
            name: "Timed Script",
            description: "agent_recipe.timed_script.description",
            prompt: "(Built-in Logic) Generates a 30, 45, or 60 second short video script.",
            category: .publish
        ),
        AgentRecipe(
            id: "repurpose_pack",
            icon: "",
            systemIcon: "arrow.triangle.2.circlepath",
            name: "Repurpose",
            description: "agent_recipe.repurpose_pack.description",
            prompt: "(Built-in Logic) Atomizes one long-form note into native posts for multiple platforms.",
            category: .publish
        ),
    ]
}

// MARK: - Execution Logic
import SwiftData

extension AgentRecipe {
    /// Generate recipe output without deciding where the result should be saved.
    func generateResult(from content: String, userInstruction: String? = nil) async throws -> String {
        let prompt: String
        let systemInstruction: String
        let languageRule = LanguageDetection.languagePreservationRule(for: content)

        switch id {
        case "translate":
            let targetLanguage = (userInstruction?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? userInstruction!
                : "English"
            prompt = """
            Translate the following notes into \(targetLanguage).

            Notes:
            \(content)
            """

            systemInstruction = """
            You are a professional translator.
            Rules:
            - Translate into \(targetLanguage).
            - Preserve meaning, tone, and formatting (including markdown).
            - Keep proper nouns, product names, URLs, code, and hashtags intact unless a standard translation exists.
            - Do not localize units, dates, or numbers unless explicitly requested.
            - Return only the translated content.
            """

        case "timed_script":
            let preferences = TimedScriptPreferences.current
            prompt = """
            Create a \(preferences.duration.seconds)-second short video script from these notes.

            Target length: \(preferences.duration.seconds) seconds.
            Target spoken word count: \(preferences.duration.wordCountRange) words.

            Notes:
            \(content)
            """

            systemInstruction = """
            You write short-form video scripts for TikTok, Instagram Reels, and YouTube Shorts. The input is an existing note, transcript, rough idea, or creator inspiration, not a chat message.

            Core rules:
            \(languageRule)
            - Produce a script that can be spoken in about \(preferences.duration.seconds) seconds.
            - Aim for \(preferences.duration.wordCountRange) spoken words. If the script is over the range, rewrite it shorter before returning.
            - Use the notes to understand the idea, audience, angle, and useful details, but do not copy distinctive wording from third-party reference text.
            - Do not invent facts, stats, quotes, personal experiences, product promises, or results that are not supported by the notes.
            - Make it recordable as a spoken script with short, natural sentences.
            - Include a strong opening line, a clear middle, a payoff, and a light CTA only when it fits.
            - Return only the script. Do not include timestamps, labels, notes, word count, or explanations.
            """

        case "caption_pack":
            let preferences = CaptionPackPreferences.current
            let platforms = preferences.selectedPlatformNames.joined(separator: ", ")
            let styleInstruction = preferences.selectedStyleInstruction
            let platformRules = preferences.selectedPlatformRules
            let platformCTAInstruction = preferences.platformSpecificCTAInstruction
            let outputTemplate = preferences.selectedOutputTemplate
            prompt = """
            Create a Caption Pack for these selected platforms: \(platforms).

            User goal: \(preferences.goal.localizedTitle)
            Tone: \(preferences.tone.localizedTitle)
            Output style: \(preferences.outputStyle.localizedTitle)

            Notes:
            \(content)
            """

            systemInstruction = """
            You create original platform-ready publishing copy for content creators.

            The notes may contain third-party creator inspiration, including descriptions, transcripts, hooks, or author metadata. Treat the notes as a private inspiration library, not source copy to rewrite.

            Core rules:
            \(languageRule)
            - Use the notes only to understand the topic, audience, emotional angle, content pattern, and reusable insight.
            - Do not copy, closely paraphrase, or preserve distinctive wording from the notes.
            - Do not mention the original author unless the notes explicitly ask for attribution.
            - Do not invent claims, stats, personal experiences, product promises, discounts, or results that are not supported.
            - If the notes do not contain enough substance, write safe, editable platform copy based on the broad idea and avoid specific unsupported claims.
            - Return only the Caption Pack. Do not explain your reasoning.

            Length and style:
            \(styleInstruction)
            - Character counts must include the generated field text, not the label.
            - If a draft exceeds any platform limit, rewrite it shorter before returning.

            Platform rules:
            \(platformRules)
            \(platformCTAInstruction)

            Output format:
            Use only the selected platforms and keep this exact section style:

            \(outputTemplate)
            """

        case "style_match":
            let preferences = BrandVoicePreferences.current
            let profile = preferences.promptProfile
            if !preferences.isConfigured {
                prompt = """
                Rewrite this note in a natural, consistent writing voice. Preserve its meaning, facts, and structure.

                Note:
                \(content)
                """

                systemInstruction = """
                You polish a creator's note so it reads naturally and consistently, without changing what it says.
                Rules:
                \(languageRule)
                - Preserve all facts, structure, and the note's purpose.
                - Do not add new claims or invent details.
                - Return only the rewritten note. Do not explain.
                """
            } else {
                prompt = """
                Brand Voice profile:
                \(profile)

                Rewrite the note below so it follows this Brand Voice profile.

                Note to rewrite:
                \(content)
                """

                systemInstruction = """
                You rewrite a creator's note using their saved Brand Voice profile.
                Rules:
                \(languageRule)
                - Apply the saved tone, audience, preferred CTA, avoided wording, and example-post style when provided.
                - Treat example posts as style references only. Do not copy their sentences, phrases, claims, or topics.
                - Use the preferred CTA only if it fits the rewritten note naturally.
                - Respect the avoided wording and style notes.
                - Preserve the note's meaning, facts, and structure. Do not invent new facts.
                - Return only the rewritten note. Do not explain.
                """
            }

        case "repurpose_pack":
            let preferences = RepurposePackPreferences.current
            let formats = preferences.selectedFormatNames.joined(separator: ", ")
            let formatRules = preferences.selectedFormatRules
            let outputTemplate = preferences.selectedOutputTemplate
            let threadLengthInstruction = preferences.threadLengthInstruction
            let ctaRule = preferences.includeCTA
                ? "- Include a light, natural call to action on each piece when it fits."
                : "- Do not add a call to action."
            prompt = """
            Repurpose this long-form content into native posts for these formats: \(formats).

            \(threadLengthInstruction)
            Tone: \(preferences.tone.localizedTitle)

            Long-form content:
            \(content)
            """

            systemInstruction = """
            You repurpose one piece of long-form content (a blog post, video script, transcript, essay, or newsletter) into native posts for multiple platforms. The text is existing content, not a chat message.

            Core rules:
            \(languageRule)
            - First identify the single core thesis and 3-5 key takeaways, then reshape them per platform.
            - Rewrite natively for each format. Do not truncate the same paragraph and paste it everywhere.
            - Do not invent facts, stats, quotes, or results that are not supported by the content.
            - Preserve the author's intent and point of view.
            \(ctaRule)
            - Return only the repurposed posts. Do not explain your reasoning.

            Format rules:
            \(formatRules)

            Output format:
            Use only the selected formats and keep this exact section style:

            \(outputTemplate)
            """

        default:
            prompt = """
            Instruction:
            \(self.prompt)

            Notes:
            \(content)
            """

            systemInstruction = """
            You are a helpful assistant.
            Rules:
            \(languageRule)
            - Follow the user's instruction precisely.
            - Return only the result without any extra commentary.
            """
        }

        return try await GeminiService.shared.generateContent(
            prompt: prompt,
            systemInstruction: systemInstruction,
            usageType: .agentRecipe
        )
    }

    /// Execute the recipe on given notes
    @MainActor
    func execute(on notes: [Note], context: ModelContext, userInstruction: String? = nil) async throws -> Note {
        // Just join the content directly without adding metadata wrappers which confuse the AI
        let combinedContent = notes.map { $0.content }.joined(separator: "\n\n---\n\n")
        let result = try await generateResult(from: combinedContent, userInstruction: userInstruction)
        
        guard let userId = AuthService.shared.currentUserId else {
            throw NSError(
                domain: "AgentRecipe",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: L10n.text("common.error.sign_in_required")]
            )
        }
        let note = Note(content: result, userId: userId)
        context.insert(note)
        return note
    }
}
