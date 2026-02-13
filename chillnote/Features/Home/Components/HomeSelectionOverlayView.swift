import SwiftUI

struct HomeSelectionOverlayView: View {
    let isSelectionMode: Bool
    let isAgentMenuOpen: Bool
    let recipeManager: RecipeManager
    let onStartAIChat: () -> Void
    let onToggleAgentMenu: () -> Void
    let onCloseMenu: () -> Void
    let onOpenChillRecipes: () -> Void
    let onHandleAgentActionRequest: (AgentRecipe) -> Void

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
                    if isAgentMenuOpen {
                        VStack(spacing: 16) {
                            HStack {
                                Text("Chill Recipes")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button {
                                    onCloseMenu()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        onOpenChillRecipes()
                                    }
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.accentPrimary)
                                        .accessibilityLabel("Add Recipes")
                                }
                            }
                            .padding(.horizontal, 4)

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

                                            Text(recipe.name)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.primary)
                                                .multilineTextAlignment(.center)
                                                .lineLimit(2)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                                if recipeManager.savedRecipes.isEmpty {
                                    VStack(spacing: 8) {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 20))
                                            .foregroundColor(.secondary)
                                        Text("No recipes yet")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
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
                            HStack(spacing: 4) {
                                Text("Ask")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                Image("chillohead_touming")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 28)
                            }
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
                                Text("Chill Recipes")
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
