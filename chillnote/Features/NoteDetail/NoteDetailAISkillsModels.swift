import Foundation

enum NoteAISkillApplyMode: String, CaseIterable, Identifiable {
    case appendToEnd
    case replaceAll

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appendToEnd:
            return L10n.text("note_detail.ai_skills.apply.append_to_end")
        case .replaceAll:
            return L10n.text("note_detail.ai_skills.apply.replace_all")
        }
    }

    var systemImage: String {
        switch self {
        case .appendToEnd:
            return "text.append"
        case .replaceAll:
            return "doc.text"
        }
    }
}

struct NoteAISkillPreview: Identifiable {
    let id = UUID()
    let recipe: AgentRecipe
    let result: String
    let sourceContent: String
    let sourceSelection: RichTextEditorSelection
    let instruction: String?

    var hasSelection: Bool {
        !sourceSelection.isCollapsed
    }

    var inputContent: String {
        hasSelection ? sourceSelection.selectedText : sourceContent
    }

    var availableApplyModes: [NoteAISkillApplyMode] {
        [.appendToEnd, .replaceAll]
    }
}

enum NoteAITransformation {
    case aiSkill(NoteAISkillPreview, NoteAISkillApplyMode)
}
