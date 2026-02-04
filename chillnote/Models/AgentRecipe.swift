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
    case care = "Care"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .organize: return "tray.full"
        case .publish: return "megaphone"
        case .care: return "heart"
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
            description: "Condense long text into a short summary.",
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
            description: "Combine selected notes into one cohesive document.",
            prompt: """
            You are merging multiple existing notes from the same user (these notes were not written for a chat). Combine them into one cohesive note while preserving the user’s intent and tone.

            - Keep the merged note in the same language as the originals.
            - Remove true duplicates but keep distinct details.
            - Preserve decisions, action items, dates, and numbers.
            - If notes disagree or use different versions, briefly note the discrepancy instead of choosing a side.
            - If the notes already have headings or sections, reuse that structure when possible.

            Output only the merged note.
            """,
            category: .organize
        ),
        AgentRecipe(
            id: "translate",
            icon: "🌍",
            systemIcon: "globe",
            name: "Translate",
            description: "Translate notes into another language.",
            prompt: """
            You are translating a user’s existing note (not a chat message). Translate it into the target language while preserving the note’s intent and tone.

            - Keep the original meaning and level of formality.
            - Preserve formatting (headings, lists, bullet points, spacing).
            - Keep proper nouns, URLs, and code unchanged unless there is a widely accepted translation.
            - If a phrase is ambiguous or culturally specific, pick the most likely meaning and keep the original in parentheses when helpful.
            """,
            category: .organize
        ),
        AgentRecipe(
            id: "fix_grammar",
            icon: "✅",
            systemIcon: "checkmark.circle",
            name: "Fix Grammar",
            description: "Correct all grammatical errors.",
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
            description: "Stretch a brief idea into richer detail.",
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
            description: "Turn notes into an email draft.",
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
            description: "ADHD helper that breaks tasks into zero-resistance steps.",
            prompt: """
            You are helping break down a user’s existing note into a zero-resistance action plan (the note was not written for a chat). Create a simple checklist that builds momentum.

            - Keep the output in the same language as the note.
            - Start with one "Start Step" that takes 5 minutes or less and needs no special setup.
            - Follow with small, concrete steps that have clear completion signals.
            - Keep it light, practical, and encouraging—focus on getting started, not perfection.
            - If the note is vague, make reasonable assumptions and still produce a usable checklist.

            Output only the checklist.
            """,
            category: .care
        ),
        // MARK: - Media
        AgentRecipe(
            id: "twitter_post",
            icon: "🐦",
            systemIcon: "bubble.left",
            name: "X (Twitter)",
            description: "Turn a note into a concise post for X (Twitter).",
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
            description: "Turn a note into a professional LinkedIn post.",
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
            description: "Turn a note into a YouTube video script.",
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
            description: "Simplify complex topics so anyone can follow.",
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
        ),
        // MARK: - Care
        AgentRecipe(
            id: "reflect",
            icon: "🪞",
            systemIcon: "sparkles",
            name: "Reflect",
            description: "Self-healing clarity from a compassionate mirror.",
            prompt: """
            You are reflecting on a user’s existing note (not a chat message). Offer a gentle, non-judgmental reflection that helps the user see their experience more clearly.

            - Keep the output in the same language as the note.
            - Summarize the emotions or themes you can reasonably infer.
            - Highlight any patterns or tensions in a soft, respectful way.
            - Avoid diagnosis or certainty; keep it supportive and grounded.
            - End with a brief, gentle insight that invites self-reflection.

            Output only the reflection.
            """,
            category: .care
        )
    ]
}
