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
        isCustom ? name : NSLocalizedString(name, comment: "")
    }

    var localizedDescription: String {
        isCustom ? description : NSLocalizedString(description, comment: "")
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

enum AgentRecipeCategory: String, CaseIterable, Identifiable, Codable {
    case organize = "Organize"
    case publish = "Media"
    
    var id: String { rawValue }

    var localizedTitle: String {
        NSLocalizedString(rawValue, comment: "")
    }
    
    var icon: String {
        switch self {
        case .organize: return "tray.full"
        case .publish: return "megaphone"
        }
    }
}

extension AgentRecipe {
    static let allRecipes: [AgentRecipe] = [
        // MARK: - Organize
        AgentRecipe(
            id: "summarize",
            icon: "📝",
            systemIcon: "doc.text",
            name: "Summarize",
            description: String(localized: "Condense long text into a short summary."),
            prompt: """
            You are summarizing a user’s existing note (not a chat message). Keep the note’s original intent and tone, and summarize only what’s actually in the note.

            - Write in the same language as the note.
            - Keep key facts, decisions, and action items.
            - If the note is short, give a one-sentence summary or a tightened rewrite.
            - If the note is long or messy, use bullets to make it easier to scan.
            - If something is unclear or conflicting, flag it briefly instead of guessing.
            """,
            category: .organize
        ),
        AgentRecipe(
            id: "merge_notes",
            icon: "🧩",
            systemIcon: "doc.on.doc.fill",
            name: "Merge Notes",
            description: String(localized: "Combine selected notes into one cohesive document."),
            prompt: "(Built-in Logic) Uses advanced internal logic to merge notes intelligently, preserving structure and handling multi-language content.",
            category: .organize
        ),
        AgentRecipe(
            id: "translate",
            icon: "🌍",
            systemIcon: "globe",
            name: "Translate",
            description: String(localized: "Translate notes into another language."),
            prompt: "(Built-in Logic) Uses a dynamic translation engine. The target language is selected at runtime.",
            category: .organize
        ),
        AgentRecipe(
            id: "fix_grammar",
            icon: "✅",
            systemIcon: "checkmark.circle",
            name: "Fix Grammar",
            description: String(localized: "Correct all grammatical errors."),
            prompt: """
            You are fixing grammar in a user’s existing note (not a chat message). Correct grammar and spelling while preserving the original meaning and tone.

            - Keep the output in the same language as the note.
            - Make minimal edits; do not rephrase unless needed for correctness.
            - Preserve formatting (headings, lists, line breaks).
            - If something is unclear, keep the original wording rather than guessing.
            """,
            category: .organize
        ),
        AgentRecipe(
            id: "expand",
            icon: "🪄",
            systemIcon: "sparkles",
            name: "Expand",
            description: String(localized: "Stretch a brief idea into richer detail."),
            prompt: """
            You are expanding a user’s existing note (not a chat message). Elaborate only what the note already suggests, keeping the original intent and tone.

            - Keep the output in the same language as the note.
            - Do not invent new facts; add detail by clarifying, giving plausible examples, or drawing out implications already present.
            - If the note is very short, provide a conservative expansion without adding new facts.
            - Preserve formatting if the note has structure.
            """,
            category: .organize
        ),
        // MARK: - Organize
        AgentRecipe(
            id: "draft_email",
            icon: "✉️",
            systemIcon: "envelope",
            name: "Draft Email",
            description: String(localized: "Turn notes into an email draft."),
            prompt: """
            You are drafting an email based on a user’s existing note (not a chat message). Turn the note into a clear, well-structured email while preserving the user’s intent and tone.

            - Keep the email in the same language as the note.
            - Include a Subject line.
            - If the note doesn’t specify recipient or tone, choose a neutral, professional default.
            - Preserve key facts, dates, and requested actions.
            - If critical details are missing, make reasonable assumptions and keep the email concise.

            Output only the email.
            """,
            category: .organize
        ),
        AgentRecipe(
            id: "adhd_helper",
            icon: "🧠",
            systemIcon: "bolt.fill",
            name: "ADHD Helper",
            description: String(localized: "ADHD helper that breaks tasks into zero-resistance steps."),
            prompt: """
            You are helping break down a user’s existing note into a zero-resistance action plan (the note was not written for a chat). Create a simple checklist that builds momentum.

            - Keep the output in the same language as the note.
            - Start with one "Start Step" that takes 5 minutes or less and needs no special setup.
            - Follow with small, concrete steps that have clear completion signals.
            - Keep it light, practical, and encouraging—focus on getting started, not perfection.
            - If the note is vague, make reasonable assumptions and still produce a usable checklist.

            Output only the checklist.
            """,
            category: .organize
        ),
        // MARK: - Media
        AgentRecipe(
            id: "twitter_post",
            icon: "🐦",
            systemIcon: "bubble.left",
            name: "X (Twitter)",
            description: String(localized: "Turn a note into a concise post for X (Twitter)."),
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
            description: String(localized: "Turn a note into a professional LinkedIn post."),
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
            name: "YouTube Video Script",
            description: String(localized: "Turn a note into a YouTube video script."),
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
        AgentRecipe(
            id: "explain_like_5",
            icon: "🧸",
            systemIcon: "brain",
            name: "Explain Like I'm 5",
            description: String(localized: "Simplify complex topics so anyone can follow."),
            prompt: """
            You are simplifying a user’s existing note (not a chat message). Explain the note in very simple language, while keeping the original meaning.

            - Keep the output in the same language as the note.
            - Use short, clear sentences and everyday words.
            - If a concept is complex, use one simple analogy that stays accurate.
            - Do not add new facts beyond what the note implies.
            - Keep the tone friendly and easy to follow.

            Output only the simplified explanation.
            """,
            category: .organize
        )
    ]
}

// MARK: - Execution Logic
import SwiftData

extension AgentRecipe {
    /// Execute the recipe on given notes
    @MainActor
    func execute(on notes: [Note], context: ModelContext, userInstruction: String? = nil) async throws -> Note {
        // Just join the content directly without adding metadata wrappers which confuse the AI
        let combinedContent = notes.map { $0.content }.joined(separator: "\n\n---\n\n")
        
        let prompt: String
        let systemInstruction: String
        
        // Helper to detect language
        let languageRule = LanguageDetection.languagePreservationRule(for: combinedContent)
        
        switch id {
        case "merge_notes":
            prompt = """
            Merge the following notes into a single, cohesive document.
            
            Original Notes:
            \(combinedContent)
            """
            
            let mergeLanguageRule = mergeLanguageLockRule(for: notes)
            systemInstruction = """
            You are a professional editor.
            Rules:
            \(languageRule)
            \(mergeLanguageRule)
            - Merge the content into a single, well-structured markdown document.
            - Remove redundancy and improve flow.
            - Use markdown for styling (# Headers, **bold**, - list).
            - DO NOT wrap the output in markdown code blocks (```).
            - DO NOT include meta-headers like "Merged Note", "Creation Date", or "[Note 1]".
            - Start directly with the content.
            """
            
        case "translate":
            let targetLanguage = (userInstruction?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? userInstruction!
                : "English"
            prompt = """
            Translate the following notes into \(targetLanguage).
            
            Notes:
            \(combinedContent)
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
            
        default:
            // For all other recipes (custom or other built-ins), use the recipe's prompt as the instruction
            let instruction = self.prompt
            
            prompt = """
            Instruction:
            \(instruction)
            
            Notes:
            \(combinedContent)
            """
            
            systemInstruction = """
            You are a helpful assistant.
            Rules:
            \(languageRule)
            - Follow the user's instruction precisely.
            - Return only the result without any extra commentary.
            """
        }
        
        let result = try await GeminiService.shared.generateContent(
            prompt: prompt,
            systemInstruction: systemInstruction,
            usageType: .agentRecipe
        )
        
        let userId = AuthService.shared.currentUserId ?? "unknown"
        let note = Note(content: result, userId: userId)
        context.insert(note)
        return note
    }

    private func mergeLanguageLockRule(for notes: [Note]) -> String {
        let normalizedTags = notes.compactMap { note in
            let tag = LanguageDetection.dominantLanguageTag(for: note.content)
            return tag?.split(separator: "-").first.map(String.init)
        }

        let uniqueTags = Set(normalizedTags)
        if uniqueTags.count == 1, let onlyTag = uniqueTags.first {
            return "- LANGUAGE LOCK: Keep the merged output in \(onlyTag). Do NOT translate unless explicitly requested."
        }

        return "- LANGUAGE LOCK: If notes contain multiple languages, preserve each language as-is (including code-switching). Do NOT translate unless explicitly requested."
    }
}
