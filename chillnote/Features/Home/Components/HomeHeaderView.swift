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

    let onToggleSidebar: () -> Void
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

                HStack(spacing: 12) {
                    if !isTrashSelected {
                        Button(action: onEnterSelectionMode) {
                            Image("chillohead_touming")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 44, height: 44)
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                .opacity(isRecording ? 0.3 : 1.0)
                                .grayscale(isRecording ? 1.0 : 0.0)
                        }
                        .buttonStyle(.bouncy)
                        .disabled(isRecording)
                        .accessibilityLabel("Enter AI Context Mode")
                    }

                    Button(action: onToggleSearch) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(isSearchVisible ? .accentPrimary : .textMain.opacity(0.8))
                            .frame(width: 40, height: 40)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            .opacity(isRecording ? 0.3 : 1.0)
                    }
                    .buttonStyle(.bouncy)
                    .disabled(isRecording)
                    .accessibilityLabel("Search")

                    if isTrashSelected {
                        Button(action: onShowEmptyTrashConfirmation) {
                            Image(systemName: "trash.slash")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundColor(.red.opacity(0.85))
                                .frame(width: 40, height: 40)
                                .background(Color.red.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.bouncy)
                        .accessibilityLabel("Empty Recycle Bin")
                    }
                }
            } else {
                HStack {
                    Button("common.cancel") {
                        onExitSelectionMode()
                    }
                    .font(.bodyMedium)
                    .foregroundColor(.textSub)

                    Spacer()

                    HStack(spacing: 20) {
                        if selectedNotesCount < visibleNotesCount {
                            Button("home.action.selectAll") {
                                onSelectAll()
                            }
                            .font(.bodyMedium)
                            .foregroundColor(.accentPrimary)
                        } else {
                            Button("home.action.deselectAll") {
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
