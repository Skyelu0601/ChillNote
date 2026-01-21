import Foundation
import SwiftData

/// Represents a user-configurable AI action (preset or custom)
@Model
final class CustomAIAction {
    var id: UUID
    var title: String
    var icon: String
    var systemPrompt: String
    var isEnabled: Bool
    var order: Int
    var isPreset: Bool // True for built-in actions, false for user-created
    var presetType: String? // Maps to AIQuickAction.ActionType.rawValue for presets
    
    init(
        id: UUID = UUID(),
        title: String,
        icon: String,
        systemPrompt: String,
        isEnabled: Bool = true,
        order: Int = 0,
        isPreset: Bool = false,
        presetType: String? = nil
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.systemPrompt = systemPrompt
        self.isEnabled = isEnabled
        self.order = order
        self.isPreset = isPreset
        self.presetType = presetType
    }
    
    /// Execute this action on given content
    func execute(on content: String) async throws -> String {
        let fullPrompt = """
        \(systemPrompt)
        
        Original note:
        \(content)
        """
        
        return try await GeminiService.shared.generateContent(
            prompt: fullPrompt,
            systemInstruction: """
            You are a professional writing assistant.
            Rules:
            \(LanguageDetection.languagePreservationRule(for: content))
            - Preserve the original structure and formatting (including markdown, code blocks, and line breaks) unless the instruction explicitly requests changes.
            - Always return only the transformed content without explanations or meta-commentary.
            """
        )
    }
    
    /// Create a CustomAIAction from a preset AIQuickAction
    static func fromPreset(_ preset: AIQuickAction, order: Int) -> CustomAIAction {
        return CustomAIAction(
            title: preset.title,
            icon: preset.icon,
            systemPrompt: preset.systemPrompt,
            isEnabled: true,
            order: order,
            isPreset: true,
            presetType: preset.type.rawValue
        )
    }
}
