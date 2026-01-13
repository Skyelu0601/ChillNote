import SwiftUI
import SwiftData

struct NoteDetailView: View {
    @Bindable var note: Note
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.textMain)
                            .padding(8)
                    }
                    Spacer()
                    Button("Save") {
                        note.updatedAt = Date()
                        try? modelContext.save()
                        dismiss()
                    }
                    .font(.bodyMedium)
                    .fontWeight(.bold)
                    .foregroundColor(.chillYellow)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                Text(note.createdAt.formatted())
                    .font(.bodySmall)
                    .foregroundColor(.textSub)
                    .padding(.horizontal, 20)

                TextEditor(text: $note.content)
                    .font(.bodyLarge)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 16)
            }
        }
        .navigationBarHidden(true)
    }
}

#Preview {
    NoteDetailView(note: Note(content: "Hello"))
        .modelContainer(DataService.shared.container!)
}
