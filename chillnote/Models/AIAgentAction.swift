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
        case generateReport = "generate_report"
        case summarizeAll = "summarize_all"
        case extractCommon = "extract_common"
    }
    
    /// Default set of agent actions
    static let defaultActions: [AIAgentAction] = [
        AIAgentAction(
            type: .merge,
            title: "Merge Notes",
            icon: "doc.on.doc.fill",
            description: "Combine selected notes into one",
            requiresConfirmation: true
        ),
        AIAgentAction(
            type: .generateReport,
            title: "Generate Report",
            icon: "doc.text.fill",
            description: "Create a comprehensive report",
            requiresConfirmation: false
        ),
        AIAgentAction(
            type: .summarizeAll,
            title: "Summarize All",
            icon: "list.bullet.rectangle",
            description: "Create a summary of all notes",
            requiresConfirmation: false
        ),
        AIAgentAction(
            type: .extractCommon,
            title: "Find Patterns",
            icon: "sparkles.rectangle.stack",
            description: "Extract common themes",
            requiresConfirmation: false
        )
    ]
    
    /// Execute the action on given notes
    @MainActor
    func execute(on notes: [Note], context: ModelContext) async throws -> Note {
        let combinedContent = notes.enumerated().map { index, note in
            """
            [Note \(index + 1)]
            Created: \(note.createdAt.formatted(date: .long, time: .shortened))
            Content: \(note.content)
            """
        }.joined(separator: "\n\n---\n\n")
        
        let prompt: String
        let systemInstruction: String
        let languageRule = LanguageDetection.languagePreservationRule(for: combinedContent)
        
        switch type {
        case .merge:
            prompt = """
            Please merge the following notes into a single, well-organized note.
            Preserve all important information while removing redundancy.
            Organize the content logically with clear sections if needed.
            
            Notes to merge:
            \(combinedContent)
            """
            systemInstruction = """
            You are a professional note organizer. Create a clean, well-structured merged note.
            Rules:
            \(languageRule)
            """
            
        case .generateReport:
            prompt = """
            Based on the following notes, generate a comprehensive report.
            Include an executive summary, key findings, and actionable insights.
            Use clear headings and bullet points where appropriate.
            
            Source notes:
            \(combinedContent)
            """
            systemInstruction = """
            You are a professional report writer. Create clear, actionable reports.
            Rules:
            \(languageRule)
            """
            
        case .summarizeAll:
            prompt = """
            Create a concise summary of the following notes.
            Highlight the most important points from each note.
            Organize by theme or chronologically as appropriate.
            
            Notes to summarize:
            \(combinedContent)
            """
            systemInstruction = """
            You are a professional summarizer. Create clear, concise summaries.
            Rules:
            \(languageRule)
            """
            
        case .extractCommon:
            prompt = """
            Analyze the following notes and extract common themes, patterns, and insights.
            Identify recurring topics, ideas, or concerns.
            Present your findings in a clear, organized format.
            
            Notes to analyze:
            \(combinedContent)
            """
            systemInstruction = """
            You are a professional analyst. Identify patterns and insights from data.
            Rules:
            \(languageRule)
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
