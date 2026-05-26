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

struct CaptionPackPreferences {
    static let tiktokKey = "captionPackPlatformTikTok"
    static let youtubeShortsKey = "captionPackPlatformYouTubeShorts"
    static let instagramReelsKey = "captionPackPlatformInstagramReels"
    static let goalKey = "captionPackGoal"
    static let toneKey = "captionPackTone"
    static let outputStyleKey = "captionPackOutputStyle"

    var includeTikTok: Bool
    var includeYouTubeShorts: Bool
    var includeInstagramReels: Bool
    var goal: CaptionPackGoal
    var tone: CaptionPackTone
    var outputStyle: CaptionPackOutputStyle

    static var current: CaptionPackPreferences {
        let defaults = UserDefaults.standard
        return CaptionPackPreferences(
            includeTikTok: defaults.object(forKey: tiktokKey) as? Bool ?? true,
            includeYouTubeShorts: defaults.object(forKey: youtubeShortsKey) as? Bool ?? true,
            includeInstagramReels: defaults.object(forKey: instagramReelsKey) as? Bool ?? true,
            goal: CaptionPackGoal(rawValue: defaults.string(forKey: goalKey) ?? "") ?? .startDiscussion,
            tone: CaptionPackTone(rawValue: defaults.string(forKey: toneKey) ?? "") ?? .casualUseful,
            outputStyle: CaptionPackOutputStyle(rawValue: defaults.string(forKey: outputStyleKey) ?? "") ?? .balanced
        )
    }

