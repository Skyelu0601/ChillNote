import Foundation
import SwiftUI

struct AgentRecipe: Identifiable, Hashable, Codable {
    let id: String
    let systemIcon: String // SF Symbol for buttons
    let name: String
    let description: String
    let prompt: String
    let isCustom: Bool
    
    var localizedName: String {
        isCustom ? name : L10n.text("agent_recipe.\(id).name")
    }

    var localizedDescription: String {
        isCustom ? description : L10n.text("agent_recipe.\(id).description")
    }

    init(
        id: String,
        systemIcon: String,
        name: String,
        description: String,
        prompt: String,
        isCustom: Bool = false
    ) {
        self.id = id
        self.systemIcon = systemIcon
        self.name = name
        self.description = description
        self.prompt = prompt
        self.isCustom = isCustom
    }

    enum CodingKeys: String, CodingKey {
        case id
        case systemIcon
        case name
        case description
        case prompt
        case isCustom
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        systemIcon = try container.decode(String.self, forKey: .systemIcon)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        prompt = try container.decode(String.self, forKey: .prompt)
        isCustom = (try? container.decode(Bool.self, forKey: .isCustom)) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(systemIcon, forKey: .systemIcon)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(prompt, forKey: .prompt)
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

    static let captionOptions = allCases.filter { $0 != .storyDriven && $0 != .creatorVoice }

    static func fromCaptionRawValue(_ value: String?) -> CaptionPackTone {
        captionOptions.first { $0.rawValue == value } ?? .casualUseful
    }

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
            return "- TikTok: Under the platform heading, output ready-to-publish caption text, then a blank line and up to 5 relevant hashtags. Do not include field labels such as Caption or Hashtags (in any language), quotation marks around the caption, or explanatory text. Keep the complete post, including hashtags, under 2,200 characters. Generate hashtags specific to the notes; do not copy template placeholders."
        case .instagramReels:
            return "- Instagram Reels: Under the platform heading, output ready-to-publish caption text, then a blank line and up to 5 relevant hashtags. Do not include field labels such as Caption or Hashtags (in any language), quotation marks around the caption, or explanatory text. Keep the complete post, including hashtags, under 2,200 characters. Generate hashtags specific to the notes; do not copy template placeholders."
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

            [Ready-to-publish caption text]

            [Up to 5 hashtags relevant to the notes]
            """
        case .instagramReels:
            return """
            ## Instagram Reels

            [Ready-to-publish caption text]

            [Up to 5 hashtags relevant to the notes]
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
            tone: CaptionPackTone.fromCaptionRawValue(defaults.string(forKey: toneKey)),
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

enum TranslatePreferences {
    static let targetLanguageKey = "translateTargetLanguage"

    static var currentLanguage: TranslateLanguage {
        language(for: UserDefaults.standard.string(forKey: targetLanguageKey))
    }

    static func language(for id: String?) -> TranslateLanguage {
        let normalizedID = ["pt", "pt-PT", "pt-BR"].contains(id ?? "") ? "pt-BR" : id
        return TranslateLanguage.defaultLanguages.first { $0.id == normalizedID }
            ?? TranslateLanguage.defaultLanguages.first { $0.id == "en" }!
    }
}

struct BrandVoicePreferences {
    static let sampleKey = "brandVoiceSample" // Legacy single-example storage.
    static let samplesKey = "brandVoiceSamples"
    var samples: [String] = []

    static var current: BrandVoicePreferences { load(from: .standard) }

    static func load(from defaults: UserDefaults) -> BrandVoicePreferences {
        let samples = defaults.stringArray(forKey: samplesKey)
            ?? [defaults.string(forKey: sampleKey) ?? ""]
        return BrandVoicePreferences(samples: samples.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(samples.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }, forKey: Self.samplesKey)
    }

    var isConfigured: Bool { samples.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }

