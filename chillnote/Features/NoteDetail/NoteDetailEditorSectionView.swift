import SwiftUI

struct NoteDetailEditorSectionView: View {
    @Binding var noteContent: String
    @Binding var editorSelection: RichTextEditorSelection
    let editorController: RichTextEditorController
    let isDeleted: Bool
    let isProcessing: Bool
    let isVoiceProcessing: Bool
    let minimumHeight: CGFloat
    @Binding var isEditing: Bool

    var body: some View {
        RichTextEditorView(
            text: $noteContent,
            selection: $editorSelection,
            controller: editorController,
            isEditable: !isProcessing && !isVoiceProcessing && !isDeleted,
            font: .systemFont(ofSize: 17),
            textColor: UIColor(Color.textMain),
            bottomInset: 40,
            isScrollEnabled: false,
            isEditing: $isEditing
        )
        .opacity(isProcessing ? 0.6 : 1)
        .frame(minHeight: max(120, minimumHeight), alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NoteDetailContextSectionView: View {
    let note: Note
    let isDeleted: Bool
    let onRemoveTag: (Tag) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let source = note.sourceMetadata {
                NoteSourceCard(source: source)
                    .opacity(isDeleted ? 0.5 : 1)
                    .allowsHitTesting(!isDeleted)
            }

            if note.importStatus == .queued || note.importStatus == .processing {
                NoteDetailImportStatusBanner(
                    iconName: "link.badge.plus",
                    text: L10n.text("quick_capture.link_import.status.processing")
                )
            } else if note.importStatus == .failed {
                NoteDetailImportStatusBanner(
                    iconName: "exclamationmark.triangle.fill",
                    text: L10n.text("quick_capture.link_import.status.failed")
                )
            }

            if note.tags.contains(where: { $0.deletedAt == nil }) {
                TagBannerView(
                    tags: note.tags,
                    onRemove: onRemoveTag
                )
                .opacity(isDeleted ? 0.5 : 1)
                .allowsHitTesting(!isDeleted)
            }
        }
    }
}

private struct NoteDetailImportStatusBanner: View {
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
