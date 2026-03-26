import SwiftUI

struct HomeSelectionOverlayView: View {
    let isSelectionMode: Bool
    let isAgentMenuOpen: Bool
    let recipeManager: RecipeManager
    let selectedNotesCount: Int
    let guideStep: HomeFirstUseGuideStep
    let highlightedRecipeID: String
    let onStartAIChat: () -> Void
    let onToggleAgentMenu: () -> Void
    let onCloseMenu: () -> Void
    let onOpenChillRecipes: () -> Void
    let onHandleAgentActionRequest: (AgentRecipe) -> Void

    @State private var shouldHighlightAddButton = false

    private var guideBubbleMessage: String? {
        switch guideStep {
        case .addSkill:
            if selectedNotesCount == 0 {
                return String(localized: "Select the note you just recorded, then choose a Skill.")
            }
            return String(localized: "Great. Now choose a Skill like Summarize to see how it works.")
        case .runSkill:
            if selectedNotesCount == 0 {
                return String(localized: "Select the note you just recorded, then choose a Skill.")
            }
            return String(localized: "Great. Now choose a Skill like Summarize to see how it works.")
        case .recordFirstNote, .openSelection, .completed:
            return nil
        }
    }

    var body: some View {
        if isSelectionMode {
            ZStack(alignment: .bottom) {
                if isAgentMenuOpen {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .onTapGesture {
                            onCloseMenu()
                        }
                        .transition(.opacity)
                }

                VStack(spacing: 0) {
                    if let guideBubbleMessage {
                        HomeSelectionGuideBubble(message: guideBubbleMessage)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 12)
                    }

                    if isAgentMenuOpen {
                        VStack(spacing: 16) {
                            HStack {
                                Text("Chill Skills")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button {
                                    onCloseMenu()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        onOpenChillRecipes()
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                        Text(recipeManager.savedRecipes.isEmpty ? "Add your first Skill" : "Add Skills")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundColor(.accentPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background((recipeManager.savedRecipes.isEmpty ? Color.accentPrimary.opacity(0.18) : Color.accentPrimary.opacity(0.1)))
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(recipeManager.savedRecipes.isEmpty ? Color.accentPrimary : Color.clear, lineWidth: 1.5)
                                    )
                                    .scaleEffect(recipeManager.savedRecipes.isEmpty && shouldHighlightAddButton ? 1.04 : 1.0)
                                    .shadow(
                                        color: recipeManager.savedRecipes.isEmpty ? Color.accentPrimary.opacity(0.24) : .clear,
                                        radius: shouldHighlightAddButton ? 12 : 6,
                                        y: 4
                                    )
                                    .accessibilityLabel("Add Skills")
                                }
                            }
                            .padding(.horizontal, 4)
                            .onAppear {
                                guard recipeManager.savedRecipes.isEmpty else { return }
                                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                                    shouldHighlightAddButton = true
                                }
                            }

                            if recipeManager.savedRecipes.isEmpty {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text("Add your first Skill")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundColor(.textMain)

                                    Text("Tap the top-right button to add one. If you're not sure where to start, try Summarize.")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.textSub)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            } else {
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 16) {
                                    ForEach(recipeManager.savedRecipes) { recipe in
                                        Button(action: {
                                            onCloseMenu()
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                onHandleAgentActionRequest(recipe)
                                            }
                                        }) {
                                            VStack(spacing: 10) {
                                                RecipeGridIcon(recipe: recipe, size: 22, container: 52)

                                                Text(recipe.localizedName)
                                                    .font(.system(size: 12, weight: recipe.id == highlightedRecipeID ? .semibold : .medium))
                                                    .foregroundColor(.primary)
                                                    .multilineTextAlignment(.center)
                                                    .lineLimit(2)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 18)
                                                    .fill(recipe.id == highlightedRecipeID ? Color.accentPrimary.opacity(0.12) : Color.clear)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 18)
                                                    .stroke(recipe.id == highlightedRecipeID ? Color.accentPrimary : Color.clear, lineWidth: 1.5)
                                            )
                                        }
                                        .buttonStyle(ScaleButtonStyle())
                                    }
                                }
                            }
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(24)
                        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95)))
                    }

                    HStack(spacing: 16) {
                        Button(action: onStartAIChat) {
                            Text("Ask AI")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [Color.accentPrimary, Color.accentPrimary.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: Color.accentPrimary.opacity(0.35), radius: 10, x: 0, y: 5)
                        }

                        Button(action: onToggleAgentMenu) {
                            HStack(spacing: 6) {
                                Text("Chill Skills")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))

                                Image(systemName: "chevron.up")
                                    .font(.system(size: 14, weight: .bold))
                                    .rotationEffect(.degrees(isAgentMenuOpen ? 180 : 0))
                            }
                            .foregroundColor(.accentPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(100)
        }
    }
}

private struct RecipeGridIcon: View {
    let recipe: AgentRecipe
    var size: CGFloat = 20
    var container: CGFloat = 52

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.bgSecondary)
                .frame(width: container, height: container)
                .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)

            if recipe.icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Image(systemName: recipe.systemIcon)
                    .font(.system(size: size))
                    .foregroundColor(.accentPrimary)
            } else {
                Text(recipe.icon)
                    .font(.system(size: size + 2))
            }
        }
    }
}