    var promptProfile: String {
        samples.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }.enumerated()
            .map { "Writing example \($0.offset + 1):\n\($0.element)" }
            .joined(separator: "\n\n")
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

enum RepurposeFormat: String, CaseIterable, Identifiable {
    case tiktok = "repurposePackFormatTikTok"
    case instagramReels = "repurposePackFormatInstagramReels"
    case youtubeShorts = "repurposePackFormatYouTubeShorts"
    case youtubeVideo = "repurposePackFormatYouTubeVideo"
    case newsletter = "repurposePackFormatNewsletter"
    case xPost = "repurposePackFormatXPost"
    case threads = "repurposePackFormatThreads"
    case linkedin = "repurposePackFormatLinkedIn"
    var id: String { rawValue }
    static let defaultFormats: [RepurposeFormat] = [.tiktok, .instagramReels]
    static let primaryFormats = Array(allCases.prefix(5))
    static let additionalFormats = Array(allCases.suffix(3))
    var localizedTitle: String {
        switch self {
        case .tiktok: return L10n.text("repurpose_pack.format.tiktok")
        case .instagramReels: return L10n.text("repurpose_pack.format.instagram_reels")
        case .youtubeShorts: return L10n.text("repurpose_pack.format.youtube_shorts")
        case .youtubeVideo: return L10n.text("repurpose_pack.format.youtube_video")
        case .newsletter: return L10n.text("repurpose_pack.format.newsletter")
        case .xPost: return L10n.text("repurpose_pack.format.x_post")
        case .threads: return L10n.text("repurpose_pack.format.threads")
        case .linkedin: return L10n.text("repurpose_pack.format.linkedin")
        }
    }
    var displayName: String {
        switch self {
        case .tiktok: return "TikTok"
        case .instagramReels: return "Instagram Reels"
        case .youtubeShorts: return "YouTube Shorts"
        case .youtubeVideo: return "YouTube Video"
        case .newsletter: return "Newsletter"
        case .xPost: return "X Post"
        case .threads: return "Threads"
        case .linkedin: return "LinkedIn"
        }
    }
    var formatRule: String {
        switch self {
        case .tiktok: return "- TikTok: a ready-to-record video script with a direct, conversational opening, a tightly focused progression, and a natural ending. Reshape the content rather than writing a caption."
        case .instagramReels: return "- Instagram Reels: a ready-to-record video script with a relatable opening, clear progression, and a memorable takeaway. Do not output carousel slides or a publishing caption."
        case .youtubeShorts: return "- YouTube Shorts: a ready-to-record short video script focused on one clear question or insight, delivering its promised answer before a complete ending. Do not output a description or tags."
        case .youtubeVideo: return "- YouTube Video: a complete long-video script with an introduction, clearly titled chapters, transitions, substantive explanations, and a conclusion. Expand supported ideas, not invented facts. Do not return only an outline."
        case .newsletter: return "- Newsletter: a complete email with a subject line, an opening, substantial body sections, and a closing. Target 600-1,000 English words, 1,200-2,000 Chinese characters, or a comparable reading length in other languages when the material supports it. Never return only an intro blurb or pad the email with repetition. Use a shorter complete email if evidence is limited; do not invent anecdotes, statistics, or links."
        case .xPost: return "- X Post: one standalone post, 280 characters or fewer, leading with the strongest takeaway."
        case .threads: return "- Threads: numbered posts (1/, 2/, ...). Each post must be 500 characters or fewer, with a conversational progression."
        case .linkedin: return "- LinkedIn: open with the core insight, use short scannable paragraphs, professional and credible, no hype."
        }
    }
    var outputTemplate: String { "## \(displayName)\n\n..." }
}

struct RepurposePackPreferences {
    static let threadLengthKey = "repurposePackThreadLength"
    static let longVideoMinutesKey = "repurposePackLongVideoMinutes"
    static let longVideoOptions = [5, 8, 12]

    var formats: [RepurposeFormat] = RepurposeFormat.defaultFormats
    var threadLength: RepurposeThreadLength = .medium
    var longVideoMinutes = 5

    static var current: RepurposePackPreferences { load(from: .standard) }

    static func load(from defaults: UserDefaults) -> RepurposePackPreferences {
        let savedFormats = RepurposeFormat.allCases.filter { defaults.bool(forKey: $0.rawValue) }
        let minutes = defaults.integer(forKey: longVideoMinutesKey)
        return RepurposePackPreferences(
            formats: savedFormats.isEmpty ? RepurposeFormat.defaultFormats : savedFormats,
            threadLength: RepurposeThreadLength(rawValue: defaults.string(forKey: threadLengthKey) ?? "") ?? .medium,
            longVideoMinutes: longVideoOptions.contains(minutes) ? minutes : 5
        )
    }

    func save(to defaults: UserDefaults = .standard) {
        for format in RepurposeFormat.allCases {
            defaults.set(selectedFormats.contains(format), forKey: format.rawValue)
        }
        defaults.set(threadLength.rawValue, forKey: Self.threadLengthKey)
        defaults.set(longVideoMinutes, forKey: Self.longVideoMinutesKey)
    }