    var selectedPlatformNames: [String] {
        var platforms: [String] = []
        if includeTikTok { platforms.append("TikTok") }
        if includeYouTubeShorts { platforms.append("YouTube Shorts") }
        if includeInstagramReels { platforms.append("Instagram Reels") }
        return platforms.isEmpty ? ["TikTok", "YouTube Shorts", "Instagram Reels"] : platforms
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
            id: "brainstorm",
            icon: "💡",
            systemIcon: "lightbulb",
            name: "Brainstorm",
            description: "agent_recipe.brainstorm.description",
            prompt: """
            You are brainstorming based on a user’s existing note (not a chat message). Generate 5 distinct, creative angles or ideas to expand upon their initial thought.

            - Keep the output in the same language as the note.
            - Encourage divergent thinking while keeping suggestions practical.
            - Use short, clear bullet points.
            
            Output only the 5 ideas.
            """,
            category: .think
        ),
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
            id: "expand",
            icon: "🪄",
            systemIcon: "sparkles",
            name: "Expand",
            description: "agent_recipe.expand.description",
            prompt: """
            You are expanding a user’s existing note (not a chat message). Elaborate only what the note already suggests, keeping the original intent and tone.

            - Keep the output in the same language as the note.
            - Do not invent new facts; add detail by clarifying, giving plausible examples, or drawing out implications already present.
            - If the note is very short, provide a conservative expansion without adding new facts.
            - Preserve formatting if the note has structure.
            """,
            category: .shape
        ),
        AgentRecipe(
            id: "style_match",
            icon: "🎭",
            systemIcon: "paintbrush.pointed",
            name: "Style Match",
            description: "agent_recipe.style_match.description",
            prompt: """
            You are writing a new piece in the style of a reference text from the user’s existing notes (not a chat message). Use the reference for tone, pacing, structure, and rhetorical moves, but do not copy distinctive sentences, phrases, claims, or proprietary wording.

            - Keep the output in the same language as the note unless the notes clearly request another language.
            - If multiple notes are provided, treat the first note as the style reference and the remaining creator notes as context for the new piece.
            - If only one note is provided, infer the style from that note and create a fresh piece on the same idea without reusing its wording.
            - Preserve the intended audience and format when they are clear.
            - Keep the result original, useful, and ready to edit.
            - Do not explain the style analysis unless the note explicitly asks for analysis.

            Output only the new piece.
            """,
            category: .shape
        ),
        // MARK: - Shape
        AgentRecipe(
            id: "hook_generator",
            icon: "🎣",
            systemIcon: "link",
            name: "Hooks",
            description: "agent_recipe.hook_generator.description",
            prompt: """
            You are an expert copywriter looking at a user’s raw note (not a chat message). Generate 5 punchy, compelling hooks or tweet openers based on the content.

            - Keep the output in the same language as the note.
            - Do not use clickbait or hype. Focus on curiosity and value.
            - Provide a mix of direct and question-based hooks.
            
            Output only the 5 hooks.
            """,
            category: .shape
        ),
        AgentRecipe(
            id: "caption_pack",
            icon: "📣",
            systemIcon: "megaphone",
            name: "Caption Pack",
            description: "agent_recipe.caption_pack.description",
            prompt: "(Built-in Logic) Generates platform-ready captions from creator inspiration notes.",
            category: .publish
        ),
        AgentRecipe(
            id: "twitter_post",
            icon: "🐦",
            systemIcon: "bubble.left",
            name: "X Post",
            description: "agent_recipe.twitter_post.description",
            prompt: """
            You are turning a user’s existing note into a post for X (Twitter). The note was not written for chat. Create a concise, high-signal post that preserves the note’s intent and tone.

            - Keep the output in the same language as the note.
            - Lead with a clear hook or takeaway.
            - Prefer short, punchy sentences.
            - If the note is long, compress it to the most shareable idea.

            Output only the post.
            """,
            category: .publish
        ),
        AgentRecipe(
            id: "linkedin_post",
            icon: "💼",
            systemIcon: "briefcase",
            name: "LinkedIn",
            description: "agent_recipe.linkedin_post.description",
            prompt: """
            You are turning a user’s existing note into a LinkedIn post. The note was not written for chat. Create a clear, professional post that preserves the note’s intent and voice.

            - Keep the output in the same language as the note.
            - Open with the core insight or result.
            - Use short paragraphs or bullets for easy scanning.
            - Keep it professional and credible; avoid hype.
            - If the note is long, focus on the most valuable takeaway.
            - End with a gentle discussion prompt only if it naturally fits.

            Output only the post.
            """,
            category: .publish
        ),
        AgentRecipe(
            id: "youtube_script",
            icon: "🎬",
            systemIcon: "play.rectangle",
            name: "YouTube Script",
            description: "agent_recipe.youtube_script.description",
            prompt: """
            You are turning a user’s existing note into a YouTube video script. The note was not written for chat. Produce a clean, recordable script that stays faithful to the note’s intent and tone.

            - Keep the script in the same language as the note.
            - Structure it as: Hook → Main Points → Summary → CTA.
            - Use short, spoken-friendly sentences.
            - If the note is long, compress to the most useful points.
            - Do not add new facts; expand only what the note supports.
            - Keep it concise enough to record comfortably.

            Output only the script.
            """,
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

        case "caption_pack":
            let preferences = CaptionPackPreferences.current
            let styleInstruction = Self.captionPackStyleInstruction(for: preferences.outputStyle)
            let platforms = preferences.selectedPlatformNames.joined(separator: ", ")
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
            - TikTok: Output Caption and Hashtags. Caption must be under 2,200 characters. Hashtags must be 5 or fewer.
            - YouTube Shorts: Output Title, Description, and Hashtags. Title must be under 100 characters. Description must be under 5,000 characters. Hashtags must be 3 or fewer.
            - Instagram Reels: Output Caption and Hashtags. Caption must be under 2,200 characters. Hashtags must be 5 or fewer.
            - For TikTok and Instagram Reels, naturally fold any question or soft call to action into the caption when it fits. Do not create a separate CTA section.

            Output format:
            Use only the selected platforms and keep this exact section style:

            ## TikTok

            Caption:
            ...

            Hashtags:
            #creatorworkflow #contentstrategy #shortformvideo #tiktoktips #contentideas

            ## YouTube Shorts

            Title:
            ...

            Description:
            ...

            Hashtags:
            #Shorts #ContentStrategy #CreatorTips

            ## Instagram Reels

            Caption:
            ...

            Hashtags:
            #contentcreator #creatorworkflow #reelstips #contentstrategy #socialmediatips
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

    private static func captionPackStyleInstruction(for style: CaptionPackOutputStyle) -> String {
        switch style {
        case .concise:
            return """
            - TikTok caption target: 120-220 characters.
            - YouTube Shorts title target: 35-50 characters.
            - YouTube Shorts description target: 80-150 characters.
            - Instagram Reels caption target: 100-180 characters.
            """
        case .balanced:
            return """
            - TikTok caption target: 300-600 characters.
            - YouTube Shorts title target: 50-70 characters.
            - YouTube Shorts description target: 150-300 characters.
            - Instagram Reels caption target: 250-500 characters.
            """
        case .detailed:
            return """
            - TikTok caption target: 700-1,200 characters.
            - YouTube Shorts title target: 70-90 characters.
            - YouTube Shorts description target: 300-600 characters.
            - Instagram Reels caption target: 600-1,000 characters.
            """
        }
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
