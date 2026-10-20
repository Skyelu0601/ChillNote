import SwiftUI

struct NoteDetailAISkillsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ChillRecipesView()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("common.close")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }
}
