import Foundation

/// Represents the smart formatting AI action for visual formatting
struct AIQuickAction: Identifiable {
    let id = UUID()
    let type: ActionType
    let title: String
    let icon: String
    let description: String
    let systemPrompt: String
    
    enum ActionType: String, CaseIterable {
        case smartFormat = "smart_format"
        
        var defaultAction: AIQuickAction {
            switch self {
            case .smartFormat:
                return AIQuickAction(
                    type: .smartFormat,
                    title: "Smart Format",
                    icon: "wand.and.stars",
                    description: "Intelligently enhance text structure and styling",
                    systemPrompt: """
                    You are a professional typesetter. Your task is to enhance the VISUAL STRUCTURE of the text.
                    
                    Rules:
                    - DO NOT change or rewrite the meaning of the content
                    - Add appropriate headers (using # markdown) to organize sections when there are distinct topics
                    - Convert lists of items to bullet points (using - )
                    - Bold (**text**) key terms, names, or important phrases for emphasis
                    - Add line breaks between logical sections for readability
                    - If there are actionable items or tasks, format them as checkboxes: - [ ] item
                    - For quotes or important callouts, use blockquotes (> text)
                    - Use *italic* for supplementary notes or emphasis
                    - Keep the original language, do NOT translate
                    - Preserve all original information - only improve structure and formatting
                    - Return only the formatted content without any explanation
                    """
                )
            }
        }
    }
    
    /// Default set of quick actions (now only smart format)
    static let defaultActions: [AIQuickAction] = ActionType.allCases.map { $0.defaultAction }
    
    /// Execute the action on given content
    func execute(on content: String) async throws -> String {
        let fullPrompt = """
        \(systemPrompt)
        
        Original content to format:
        \(content)
        """
        
        return try await GeminiService.shared.generateContent(
            prompt: fullPrompt,
            systemInstruction: """
            You are a professional typesetter and document designer.
            Rules:
            \(LanguageDetection.languagePreservationRule(for: content))
            - Your job is ONLY visual formatting - never change the meaning or rewrite content.
            - Use markdown formatting: # headers, **bold**, *italic*, - bullets, - [ ] checkboxes, > quotes, --- dividers
            - Always return only the formatted content without explanations or meta-commentary.
            """
        )
    }
}