    var selectedFormats: [RepurposeFormat] { formats.isEmpty ? RepurposeFormat.defaultFormats : formats }
    var selectedFormatNames: [String] { selectedFormats.map(\.displayName) }
    var selectedFormatRules: String { selectedFormats.map(\.formatRule).joined(separator: "\n") }
    var selectedOutputTemplate: String { selectedFormats.map(\.outputTemplate).joined(separator: "\n\n") }
    var threadLengthInstruction: String {
        selectedFormats.contains(.threads) ? "Thread length (Threads): \(threadLength.tweetCountRange) posts." : ""
    }
    var lengthInstruction: String {
        [selectedFormats.contains(.youtubeVideo) ? "YouTube Video target: \(longVideoMinutes) minutes. Use complete spoken sections with chapter headings." : "",
         threadLengthInstruction].filter { !$0.isEmpty }.joined(separator: "\n")
    }
    static let adaptationRules = """

    Adapt the current draft into content for the requested platforms. Use the latest edited draft or the draft selected in our conversation, not the original imported transcript when a revised draft is available.
    - Preserve the core ideas and supported facts. Treat imported creators' personal experiences as reference material, not as the user's own experiences.
    - For video targets, return ready-to-record scripts; publishing captions belong to a separate task.
    - Adapt openings, information order, pacing, detail, and endings to each requested target. Do not repeat the same script with different platform headings, and do not claim that a platform guarantees reach.
    - Expand or condense the content to the requested length only when the available material supports it. Do not invent facts, quotes, results, personal anecdotes, visual details, or links to fill space.
    - For Newsletter, write a complete substantial email, not a teaser or a brief introduction.
    - Return only the requested adapted content, with ## headings reserved for target platforms and ### headings for internal chapters or email sections. Follow explicit conversation preferences over saved defaults.
    """
}

extension AgentRecipe {
    static let allRecipes: [AgentRecipe] = [
        AgentRecipe(
            id: "why_viral",
            systemIcon: "chart.line.uptrend.xyaxis",
            name: "Why Viral",
            description: "agent_recipe.why_viral.description",
            prompt: """
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
            """
        ),
        AgentRecipe(
            id: "summarize",
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
            """
        ),
        AgentRecipe(
            id: "translate",
            systemIcon: "globe",
            name: "Translate",
            description: "agent_recipe.translate.description",
            prompt: "(Built-in Logic) Uses a dynamic translation engine. The target language is selected at runtime."
        ),
        AgentRecipe(
            id: "humanizer",
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
            """
        ),
        AgentRecipe(
            id: "rewrite",
            systemIcon: "pencil.and.scribble",
            name: "Rewrite Content",
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
            """
        ),
        AgentRecipe(
            id: "style_match",
            systemIcon: "waveform",
            name: "Brand Voice",
            description: "agent_recipe.style_match.description",
            prompt: "(Built-in Logic) Rewrites the note in the creator's saved brand voice."
        ),
        AgentRecipe(
            id: "hook_generator",
            systemIcon: "link",
            name: "Write Hooks",
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
            """
        ),
        AgentRecipe(
            id: "title_thumbnail",
            systemIcon: "rectangle.and.text.magnifyingglass",
            name: "Titles & Thumbnail Text",
            description: "agent_recipe.title_thumbnail.description",
            prompt: """
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
            """
        ),
        AgentRecipe(
            id: "caption_pack",
            systemIcon: "megaphone",
            name: "Write Captions",
            description: "agent_recipe.caption_pack.description",
            prompt: "(Built-in Logic) Generates platform-ready captions from creator inspiration notes."
        ),
        AgentRecipe(
            id: "repurpose_pack",
            systemIcon: "arrow.triangle.2.circlepath",
            name: "Repurpose",
            description: "agent_recipe.repurpose_pack.description",
            prompt: "(Built-in Logic) Atomizes one long-form note into native posts for multiple platforms."
        ),
    ]
}

// MARK: - Execution Logic

extension AgentRecipe {
    /// Generate recipe output without deciding where the result should be saved.
    func generateResult(from content: String, userInstruction: String? = nil) async throws -> String {
        let request = generationRequest(from: content, userInstruction: userInstruction)
        return try await GeminiService.shared.generateContent(
            prompt: request.prompt, systemInstruction: request.system, usageType: .agentRecipe
        )
    }

    /// Builds the request for standalone skills; conversational requests use NoteConversationPrompt.
    func generationRequest(from content: String, userInstruction: String? = nil) -> (prompt: String, system: String) {
        let prompt: String
        let systemInstruction: String
        let languageRule = LanguageDetection.languagePreservationRule(for: content)

        switch id {
        case "translate":
            let targetLanguage = (userInstruction?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? userInstruction!
                : TranslatePreferences.currentLanguage.name
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
                - Infer the shared tone, vocabulary, sentence rhythm, and expression style across the writing examples. Prioritize the current request over example style.
                - Treat example posts as style references only. Do not copy their sentences, phrases, claims, or topics.
                - Preserve the note's meaning, facts, and structure. Do not invent new facts.
                - Return only the rewritten note. Do not explain.
                """
            }

        case "repurpose_pack":
            let preferences = RepurposePackPreferences.current
            let formats = preferences.selectedFormatNames.joined(separator: ", ")
            let formatRules = preferences.selectedFormatRules
            let outputTemplate = preferences.selectedOutputTemplate
            let threadLengthInstruction = preferences.lengthInstruction
            prompt = """
            Adapt this draft for these target platforms: \(formats).

            \(threadLengthInstruction)

            Current draft:
            \(content)
            """

            systemInstruction = """
            \(RepurposePackPreferences.adaptationRules)

            Core rules:
            \(languageRule)
            - First identify the single core thesis and 3-5 key takeaways, then reshape them per platform.
            - Rewrite natively for each format. Do not truncate the same paragraph and paste it everywhere.
            - Do not invent facts, stats, quotes, or results that are not supported by the content.
            - Preserve the author's intent and point of view.
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

        return (prompt, systemInstruction)
    }
}
