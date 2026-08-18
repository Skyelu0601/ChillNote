import SwiftUI

struct NoteDetailHeaderView: View {
    let isDeleted: Bool
    let onBack: () -> Void
    let onRestore: () -> Void
    let onAddTopic: () -> Void
    let onExport: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.textMain)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.bouncy)
            .accessibilityLabel(L10n.text("note_detail.header.accessibility.back"))

            Spacer()

            if isDeleted {
                Button(action: onRestore) {
                    Label(L10n.text("home.notes.action.restore"), systemImage: "arrow.uturn.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.accentPrimary)
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(Color.accentPrimary.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.tactile)
                .accessibilityLabel(L10n.text("note_detail.header.accessibility.restore_note"))
            } else {
                Menu {
                    Button(action: onAddTopic) {
                        Label(L10n.text("note_detail.tag.add"), systemImage: "tag")
                    }

                    Divider()

                    Button(action: onExport) {
                        Label(L10n.text("note_detail.header.action.export_markdown"), systemImage: "square.and.arrow.up")
                    }

                    Button(role: .destructive, action: onDelete) {
                        Label(L10n.text("note_detail.header.action.delete_note"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textMain)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(L10n.text("note_detail.header.accessibility.more_actions"))
            }
        }
        .frame(height: 44)
    }
}
