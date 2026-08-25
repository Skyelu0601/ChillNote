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
    let onToggleSearch: () -> Void
    let onExitSelectionMode: () -> Void
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onShowDeleteConfirmation: () -> Void
    let onShowEmptyTrashConfirmation: () -> Void

    var body: some View {
        Group {
            if isSelectionMode {
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
            } else {
                ZStack {
                    HStack {
                        sidebarButton

                        Spacer()

                        trailingTools
                    }

                    headerTitleView
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    private var sidebarButton: some View {
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
    }

    private var headerTitleView: some View {
        titleText
    }

    @ViewBuilder
    private var titleText: some View {
        if headerTitle == "ChillScript" {
            (
                Text(verbatim: "Chill")
                    .foregroundColor(.black)
                + Text(verbatim: "Script")
                    .foregroundColor(.brandBlue)
            )
            .font(.system(size: 24, weight: .semibold, design: .serif))
        } else {
            Text(headerTitle)
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundColor(.black)
                .lineLimit(1)
        }
    }

    private var trailingTools: some View {
        HStack(spacing: 6) {
            Button(action: onToggleSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(isSearchVisible ? .brandBlue : .textMain)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.bouncy)
            .disabled(isRecording)
            .accessibilityLabel(L10n.text("home.header.accessibility.search"))

            if isTrashSelected {
                Button(action: onShowEmptyTrashConfirmation) {
                    HomeHeaderToolIcon(
                        systemImage: "trash.slash",
                        tint: .red.opacity(0.85)
                    )
                }
                .buttonStyle(.bouncy)
                .accessibilityLabel(L10n.text("home.header.accessibility.empty_recycle_bin"))
            }
        }
        .opacity(isRecording ? 0.3 : 1.0)
    }
}

private struct HomeHeaderToolIcon: View {
    let systemImage: String
    let tint: Color
    var isHighlighted: Bool = false

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(tint)
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(Color.bgSecondary)
            )
            .overlay(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.brandBlue.opacity(isHighlighted ? 0.10 : 0.04),
                                Color.white.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .clipShape(Circle())
            .overlay(
                Circle()
                    .strokeBorder(
                        isHighlighted ? Color.brandBlue.opacity(0.18) : Color.borderSubtle,
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.shadowColor, radius: 5, x: 0, y: 2)
            .contentShape(Circle())
    }
}
