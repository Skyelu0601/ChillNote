import SwiftUI
import SwiftData

struct HomeNotesListView: View {
    let cachedVisibleNotes: [Note]
    let isTrashSelected: Bool
    let isSelectionMode: Bool
    let selectedNotes: Set<UUID>
    let onReachBottom: (Note) -> Void
    let onToggleNoteSelection: (Note) -> Void
    let onRestoreNote: (Note) -> Void
    let onDeleteNotePermanently: (Note) -> Void
    let onTogglePin: (Note) -> Void
    let onDeleteNote: (Note) -> Void

    var body: some View {
        if cachedVisibleNotes.isEmpty {
            if isTrashSelected {
                Text("No deleted notes yet. Notes stay for 30 days.")
                    .font(.bodyMedium)
                    .foregroundColor(.textSub)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("home.empty.title")
                    .font(.bodyMedium)
                    .foregroundColor(.textSub)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            LazyVStack(spacing: 16) {
                ForEach(cachedVisibleNotes) { note in
                    let item = NoteListItemViewData(note: note, usePlainPreview: FeatureFlags.usePlainPreviewInList)
                    Group {
                        if isTrashSelected {
                            NavigationLink(value: note) {
                                VStack(alignment: .leading, spacing: 8) {
                                    NoteCard(item: item)
                                    TrashNoteFooterView(note: note)
                                }
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    onRestoreNote(note)
                                } label: {
                                    Label("Restore", systemImage: "arrow.uturn.left")
                                }
                                Button(role: .destructive) {
                                    onDeleteNotePermanently(note)
                                } label: {
                                    Label("Delete Permanently", systemImage: "trash.slash")
                                }
                            }
                        } else if isSelectionMode {
                            NoteCard(
                                item: item,
                                isSelectionMode: true,
                                isSelected: selectedNotes.contains(note.id),
                                onSelectionToggle: {
                                    onToggleNoteSelection(note)
                                }
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onToggleNoteSelection(note)
                            }
                        } else {
                            NavigationLink(value: note) {
                                NoteCard(item: item)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    onTogglePin(note)
                                } label: {
                                    Label(note.pinnedAt == nil ? "Pin" : "Unpin", systemImage: note.pinnedAt == nil ? "pin" : "pin.slash")
                                }
                                Button(role: .destructive) {
                                    onDeleteNote(note)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .onAppear {
                        onReachBottom(note)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, isTrashSelected ? 24 : 100)
        }
    }
}

struct TrashNoteFooterView: View {
    let note: Note

    var body: some View {
        if let deletedAt = note.deletedAt {
            let daysRemaining = TrashPolicy.daysRemaining(from: deletedAt)
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 12))
                    .foregroundColor(.textSub)
                Text("Deleted \(deletedAt.relativeFormatted())")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSub)
                Text("•")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSub)
                Text(daysRemaining == 0 ? "Expires today" : "\(daysRemaining) days left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSub)
            }
            .padding(.horizontal, 8)
        }
    }
}

struct NoteListTagViewData: Identifiable {
    let id: UUID
    let name: String
    let color: Color
}

struct NoteListItemViewData: Identifiable {
    let id: UUID
    let createdAt: Date
    let createdAtRelativeText: String
    let pinnedAt: Date?
    let previewText: String
    let markdownPreviewText: String
    let usePlainPreview: Bool
    let isEmpty: Bool
    let tags: [NoteListTagViewData]
    let hiddenTagCount: Int

    init(note: Note, usePlainPreview: Bool = true) {
        id = note.id
        createdAt = note.createdAt
        createdAtRelativeText = note.createdAt.relativeFormatted()
        pinnedAt = note.pinnedAt

        let trimmed = note.content.trimmingCharacters(in: .whitespacesAndNewlines)
        isEmpty = trimmed.isEmpty
        self.usePlainPreview = usePlainPreview
        previewText = note.displayText
        markdownPreviewText = trimmed

        let prefixTags = Array(note.tags.prefix(3))
        tags = prefixTags.map { tag in
            NoteListTagViewData(id: tag.id, name: tag.name, color: tag.color)
        }
        hiddenTagCount = max(0, note.tags.count - prefixTags.count)
    }
}

struct NoteCard: View {
    let item: NoteListItemViewData
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onSelectionToggle: (() -> Void)? = nil

    private var processingStage: VoiceProcessingStage? {
        guard let state = VoiceProcessingService.shared.processingStates[item.id],
              case .processing(let stage) = state else {
            return nil
        }
        return stage
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isSelectionMode {
                Button(action: {
                    onSelectionToggle?()
                }) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isSelected ? .accentPrimary : .textSub)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.createdAtRelativeText)
                        .font(.chillCaption)
                        .foregroundColor(.textSub)
                    if item.pinnedAt != nil {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.accentPrimary)
                            .padding(.leading, 4)
                            .accessibilityLabel(Text("Pinned"))
                    }
                    Spacer()
                }

                if let stage = processingStage {
                    VoiceProcessingWorkflowView(currentStage: stage, style: .compact)
                        .padding(.top, 2)
                } else {
                    if !item.isEmpty {
                        Group {
                            if item.usePlainPreview {
                                Text(item.previewText)
                                    .font(.bodyMedium)
                                    .foregroundColor(.textMain)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                            } else {
                                RichTextPreview(
                                    content: item.markdownPreviewText,
                                    lineLimit: 3,
                                    font: .bodyMedium,
                                    textColor: .textMain
                                )
                            }
                        }
                    }

                    if !item.tags.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(item.tags) { tag in
                                Text(tag.name)
                                    .font(.chillCaption)
                                    .foregroundColor(tag.color)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(tag.color.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            if item.hiddenTagCount > 0 {
                                Text("+\(item.hiddenTagCount)")
                                    .font(.chillCaption)
                                    .foregroundColor(.textSub)
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.shadowColor, radius: 8, y: 4)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}
