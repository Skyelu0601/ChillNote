import SwiftUI

struct NoteDetailHeaderView: View {
    let isDeleted: Bool
    let isAISkillsEnabled: Bool
    let onBack: () -> Void
    let onRestore: () -> Void
    let onAISkills: () -> Void
    let onTeleprompter: () -> Void
    let onExport: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.textMain)
                    .padding(8)
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
                        .padding(.vertical, 8)
                        .background(Color.accentPrimary.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.tactile)
                .accessibilityLabel(L10n.text("note_detail.header.accessibility.restore_note"))
            } else {
                HStack(spacing: 4) {
                    Button(action: onAISkills) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.brandBlue)
                            .rotationEffect(.degrees(4))
                            .frame(width: 36, height: 36)
                            .background(Color.brandBlueSoft)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.bouncy)
                    .disabled(!isAISkillsEnabled)
                    .opacity(isAISkillsEnabled ? 1 : 0.55)
                    .accessibilityLabel(L10n.text("note_detail.header.accessibility.ai_skills"))
                    .firstActionGuideTarget(.aiSkills)

                    Button(action: onTeleprompter) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.brandBlue)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.bouncy)
                    .accessibilityLabel(L10n.text("note_detail.header.action.teleprompter"))
                    .firstActionGuideTarget(.teleprompter)

                    Menu {
                        Button(action: onExport) {
                            Label(L10n.text("note_detail.header.action.export_markdown"), systemImage: "square.and.arrow.up")
                        }

                        Button(role: .destructive, action: onDelete) {
                            Label(L10n.text("note_detail.header.action.delete_note"), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16))
                            .foregroundColor(.textSub)
                            .frame(width: 36, height: 36)
                            .background(Color.textSub.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(L10n.text("note_detail.header.accessibility.more_actions"))
                }
                .padding(4)
                .background(Color.bgSecondary)
                .clipShape(Capsule())
                .shadow(color: Color.shadowColor, radius: 8, x: 0, y: 3)
            }
        }
    }
}
