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
    }
    
    /// Default set of agent actions
    static let defaultActions: [AIAgentAction] = [
        AIAgentAction(
            type: .merge,
            title: "Merge Notes",
            icon: "doc.on.doc.fill",
            description: "Combine selected notes into one",
            requiresConfirmation: true
        )
    ]
    
    /// Execute the action on given notes
    @MainActor
    func execute(on notes: [Note], context: ModelContext) async throws -> Note {
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
        }
        
        let result = try await GeminiService.shared.generateContent(
            prompt: prompt,
            systemInstruction: systemInstruction
        )
        
        let note = Note(content: result)
        context.insert(note)
        return note
    }
}
