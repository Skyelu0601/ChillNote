import Foundation

enum NoteSection: String, CaseIterable, Identifiable {
    case inbox
    case drafts
    case published

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inbox:
            return L10n.text("note_section.inbox")
        case .drafts:
            return L10n.text("note_section.drafts")
        case .published:
            return L10n.text("note_section.published")
        }
    }

    var moveActionTitle: String {
        switch self {
        case .inbox:
            return L10n.text("home.notes.action.move_to_inbox")
        case .drafts:
            return L10n.text("home.notes.action.move_to_drafts")
        case .published:
            return L10n.text("home.notes.action.mark_published")
        }
    }

    var systemImage: String {
        switch self {
        case .inbox:
            return "tray"
        case .drafts:
            return "square.and.pencil"
        case .published:
            return "checkmark.seal"
        }
    }
}
