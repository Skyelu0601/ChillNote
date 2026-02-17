import SwiftUI

struct NoteDetailHeaderView: View {
    let isDeleted: Bool
    let isRecording: Bool
    let recordingTimeString: String
    let isTidyEnabled: Bool
    let onBack: () -> Void
    let onRestore: () -> Void
    let onStopRecording: () -> Void
    let onTidy: () -> Void
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
            .accessibilityLabel("Back")

            Spacer()

            if isDeleted {
                Button(action: onRestore) {
                    Label("Restore", systemImage: "arrow.uturn.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.accentPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.accentPrimary.opacity(0.1))
                        .clipShape(Capsule())
                }
                .accessibilityLabel("Restore Note")
            } else if isRecording {
                HStack(spacing: 8) {
                    Text(recordingTimeString)
                        .font(.system(size: 14, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.accentPrimary)

                    Image(systemName: "waveform")
                        .symbolEffect(.variableColor.iterative.dimInactiveLayers, isActive: true)
                        .font(.system(size: 14))
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
                    Button(action: onTidy) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 16))
                            .foregroundColor(.accentPrimary)
                            .frame(width: 32, height: 32)
                            .background(Color.bgSecondary)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Chillo's Magic")
                    .disabled(!isTidyEnabled)
                    .opacity(isTidyEnabled ? 1 : 0.5)

                    Menu {
                        Button(action: onExport) {
                            Label("Export Markdown", systemImage: "square.and.arrow.up")
                        }

                        Button(role: .destructive, action: onDelete) {
                            Label("Delete Note", systemImage: "trash")
                        }

                        Button(role: .destructive, action: onDeletePermanently) {
                            Label("Delete Permanently", systemImage: "trash.slash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16))
                            .foregroundColor(.textSub)
                            .frame(width: 32, height: 32)
                            .background(Color.bgSecondary)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("More Actions")
                }
            }
        }
    }
}
