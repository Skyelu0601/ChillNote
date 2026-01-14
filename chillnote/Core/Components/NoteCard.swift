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
                    .onTapGesture {
                        onSelectionToggle?()
                    }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text(note.displayText)
                    .font(.bodyMedium) // Slighly larger for list style
                    .foregroundColor(.textMain)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                // Category tags
                if let categories = note.categories, !categories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories.sorted(by: { $0.order < $1.order })) { category in
                                HStack(spacing: 4) {
                                    Image(systemName: category.icon)
                                        .font(.system(size: 10, weight: .semibold))
                                    Text(category.name)
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(category.color)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(category.color.opacity(0.15))
                                )
                            }
                        }
                    }
                }
                
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
        NoteCard(note: Note(content: "Remember to buy milk and check the post office for that package."))
    }
}
