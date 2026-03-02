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

                HStack(spacing: 2) {
                    Button(action: onToggleSearch) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(isSearchVisible ? .accentPrimary : .textMain)
                            .frame(width: 36, height: 36)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.bouncy)
                    .disabled(isRecording)
                    .accessibilityLabel("Search")

                    if !isTrashSelected {
                        Button(action: onCreateBlankNote) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.textMain)
                                .frame(width: 36, height: 36)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.bouncy)
                        .disabled(isRecording)
                        .accessibilityLabel("Create Blank Note")

                        Button(action: onEnterSelectionMode) {
                            Image("chillohead_touming")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30, height: 30)
                                .frame(width: 36, height: 36)
                                .grayscale(isRecording ? 1.0 : 0.0)
                        }
                        .buttonStyle(.bouncy)
                        .disabled(isRecording)
                        .accessibilityLabel("Enter AI Context Mode")
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
                        .accessibilityLabel("Empty Recycle Bin")
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.05))
                .clipShape(Capsule())
                .opacity(isRecording ? 0.3 : 1.0)
            } else {
                HStack {
                    Button("Cancel") {
                        onExitSelectionMode()
                    }
                    .font(.bodyMedium)
                    .foregroundColor(.textSub)

                    Spacer()

                    HStack(spacing: 20) {
                        if selectedNotesCount < visibleNotesCount {
                            Button("Select All") {
                                onSelectAll()
                            }
                            .font(.bodyMedium)
                            .foregroundColor(.accentPrimary)
                        } else {
                            Button("Deselect All") {
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
