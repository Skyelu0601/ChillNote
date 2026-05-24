import SwiftUI

struct NoteDetailEditorSectionView: View {
    let note: Note
    @Binding var noteContent: String
    @Binding var editorSelection: RichTextEditorSelection
    let isDeleted: Bool
    let isProcessing: Bool
    let isVoiceProcessing: Bool
    let onRemoveTag: (Tag) -> Void
    let onAddTagClick: () -> Void

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                Text(note.createdAt.relativeFormatted())
                    .font(.bodySmall)
                    .foregroundColor(.textSub)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                if let source = note.sourceMetadata {
                    NoteSourceCard(source: source)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 14)
                        .opacity(isDeleted ? 0.5 : 1)
                        .allowsHitTesting(!isDeleted)
                }

                if note.importStatus == .queued || note.importStatus == .processing {
                    LinkImportStatusBanner(
                        iconName: "link.badge.plus",
                        text: L10n.text("quick_capture.link_import.status.processing")
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
                } else if note.importStatus == .failed {
                    LinkImportStatusBanner(
                        iconName: "exclamationmark.triangle.fill",
                        text: L10n.text("quick_capture.link_import.status.failed")
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
                }

                TagBannerView(
                    tags: note.tags,
                    onRemove: onRemoveTag,
                    onAddClick: onAddTagClick
                )
                .padding(.bottom, 16)
                .padding(.horizontal, 20)
                .opacity(isDeleted ? 0.5 : 1)
                .allowsHitTesting(!isDeleted)

                RichTextEditorView(
                    text: $noteContent,
                    selection: $editorSelection,
                    isEditable: !isProcessing && !isVoiceProcessing && !isDeleted,
                    font: .systemFont(ofSize: 17),
                    textColor: UIColor(Color.textMain),
                    bottomInset: 40,
                    isScrollEnabled: false
                )
                .padding(.horizontal, 4)
                .opacity(isProcessing ? 0.6 : 1)
                .frame(minHeight: 400)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct LinkImportStatusBanner: View {
    let iconName: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.accentPrimary)
            Text(text)
                .font(.chillCaption)
                .foregroundColor(.textSub)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentPrimary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
