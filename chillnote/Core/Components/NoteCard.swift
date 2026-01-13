import SwiftUI

struct NoteCard: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(note.displayText)
                .font(.bodyMedium) // Slighly larger for list style
                .foregroundColor(.textMain)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            HStack {
                Text(note.createdAt.formatted(date: .numeric, time: .shortened))
                    .font(.chillCaption)
                    .foregroundColor(.textSub)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.textSub.opacity(0.5))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(note.displayText)
        .accessibilityHint("Note.")
    }
}

// Preview Mock
#Preview {
    ZStack {
        Color.bgSecondary.ignoresSafeArea()
        NoteCard(note: Note(content: "Remember to buy milk and check the post office for that package."))
    }
}
