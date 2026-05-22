import Foundation

enum NoteAISkillApplyMode: String, CaseIterable, Identifiable {
    case replaceSelection
    case insertAtCursor
    case insertBelowSelection
    case appendToEnd
    case replaceAll

    var id: String { rawValue }

    var title: String {
        switch self {
        case .replaceSelection:
            return L10n.text("note_detail.ai_skills.apply.replace_selection")
        case .insertAtCursor:
            return L10n.text("note_detail.ai_skills.apply.insert_at_cursor")
        case .insertBelowSelection:
            return L10n.text("note_detail.ai_skills.apply.insert_below_selection")
        case .appendToEnd:
            return L10n.text("note_detail.ai_skills.apply.append_to_end")
        case .replaceAll:
            return L10n.text("note_detail.ai_skills.apply.replace_all")
        }
    }

    var systemImage: String {
        switch self {
        case .replaceSelection:
            return "arrow.triangle.2.circlepath"
        case .insertAtCursor:
            return "text.cursor"
        case .insertBelowSelection:
            return "arrow.down.doc"
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
        if hasSelection {
            return [.replaceSelection, .insertBelowSelection, .appendToEnd, .replaceAll]
        }
        return [.insertAtCursor, .appendToEnd, .replaceAll]
    }
}

enum NoteAITransformation {
    case tidy
    case aiSkill(NoteAISkillPreview, NoteAISkillApplyMode)
}
