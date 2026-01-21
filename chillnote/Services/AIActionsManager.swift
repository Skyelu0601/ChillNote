import Foundation
import SwiftData

/// Manages user's AI action configurations
@MainActor
class AIActionsManager: ObservableObject {
    static let shared = AIActionsManager()
    
    @Published var actions: [CustomAIAction] = []
    
    private var modelContext: ModelContext?
    
    private init() {}
    
    /// Initialize with model context and load saved actions
    func initialize(context: ModelContext) {
        self.modelContext = context
        loadActions()
    }
    
    /// Load actions from database, or create defaults if none exist
    func loadActions() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<CustomAIAction>(
            sortBy: [SortDescriptor(\.order)]
        )
        
        do {
            let savedActions = try context.fetch(descriptor)
            
            if savedActions.isEmpty {
                // First time - create default preset actions
                createDefaultActions(context: context)
            } else if needsMigration(savedActions) {
                // Old presets detected - migrate to new typesetting actions
                actions = savedActions
                migrateToNewPresets()
                print("✅ Migrated AI actions to new typesetting presets")
            } else {
                actions = savedActions
            }
        } catch {
            print("⚠️ Failed to load AI actions: \(error)")
            createDefaultActions(context: context)
        }
    }
    
    /// Create default preset actions from AIQuickAction
    private func createDefaultActions(context: ModelContext) {
        let presets = AIQuickAction.ActionType.allCases.enumerated().map { index, type in
            CustomAIAction.fromPreset(type.defaultAction, order: index)
        }
        
        for preset in presets {
            context.insert(preset)
        }
        
        try? context.save()
        actions = presets
    }
    
    /// Check if old presets need migration to new typesetting actions
    private func needsMigration(_ savedActions: [CustomAIAction]) -> Bool {
        // Check for old action types that no longer exist
        let oldPresetTypes = ["emailify", "summary", "todo_list", "proofread", "eli5", "social_polish", "auto_format", "visual_polish", "minimal_clean"]
        let currentPresetTypes = savedActions.compactMap { $0.presetType }
        return currentPresetTypes.contains { oldPresetTypes.contains($0) }
    }
    
    /// Migrate old presets to new typesetting actions
    func migrateToNewPresets() {
        guard let context = modelContext else { return }
        
        // Delete old preset actions
        let oldPresets = actions.filter { $0.isPreset }
        for preset in oldPresets {
            context.delete(preset)
        }
        
        // Keep custom user actions
        let customActions = actions.filter { !$0.isPreset }
        
        // Create new presets
        let newPresets = AIQuickAction.ActionType.allCases.enumerated().map { index, type in
            CustomAIAction.fromPreset(type.defaultAction, order: index)
        }
        
        for preset in newPresets {
            context.insert(preset)
        }
        
        // Reorder custom actions after presets
        for (index, action) in customActions.enumerated() {
            action.order = newPresets.count + index
        }
        
        try? context.save()
        actions = newPresets + customActions
    }
    
    /// Get enabled actions only
    var enabledActions: [CustomAIAction] {
        actions.filter { $0.isEnabled }.sorted { $0.order < $1.order }
    }
    
    /// Add a new custom action
    func addCustomAction(title: String, icon: String, systemPrompt: String) {
        guard let context = modelContext else { return }
        
        let newAction = CustomAIAction(
            title: title,
            icon: icon,
            systemPrompt: systemPrompt,
            isEnabled: true,
            order: actions.count,
            isPreset: false
        )
        
        context.insert(newAction)
        try? context.save()
        
        actions.append(newAction)
    }
    
    /// Update an existing action
    func updateAction(_ action: CustomAIAction, title: String, icon: String, systemPrompt: String) {
        action.title = title
        action.icon = icon
        action.systemPrompt = systemPrompt
        
        try? modelContext?.save()
        objectWillChange.send()
    }
    
    /// Toggle action enabled state
    func toggleAction(_ action: CustomAIAction) {
        action.isEnabled.toggle()
        try? modelContext?.save()
        objectWillChange.send()
    }
    
    /// Delete a custom action (presets can only be disabled, not deleted)
    func deleteAction(_ action: CustomAIAction) {
        guard !action.isPreset, let context = modelContext else { return }
        
        context.delete(action)
        try? context.save()
        
        if let index = actions.firstIndex(where: { $0.id == action.id }) {
            actions.remove(at: index)
        }
    }
    
    /// Reorder actions
    func moveAction(from source: IndexSet, to destination: Int) {
        actions.move(fromOffsets: source, toOffset: destination)
        
        // Update order values
        for (index, action) in actions.enumerated() {
            action.order = index
        }
        
        try? modelContext?.save()
        objectWillChange.send()
    }
    
    /// Reset to defaults
    func resetToDefaults() {
        guard let context = modelContext else { return }
        
        // Delete all existing actions
        for action in actions {
            context.delete(action)
        }
        
        try? context.save()
        actions.removeAll()
        
        // Recreate defaults
        createDefaultActions(context: context)
    }
}
