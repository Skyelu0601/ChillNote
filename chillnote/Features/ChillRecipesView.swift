import SwiftUI

struct ChillRecipesView: View {
    @StateObject private var recipeManager = RecipeManager.shared
    @StateObject private var storeService = StoreService.shared
    @State private var selectedSection: RecipeSection = .library
    @State private var selectedCategory: AgentRecipeCategory? = nil // nil means "All" effectively, or we default to first
    @State private var showingRecipeDetail: AgentRecipe?
    @State private var showingCreateRecipe = false
    @State private var showingSubscription = false
    @State private var pendingDeleteRecipe: AgentRecipe?

    @State private var newRecipeName = ""
    @State private var newRecipePrompt = ""
    @State private var newRecipeIcon = "sparkles"
    
    @Namespace private var animation

    // Grid layout for the library
    private let gridColumns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
    ]

    var body: some View {
        ZStack {
            // Background
            Color.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Area
                VStack(spacing: 16) {
                    // Custom Segment Control
                    HStack(spacing: 0) {
                        ForEach(RecipeSection.allCases) { section in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedSection = section
                                }
                            } label: {
                                Text(section.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(selectedSection == section ? .white : .textSub)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background {
                                        if selectedSection == section {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.accentPrimary)
                                                .matchedGeometryEffect(id: "SectionTab", in: animation)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .background(Color.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
                .padding(.bottom, 16)

                ScrollView {
                    VStack(spacing: 24) {
                        if selectedSection == .library {
                            // Categories - Full Width
                            HStack(spacing: 10) {
                                ForEach(AgentRecipeCategory.allCases) { category in
                                    CategoryChip(
                                        category: category,
                                        isSelected: selectedCategory == category || (selectedCategory == nil && category == .organize), // Default first if nil
                                        action: {
                                            withAnimation {
                                                selectedCategory = category
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            // Library Grid
                            LazyVGrid(columns: gridColumns, spacing: 16) {
                                ForEach(recipes(for: selectedCategory ?? .organize)) { recipe in
                                    RecipeCard(recipe: recipe, isAdded: recipeManager.isAdded(recipe)) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                            recipeManager.toggleRecipe(recipe)
                                        }
                                    }
                                    .onTapGesture {
                                        showingRecipeDetail = recipe
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                            
                        } else {
                            // My Recipes List
                            if recipeManager.savedRecipes.isEmpty {
                                EmptyStateView(
                                    icon: "doc.text.magnifyingglass",
                                    title: "No Recipes Yet",
                                    message: "Add recipes from the library. Creating your own custom actions is available for paid members."
                                )
                                .padding(.top, 40)
                            } else {
                                LazyVStack(spacing: 12) {
                                    ForEach(recipeManager.savedRecipes) { recipe in
                                        MyRecipeCardRow(
                                            recipe: recipe,
                                            onRemove: { withAnimation { recipeManager.removeRecipe(recipe) } },
                                            onDelete: recipe.isCustom ? { pendingDeleteRecipe = recipe } : nil
                                        )
                                        .onTapGesture {
                                            showingRecipeDetail = recipe
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 80) // Space for FAB
                            }
                        }
                    }
                }
            }
            
            // FAB for My Recipes
            if selectedSection == .myRecipes {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            if storeService.currentTier == .free {
                                showingSubscription = true
                            } else {
                                showingCreateRecipe = true
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.headline)
                                Text("Create")
                                    .font(.headline)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(Color.accentPrimary)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .shadow(color: Color.accentPrimary.opacity(0.4), radius: 10, x: 0, y: 5)
                        }
                        .buttonStyle(.recipeScale)
                        .padding(.trailing, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .navigationTitle("Chill Recipes")
        .sheet(item: $showingRecipeDetail) { recipe in
            RecipeDetailSheet(recipe: recipe, isAdded: recipeManager.isAdded(recipe)) {
                recipeManager.toggleRecipe(recipe)
            }
        }
        .sheet(isPresented: $showingCreateRecipe) {
            CreateRecipeSheet(
                name: $newRecipeName,
                prompt: $newRecipePrompt,
                icon: $newRecipeIcon,
                onSave: saveCustomRecipe,
                onCancel: {
                    resetCreateRecipe()
                    showingCreateRecipe = false
                }
            )
        }
        .sheet(isPresented: $showingSubscription) {
            SubscriptionView()
        }
        .alert("Delete Recipe", isPresented: Binding(
            get: { pendingDeleteRecipe != nil },
            set: { isPresented in if !isPresented { pendingDeleteRecipe = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingDeleteRecipe = nil }
            Button("Delete", role: .destructive) {
                if let recipe = pendingDeleteRecipe {
                    withAnimation { recipeManager.deleteCustomRecipe(recipe) }
                }
                pendingDeleteRecipe = nil
            }
        } message: {
            Text("This will permanently delete this custom recipe.")
        }
    }

    private func recipes(for category: AgentRecipeCategory) -> [AgentRecipe] {
        AgentRecipe.allRecipes.filter { $0.category == category }
    }

    private func saveCustomRecipe() {
        let trimmedName = newRecipeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPrompt = newRecipePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedPrompt.isEmpty else { return }
        _ = recipeManager.addCustomRecipe(
            name: trimmedName,
            systemIcon: newRecipeIcon,
            prompt: trimmedPrompt
        )
        resetCreateRecipe()
        showingCreateRecipe = false
    }

    private func resetCreateRecipe() {
        newRecipeName = ""
        newRecipePrompt = ""
        newRecipeIcon = "sparkles"
    }
}

// MARK: - Subviews

private struct CategoryChip: View {
    let category: AgentRecipeCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(category.rawValue)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentPrimary : Color.bgSecondary)
                .foregroundColor(isSelected ? .white : .textSub)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.accentPrimary.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(.recipeScale)
    }
}

private struct RecipeCard: View {
    let recipe: AgentRecipe
    let isAdded: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                RecipeIcon(recipe: recipe, size: 20, container: 36)
                Spacer()
                Button(action: onToggle) {
                    Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 20))
                        .foregroundColor(isAdded ? .accentPrimary : .textSub.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundColor(.textMain)
                
                Text(recipe.description)
                    .font(.caption)
                    .foregroundColor(.textSub)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 140)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isAdded ? Color.accentPrimary.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

private struct MyRecipeCardRow: View {
    let recipe: AgentRecipe
    let onRemove: () -> Void
    let onDelete: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 16) {
            RecipeIcon(recipe: recipe, size: 24, container: 44)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.textMain)
                Text(recipe.description)
                    .font(.subheadline)
                    .foregroundColor(.textSub)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Menu {
                Button(role: .destructive, action: onRemove) {
                    Label("Remove", systemImage: "minus.circle")
                }
                
                if let onDelete {
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete Permanently", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textSub)
                    .frame(width: 28, height: 28)
                    .background(Color.bgSecondary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

private struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.textSub.opacity(0.3))
                .padding(.bottom, 4)
            
            Text(title)
                .font(.title3.bold())
                .foregroundColor(.textMain)
            
            Text(message)
                .font(.body)
                .foregroundColor(.textSub)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Helper Views

private struct RecipeIcon: View {
    let recipe: AgentRecipe
    var size: CGFloat = 24
    var container: CGFloat = 40

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.bgSecondary)
                .frame(width: container, height: container)

            if recipe.icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Image(systemName: recipe.systemIcon)
                    .font(.system(size: size))
                    .foregroundColor(.accentPrimary)
            } else {
                Text(recipe.icon)
                    .font(.system(size: size))
            }
        }
    }
}

private struct RecipeDetailSheet: View {
    let recipe: AgentRecipe
    let isAdded: Bool
    let onToggle: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Sheet Handle
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            HStack(spacing: 16) {
                RecipeIcon(recipe: recipe, size: 36, container: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.name)
                        .font(.title2.bold())
                        .foregroundColor(.textMain)
                    Text(recipe.description)
                        .font(.subheadline)
                        .foregroundColor(.textSub)
                }
            }
            .padding(.horizontal, 24)

            Divider()
                .padding(.horizontal, 24)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Prompt")
                        .font(.headline)
                        .foregroundColor(.textMain)
                    
                    Text(recipe.prompt)
                        .font(.body.monospaced())
                        .foregroundColor(.textSub)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(24)
            }
            
            Button(action: {
                onToggle()
                dismiss() // Optional: dismiss after action
            }) {
                Text(isAdded ? "Remove from My Recipes" : "Add to My Recipes")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isAdded ? Color.red.opacity(0.1) : Color.accentPrimary)
                    .foregroundColor(isAdded ? .red : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.recipeScale)
            .padding(24)
        }
    }
}

// Basic scaling button style
private struct RecipeScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

extension ButtonStyle where Self == RecipeScaleButtonStyle {
    static var recipeScale: RecipeScaleButtonStyle { RecipeScaleButtonStyle() }
}

private struct CreateRecipeSheet: View {
    @Binding var name: String
    @Binding var prompt: String
    @Binding var icon: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @State private var isIconPickerPresented = false

    var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe Details") {
                    TextField("Name (e.g. Summarize)", text: $name)
                    
                    Button(action: { isIconPickerPresented = true }) {
                        HStack {
                            Text("Icon")
                                .foregroundColor(.textMain)
                            Spacer()
                            Image(systemName: icon.isEmpty ? "sparkles" : icon)
                                .foregroundColor(.textMain)
                        }
                    }
                }

                Section("Prompt") {
                    TextEditor(text: $prompt)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("Create Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .disabled(isSaveDisabled)
                }
            }
            .sheet(isPresented: $isIconPickerPresented) {
                IconPickerView(selectedIcon: $icon)
            }
        }
    }
}

private enum RecipeSection: String, CaseIterable, Identifiable {
    case library = "library"
    case myRecipes = "myRecipes"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .library: return "Library"
        case .myRecipes: return "My Recipes"
        }
    }
}

#Preview {
    NavigationStack {
        ChillRecipesView()
    }
}
