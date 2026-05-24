import Foundation
import SwiftUI

final class RecipeManager: ObservableObject {
    static let shared = RecipeManager()
    private static let retiredRecipeIds: Set<String> = [
        "draft_email",
        "devils_advocate",
        "fix_grammar",
        "release_notes",
        "merge_notes"
    ]

    @AppStorage("savedRecipesJSON") private var savedRecipesJSON: String = "[]"
    @AppStorage("customRecipesJSON") private var customRecipesJSON: String = "[]"
    @AppStorage("defaultRecipesInstalled") private var defaultRecipesInstalled = false
    @AppStorage("captionPackRecipeInstalled") private var captionPackRecipeInstalled = false

    @Published var savedRecipes: [AgentRecipe] = [] {
        didSet { saveToDisk() }
    }

    @Published var savedRecipeIds: Set<String> = []
    @Published var customRecipes: [AgentRecipe] = [] {
        didSet { saveCustomToDisk() }
    }

    private init() {
        loadFromDisk()
        installDefaultRecipesIfNeeded()
        installCaptionPackRecipeIfNeeded()
    }

    func toggleRecipe(_ recipe: AgentRecipe) {
        if savedRecipeIds.contains(recipe.id) {
            removeRecipe(recipe)
        } else {
            addRecipe(recipe)
        }
    }

    func addRecipe(_ recipe: AgentRecipe) {
        guard !savedRecipeIds.contains(recipe.id) else { return }
        savedRecipes.append(recipe)
        savedRecipeIds.insert(recipe.id)
    }

    func removeRecipe(_ recipe: AgentRecipe) {
        savedRecipes.removeAll { $0.id == recipe.id }
        savedRecipeIds.remove(recipe.id)
    }

    func isAdded(_ recipe: AgentRecipe) -> Bool {
        savedRecipeIds.contains(recipe.id)
    }

    func addCustomRecipe(name: String, systemIcon: String, prompt: String) -> AgentRecipe {
        let recipe = AgentRecipe(
            id: "custom_\(UUID().uuidString)",
            icon: "",
            systemIcon: systemIcon,
            name: name,
            description: L10n.text("recipes.custom_skill"),
            prompt: prompt,
            category: .shape,
            isCustom: true
        )
        customRecipes.append(recipe)
        addRecipe(recipe)
        return recipe
    }

    func deleteCustomRecipe(_ recipe: AgentRecipe) {
        customRecipes.removeAll { $0.id == recipe.id }
        removeRecipe(recipe)
    }

    func installDefaultRecipesIfNeeded() {
        guard !defaultRecipesInstalled else { return }
        guard savedRecipes.isEmpty else {
            defaultRecipesInstalled = true
            return
        }

        let defaultIDs = ["hook_generator", "caption_pack", "humanizer"]
        let defaults = AgentRecipe.allRecipes.filter { defaultIDs.contains($0.id) }
        guard !defaults.isEmpty else { return }

        savedRecipes = defaults
        savedRecipeIds = Set(defaults.map(\.id))
        defaultRecipesInstalled = true
    }

    func installCaptionPackRecipeIfNeeded() {
        guard !captionPackRecipeInstalled else { return }
        guard let recipe = AgentRecipe.allRecipes.first(where: { $0.id == "caption_pack" }) else { return }

        if !savedRecipeIds.contains(recipe.id) {
            addRecipe(recipe)
        }
        captionPackRecipeInstalled = true
    }

    private func loadFromDisk() {
        if let data = customRecipesJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([AgentRecipe].self, from: data) {
            customRecipes = decoded
        } else {
            customRecipes = []
        }

        if let data = savedRecipesJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([AgentRecipe].self, from: data) {
            savedRecipes = decoded.filter { !Self.retiredRecipeIds.contains($0.id) }
        } else {
            savedRecipes = []
            savedRecipeIds = []
        }
        savedRecipeIds = Set(savedRecipes.map { $0.id })
    }

    private func saveToDisk() {
        if let encoded = try? JSONEncoder().encode(savedRecipes),
           let jsonString = String(data: encoded, encoding: .utf8) {
            savedRecipesJSON = jsonString
            savedRecipeIds = Set(savedRecipes.map { $0.id })
        }
    }


    private func saveCustomToDisk() {
        if let encoded = try? JSONEncoder().encode(customRecipes),
           let jsonString = String(data: encoded, encoding: .utf8) {
            customRecipesJSON = jsonString
        }
    }
}
