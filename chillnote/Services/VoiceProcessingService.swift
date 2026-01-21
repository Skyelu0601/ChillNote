import Foundation

/// Service for processing voice transcripts with intent recognition and structuring
@MainActor
class VoiceProcessingService {
    static let shared = VoiceProcessingService()
    
    private init() {}
    
    /// Process raw voice transcript into structured, usable text
    /// This handles intent recognition and automatic formatting
    func processTranscript(_ rawTranscript: String) async throws -> String {
        let trimmed = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        
        // Skip AI processing for very short inputs (likely just a word or two)
        if trimmed.count < 20 {
            return trimmed
        }
        
        let prompt = """
        Process this voice transcript into clean, directly usable text.
        
        Voice transcript:
        \(trimmed)
        """
        
        let systemInstruction = """
        You are a voice-to-text optimizer called "chillnote". Your job is to transform raw speech transcripts into polished, ready-to-use notes.
        
        Follow these CORE CAPABILITIES:
        1. REMOVES FILLER: Automatically remove filler words like "um", "uh", "like", "you know", "basically", "so yeah".
        2. REMOVES REPETITION: Detect and remove unnecessary repeated words or phrases to ensure the language is concise and easy to understand.
        3. AUTO-EDITS (SELF-CORRECTION): Recognize when the speaker corrects themselves mid-sentence (e.g., "I want to go on Tuesday... no, Wednesday") and keep only the final intended message.
        4. AUTO-FORMATS: Automatically organize spoken lists, steps, and key points into clear, structured text (Markdown).
           - If the user mentions "todo", "task", or "remind me" -> Use checkboxes: - [ ] item
           - If the user mentions "list" or "bullets" -> Use bullet points
           - If the user implies a sequence -> Use numbered lists
        5. FIND THE PERFECT WORDS: Effortlessly improve word choice and flow for clarity without changing the original meaning.
        6. DIFFERENT TONES FOR DIFFERENT APPS: Adapt the tone based on mentioned targets:
           - "Email": Professional format with greeting and closing.
           - "Twitter/X/Tweet": Punchy, concise, and easy to scan.
           - "Meeting Notes": Structured with headers and action items.

        STRICT RULES:
        - LANGUAGE PRESERVATION: Keep the SAME language as the input (Chinese stays Chinese, English stays English). Do NOT translate.
        - NO EXPLANATIONS: Return ONLY the processed note text. Do not add "Here is your note" or any metadata.
        - MINIMAL CHANGE: If the input is already clean and short, return it mostly unchanged.
        """
        
        return try await GeminiService.shared.generateContent(
            prompt: prompt,
            systemInstruction: systemInstruction
        )
    }
    
    /// Process voice command for the Voice Agent (placeholder for future expansion)
    /// Currently returns the command for logging, but will be expanded for actual agent actions
    func processAgentCommand(_ rawTranscript: String) async throws -> AgentCommandResult {
        let trimmed = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // For now, just return a placeholder result
        // This will be expanded when Voice Agent features are defined
        return AgentCommandResult(
            command: trimmed,
            action: .unknown,
            message: "Voice Agent received: \(trimmed)"
        )
    }
}

// MARK: - Voice Agent Types (Placeholder for future expansion)

struct AgentCommandResult {
    let command: String
    let action: AgentAction
    let message: String
}

enum AgentAction {
    case unknown
    case createNote
    case searchNotes
    case summarizeNotes
    case deleteNote
    // Future actions to be added
}
