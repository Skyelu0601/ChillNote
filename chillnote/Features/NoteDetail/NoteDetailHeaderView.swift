import SwiftUI

struct NoteDetailHeaderView: View {
    let isDeleted: Bool
    let isRecording: Bool
    let recordingTimeString: String
    let isTidyEnabled: Bool
    let isAISkillsEnabled: Bool
    let onBack: () -> Void
    let onRestore: () -> Void
    let onStopRecording: () -> Void
    let onTidy: () -> Void
    let onAISkills: () -> Void
    let onExport: () -> Void
    let onDelete: () -> Void
    let onDeletePermanently: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.textMain)
                    .padding(8)
            }
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
                .accessibilityLabel(L10n.text("note_detail.header.accessibility.restore_note"))
            } else if isRecording {
                HStack(spacing: 8) {
                    Text(recordingTimeString)
                        .font(.system(size: 14, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.accentPrimary)

                    Button(action: onStopRecording) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.accentPrimary)
                            .clipShape(Circle())
                    }
                }
                .padding(.leading, 12)
                .padding(.trailing, 4)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.bgSecondary))
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else {
                HStack(spacing: 8) {
                    Button(action: onAISkills) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16))
                            .foregroundColor(.accentPrimary)
                            .frame(width: 32, height: 32)
                            .background(Color.bgSecondary)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(L10n.text("note_detail.header.accessibility.ai_skills"))
                    .disabled(!isAISkillsEnabled)
                    .opacity(isAISkillsEnabled ? 1 : 0.5)

                    Button(action: onTidy) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 16))
                            .foregroundColor(.accentPrimary)
                            .frame(width: 32, height: 32)
                            .background(Color.bgSecondary)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(L10n.text("note_detail.header.accessibility.chillo_magic"))
                    .disabled(!isTidyEnabled)
                    .opacity(isTidyEnabled ? 1 : 0.5)

                    Menu {
                        Button(action: onExport) {
                            Label(L10n.text("note_detail.header.action.export_markdown"), systemImage: "square.and.arrow.up")
                        }

                        Button(role: .destructive, action: onDelete) {
                            Label(L10n.text("note_detail.header.action.delete_note"), systemImage: "trash")
                        }

                        Button(role: .destructive, action: onDeletePermanently) {
                            Label(L10n.text("home.notes.action.delete_permanently"), systemImage: "trash.slash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16))
                            .foregroundColor(.textSub)
                            .frame(width: 32, height: 32)
                            .background(Color.bgSecondary)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(L10n.text("note_detail.header.accessibility.more_actions"))
                }
            }
        }
    }
}
