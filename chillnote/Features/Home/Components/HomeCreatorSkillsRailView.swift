import SwiftUI

struct HomeCreatorSkillsRailView: View {
    let recipes: [AgentRecipe]
    let onRecipeTap: (AgentRecipe) -> Void
    let onAddMoreTap: () -> Void

    private var orderedRecipes: [AgentRecipe] {
        let priorityIDs = ["hook_generator", "caption_pack", "rewrite", "repurpose_pack"]
        let priority = priorityIDs.compactMap { id in recipes.first { $0.id == id } }
        let remaining = recipes.filter { recipe in !priorityIDs.contains(recipe.id) }
        return priority + remaining
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(orderedRecipes) { recipe in
                    Button {
                        onRecipeTap(recipe)
                    } label: {
                        HomeCreatorSkillChip(recipe: recipe)
                    }
                    .buttonStyle(.tactile)
                }

                Button(action: onAddMoreTap) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.accentPrimary)
                        .frame(width: 42, height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.bgPrimary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.borderSubtle, lineWidth: 1)
                        )
                }
                .buttonStyle(.bouncy)
                .accessibilityLabel(L10n.text("home.creator_skills.add_more"))
            }
            .padding(.horizontal, 1)
            .padding(.vertical, 1)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.bgSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.borderSubtle, lineWidth: 1)
                )
        )
        .shadow(color: Color.shadowColor.opacity(0.55), radius: 8, x: 0, y: 3)
    }
}

private struct HomeCreatorSkillChip: View {
    let recipe: AgentRecipe

    var body: some View {
        HStack(spacing: 8) {
            CreatorSkillIcon(recipe: recipe, size: 15, container: 30)

            Text(recipe.localizedName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.textMain)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.leading, 7)
        .padding(.trailing, 10)
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.bgPrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.borderSubtle, lineWidth: 1)
        )
    }
}
