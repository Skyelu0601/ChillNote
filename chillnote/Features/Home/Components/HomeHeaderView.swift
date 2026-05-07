import SwiftUI

struct HomeHeaderView: View {
    let isSelectionMode: Bool
    let isTrashSelected: Bool
    let isSearchVisible: Bool
    let isRecording: Bool
    let headerTitle: String
    let selectedNotesCount: Int
    let visibleNotesCount: Int
    let hasPendingRecordings: Bool
    let highlightSelectionEntry: Bool

    let onToggleSidebar: () -> Void
    let onCreateBlankNote: () -> Void
    let onEnterSelectionMode: () -> Void
    let onToggleSearch: () -> Void
    let onExitSelectionMode: () -> Void
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onShowBatchTagSheet: () -> Void
    let onShowDeleteConfirmation: () -> Void
    let onShowEmptyTrashConfirmation: () -> Void

    var body: some View {
        HStack {
            if !isSelectionMode {
                Button(action: onToggleSidebar) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.textMain)
                        .frame(width: 44, height: 44)
                        .overlay(alignment: .topTrailing) {
                            if hasPendingRecordings {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: -8, y: 8)
                            }
                        }
                }
                .buttonStyle(.bouncy)
                .padding(.leading, -10)

                Text(headerTitle)
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .foregroundColor(.black)

                Spacer()

                HStack(spacing: 10) {
                    Button(action: onToggleSearch) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(isSearchVisible ? .accentPrimary : .textMain)
                            .frame(width: 36, height: 36)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.bouncy)
                    .disabled(isRecording)
                    .accessibilityLabel(L10n.text("home.header.accessibility.search"))

                    if !isTrashSelected {
                        Button(action: onEnterSelectionMode) {
                            HomeAIEntryIcon(
                                isRecording: isRecording,
                                isHighlighted: highlightSelectionEntry
                            )
                        }
                        .buttonStyle(.bouncy)
                        .disabled(isRecording)
                        .accessibilityLabel(L10n.text("home.header.accessibility.enter_ai_context_mode"))
                    }

                    if isTrashSelected {
                        Button(action: onShowEmptyTrashConfirmation) {
                            Image(systemName: "trash.slash")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.red.opacity(0.85))
                                .frame(width: 36, height: 36)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.bouncy)
                        .accessibilityLabel(L10n.text("home.header.accessibility.empty_recycle_bin"))
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.05))
                .clipShape(Capsule())
                .opacity(isRecording ? 0.3 : 1.0)
            } else {
                HStack {
                    Button(L10n.text("common.cancel")) {
                        onExitSelectionMode()
                    }
                    .font(.bodyMedium)
                    .foregroundColor(.textSub)

                    Spacer()

                    HStack(spacing: 20) {
                        if selectedNotesCount < visibleNotesCount {
                            Button(L10n.text("home.header.select_all")) {
                                onSelectAll()
                            }
                            .font(.bodyMedium)
                            .foregroundColor(.accentPrimary)
                        } else {
                            Button(L10n.text("home.header.deselect_all")) {
                                onDeselectAll()
                            }
                            .font(.bodyMedium)
                            .foregroundColor(.accentPrimary)
                        }

                        Button(action: onShowBatchTagSheet) {
                            Image(systemName: "tag")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.accentPrimary)
                        }
                        .disabled(selectedNotesCount == 0)
                        .opacity(selectedNotesCount == 0 ? 0.3 : 1.0)

                        Button(action: onShowDeleteConfirmation) {
                            Image(systemName: "trash")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.red.opacity(0.8))
                        }
                        .disabled(selectedNotesCount == 0)
                        .opacity(selectedNotesCount == 0 ? 0.3 : 1.0)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
}

private struct HomeAIEntryIcon: View {
    let isRecording: Bool
    let isHighlighted: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundFill)
                .frame(width: 30, height: 30)

            LightningGlyph()
                .fill(iconColor)
                .frame(width: 13, height: 16)
                .offset(x: -0.4, y: 0.3)
        }
        .frame(width: 36, height: 36)
        .opacity(isRecording ? 0.72 : 1.0)
    }

    private var backgroundFill: Color {
        if isRecording {
            return Color.textMain.opacity(0.04)
        }

        if isHighlighted {
            return Color.accentPrimary.opacity(0.12)
        }

        return .clear
    }

    private var iconColor: Color {
        isRecording ? Color.textSub.opacity(0.92) : Color.textMain
    }
}

private struct LightningGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + rect.width * 0.62, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.minY + rect.height * 0.56))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.47, y: rect.minY + rect.height * 0.56))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.34, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.38))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.68, y: rect.minY + rect.height * 0.38))
        path.closeSubpath()

        return path
    }
}
