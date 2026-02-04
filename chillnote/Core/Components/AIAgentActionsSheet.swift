import SwiftUI

/// Action sheet for AI agent operations on multiple notes
struct AIAgentActionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let selectedCount: Int
    let onActionSelected: (AgentRecipe) -> Void
    
    @ObservedObject private var recipeManager = RecipeManager.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.accentPrimary)
                        Text("Chillo's Toolkit")
                            .font(.displayMedium)
                            .foregroundColor(.textMain)
                        Spacer()
                    }
                    
                    Text("\(selectedCount) note\(selectedCount == 1 ? "" : "s") selected")
                        .font(.bodyMedium)
                        .foregroundColor(.textSub)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
                
                Divider()
                    .background(Color.textSub.opacity(0.2))
                
                // Actions List
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(recipeManager.savedRecipes) { recipe in
                            AgentActionRow(recipe: recipe) {
                                onActionSelected(recipe)
                                dismiss()
                            }
                        }
                    }
                    .padding(24)
                }
                .background(Color.bgPrimary)
            }
            .background(Color.white)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.textSub)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Agent Action Row
private struct AgentActionRow: View {
    let recipe: AgentRecipe
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.mellowYellow.opacity(0.3), Color.mellowOrange.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: recipe.systemIcon)
                        .font(.system(size: 22))
                        .foregroundColor(.accentPrimary)
                }
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.name)
                        .font(.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(.textMain)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.85)
                    
                    Text(recipe.description)
                        .font(.bodySmall)
                        .foregroundColor(.textSub)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.textSub)
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(isPressed ? 0.05 : 0.1), radius: isPressed ? 4 : 8, x: 0, y: isPressed ? 2 : 4)
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
    }
}

#Preview {
    AIAgentActionsSheet(selectedCount: 3) { action in
        print("Selected: \(action.name)")
    }
}
