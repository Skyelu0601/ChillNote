import SwiftUI
import SwiftData

/// Settings view for managing AI quick actions
struct AIActionsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var actionsManager: AIActionsManager
    
    @State private var showAddAction = false
    @State private var editingAction: CustomAIAction?
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(actionsManager.actions) { action in
                        ActionRow(
                            action: action,
                            onToggle: {
                                actionsManager.toggleAction(action)
                            },
                            onEdit: {
                                editingAction = action
                            },
                            onDelete: action.isPreset ? nil : {
                                actionsManager.deleteAction(action)
                            }
                        )
                    }
                    .onMove { source, destination in
                        actionsManager.moveAction(from: source, to: destination)
                    }
                } header: {
                    Text("Quick Actions")
                } footer: {
                    Text("智能排版功能可以自动优化文本结构和格式。您也可以添加自定义的AI动作。")
                }
                
                Section {
                    Button(action: { showAddAction = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentPrimary)
                            Text("Add Custom Action")
                                .foregroundColor(.textMain)
                        }
                    }
                } footer: {
                    Text("Create your own AI actions with custom prompts and icons.")
                }
                
                Section {
                    Button(role: .destructive, action: resetToDefaults) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Defaults")
                        }
                    }
                } footer: {
                    Text("这将删除所有自定义动作并恢复内置的智能排版预设。")
                }
            }
            .navigationTitle("AI Quick Actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showAddAction) {
                ActionEditorView(mode: .create) { title, icon, prompt in
                    actionsManager.addCustomAction(title: title, icon: icon, systemPrompt: prompt)
                }
            }
            .sheet(item: $editingAction) { action in
                ActionEditorView(
                    mode: .edit(action),
                    onSave: { title, icon, prompt in
                        actionsManager.updateAction(action, title: title, icon: icon, systemPrompt: prompt)
                    }
                )
            }
        }
    }
    
    private func resetToDefaults() {
        actionsManager.resetToDefaults()
    }
}

// MARK: - Action Row
private struct ActionRow: View {
    let action: CustomAIAction
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: action.icon)
                .font(.system(size: 20))
                .foregroundColor(.accentPrimary)
                .frame(width: 32)
            
            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(.bodyMedium)
                    .foregroundColor(.textMain)
                
                if action.isPreset {
                    Text("Built-in")
                        .font(.caption)
                        .foregroundColor(.textSub)
                }
            }
            
            Spacer()
            
            // Edit button
            Button(action: onEdit) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.accentPrimary.opacity(0.6))
            }
            .buttonStyle(.plain)
            
            // Toggle
            Toggle("", isOn: Binding(
                get: { action.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if let onDelete = onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Action Editor
struct ActionEditorView: View {
    enum Mode {
        case create
        case edit(CustomAIAction)
    }
    
    @Environment(\.dismiss) private var dismiss
    let mode: Mode
    let onSave: (String, String, String) -> Void
    
    @State private var title: String
    @State private var icon: String
    @State private var systemPrompt: String
    @State private var showIconPicker = false
    
    init(mode: Mode, onSave: @escaping (String, String, String) -> Void) {
        self.mode = mode
        self.onSave = onSave
        
        switch mode {
        case .create:
            _title = State(initialValue: "")
            _icon = State(initialValue: "sparkles")
            _systemPrompt = State(initialValue: "")
        case .edit(let action):
            _title = State(initialValue: action.title)
            _icon = State(initialValue: action.icon)
            _systemPrompt = State(initialValue: action.systemPrompt)
        }
    }
    
    private var isValid: Bool {
        !title.isEmpty && !systemPrompt.isEmpty
    }
    
    private var isPreset: Bool {
        if case .edit(let action) = mode {
            return action.isPreset
        }
        return false
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    HStack {
                        Text("Title")
                        Spacer()
                        TextField("e.g., Email Format", text: $title)
                            .multilineTextAlignment(.trailing)
                            .disabled(isPreset)
                    }
                    
                    Button(action: { showIconPicker = true }) {
                        HStack {
                            Text("Icon")
                                .foregroundColor(.textMain)
                            Spacer()
                            Image(systemName: icon)
                                .foregroundColor(.accentPrimary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.textSub)
                        }
                    }
                    .disabled(isPreset)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("System Prompt")
                            .font(.bodySmall)
                            .foregroundColor(.textSub)
                        
                        TextEditor(text: $systemPrompt)
                            .font(.bodyMedium)
                            .frame(minHeight: 200)
                            .disabled(isPreset)
                    }
                } header: {
                    Text("AI Instructions")
                } footer: {
                    if isPreset {
                        Text("Built-in actions cannot be edited. Create a custom action instead.")
                    } else {
                        Text("Describe what you want the AI to do with the note content. Be specific and clear.")
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(title, icon, systemPrompt)
                        dismiss()
                    }
                    .disabled(!isValid || isPreset)
                }
            }
            .sheet(isPresented: $showIconPicker) {
                IconPickerView(selectedIcon: $icon)
            }
        }
    }
}

extension ActionEditorView.Mode {
    var title: String {
        switch self {
        case .create: return "New Action"
        case .edit: return "Edit Action"
        }
    }
}

#Preview {
    AIActionsSettingsView()
        .modelContainer(DataService.shared.container!)
        .environmentObject(AIActionsManager.shared)
}
