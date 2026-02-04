import Foundation
import SwiftData

/// Represents an agent action that can be performed on multiple notes
struct AIAgentAction: Identifiable {
    let id = UUID()
    let type: ActionType
    let title: String
    let icon: String
    let description: String
    let requiresConfirmation: Bool
    
    enum ActionType: String {
        case merge = "merge"
        case translate = "translate"
        case custom = "custom"
    }
    
    /// Execute the action on given notes
    @MainActor
    func execute(on notes: [Note], context: ModelContext, userInstruction: String? = nil) async throws -> Note {
        // Just join the content directly without adding metadata wrappers which confuse the AI
        let combinedContent = notes.map { $0.content }.joined(separator: "\n\n---\n\n")
        
        // Helper to detect language
        let languageRule = LanguageDetection.languagePreservationRule(for: combinedContent)
        
        let prompt: String
        let systemInstruction: String
        
        switch type {
        case .merge:
            prompt = """
            Merge the following notes into a single, cohesive document.
            
            Original Notes:
            \(combinedContent)
            """
            
            systemInstruction = """
            You are a professional editor.
            Rules:
            \(languageRule)
            - Merge the content into a single, well-structured markdown document.
            - Remove redundancy and improve flow.
            - Use markdown for styling (# Headers, **bold**, - list).
            - DO NOT wrap the output in markdown code blocks (```).
            - DO NOT include meta-headers like "Merged Note", "Creation Date", or "[Note 1]".
            - Start directly with the content.
            """
        case .translate:
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
        case .custom:
            let instruction = userInstruction?.trimmingCharacters(in: .whitespacesAndNewlines)
            let safeInstruction = instruction?.isEmpty == false ? instruction! : "Use your best judgment to improve the notes."
            prompt = """
            Instruction:
            \(safeInstruction)
            
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
            systemInstruction: systemInstruction
        )
        
        let userId = AuthService.shared.currentUserId ?? "unknown"
        let note = Note(content: result, userId: userId)
        context.insert(note)
        return note
    }
}
