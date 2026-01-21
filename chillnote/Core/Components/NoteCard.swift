import SwiftUI

struct NoteCard: View {
    let note: Note
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onSelectionToggle: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox (only visible in selection mode)
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .accentPrimary : .textSub.opacity(0.3))
            }
            
            VStack(alignment: .leading, spacing: 12) {
                // Unified Rich Text Preview - renders all content including checkboxes as formatted text
                RichTextPreview(
                    content: note.content,
                    lineLimit: 4,
                    font: .bodyMedium,
                    textColor: .textMain
                )
                

                
                HStack {
                    Text(note.createdAt.relativeFormatted())
                        .font(.chillCaption)
                        .foregroundColor(.textSub)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.textSub.opacity(0.5))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(isSelected ? Color.selectionHighlight : Color.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.mellowYellow : Color.clear, lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(note.displayText)
        .accessibilityHint("Note.")
        .contentShape(Rectangle())
        .simultaneousGesture(
            isSelectionMode ? TapGesture().onEnded {
                onSelectionToggle?()
            } : nil
        )
    }
}

// Preview Mock
#Preview {
    ZStack {
        Color.bgSecondary.ignoresSafeArea()
        VStack {
            NoteCard(note: Note(content: "Remember to buy milk"))
            // Mock checklist note is harder without context setup, just showing text note
        }
    }
}
