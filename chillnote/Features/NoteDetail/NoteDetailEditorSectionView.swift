import SwiftUI

struct NoteDetailEditorSectionView: View {
    let note: Note
    @Binding var noteContent: String
    let isDeleted: Bool
    let isProcessing: Bool
    let isVoiceProcessing: Bool
    let onConfirmTag: (String) -> Void
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

                TagBannerView(
                    tags: note.tags,
                    suggestedTags: note.suggestedTags,
                    onConfirm: onConfirmTag,
                    onRemove: onRemoveTag,
                    onAddClick: onAddTagClick
                )
                .padding(.bottom, 16)
                .padding(.horizontal, 20)
                .opacity(isDeleted ? 0.5 : 1)
                .allowsHitTesting(!isDeleted)

                RichTextEditorView(
                    text: $noteContent,
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
