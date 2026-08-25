import Foundation
import OSLog
import SwiftUI

final class RecipeManager: ObservableObject {
    static let shared = RecipeManager()
    private static let logger = Logger(subsystem: "com.chillnote.app", category: "recipe-manager")
    static let retiredRecipeIds: Set<String> = [
        "draft_email",
        "devils_advocate",
        "fix_grammar",
        "release_notes",
        "merge_notes",
        "twitter_post",
        "linkedin_post",
        "brainstorm",
        "expand",
        "youtube_script"
    ]

    @AppStorage("savedRecipesJSON") private var savedRecipesJSON: String = "[]"
    @AppStorage("customRecipesJSON") private var customRecipesJSON: String = "[]"
    @AppStorage("defaultRecipesInstalled") private var defaultRecipesInstalled = false
    @AppStorage("hookRecipeInstalled") private var hookRecipeInstalled = false
    @AppStorage("captionPackRecipeInstalled") private var captionPackRecipeInstalled = false
    @AppStorage("rewriteRecipeInstalled") private var rewriteRecipeInstalled = false
    @AppStorage("repurposePackRecipeInstalled") private var repurposePackRecipeInstalled = false

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
        installHookRecipeIfNeeded()
        installCaptionPackRecipeIfNeeded()
        installRewriteRecipeIfNeeded()
        installRepurposePackRecipeIfNeeded()
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

        let defaultIDs = ["hook_generator", "caption_pack", "rewrite", "repurpose_pack"]
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

    func installHookRecipeIfNeeded() {
        guard !hookRecipeInstalled else { return }
        guard let recipe = AgentRecipe.allRecipes.first(where: { $0.id == "hook_generator" }) else { return }

        if !savedRecipeIds.contains(recipe.id) {
            addRecipe(recipe)
        }
        hookRecipeInstalled = true
    }

    func installRewriteRecipeIfNeeded() {
        guard !rewriteRecipeInstalled else { return }
        guard let recipe = AgentRecipe.allRecipes.first(where: { $0.id == "rewrite" }) else { return }

        if !savedRecipeIds.contains(recipe.id) {
            addRecipe(recipe)
        }
        rewriteRecipeInstalled = true
    }

    func installRepurposePackRecipeIfNeeded() {
        guard !repurposePackRecipeInstalled else { return }
        guard let recipe = AgentRecipe.allRecipes.first(where: { $0.id == "repurpose_pack" }) else { return }

        if !savedRecipeIds.contains(recipe.id) {
            addRecipe(recipe)
        }
        repurposePackRecipeInstalled = true
    }

    private func loadFromDisk() {
        if let data = customRecipesJSON.data(using: .utf8) {
            do {
                customRecipes = try JSONDecoder().decode([AgentRecipe].self, from: data)
            } catch {
                Self.logger.error("Failed to decode custom recipes: \(error.localizedDescription, privacy: .public)")
                customRecipes = []
            }
        } else {
            Self.logger.error("Failed to read custom recipes JSON as UTF-8")
            customRecipes = []
        }

        if let data = savedRecipesJSON.data(using: .utf8) {
            do {
                let decoded = try JSONDecoder().decode([AgentRecipe].self, from: data)
                savedRecipes = decoded.filter { !Self.retiredRecipeIds.contains($0.id) }
            } catch {
                Self.logger.error("Failed to decode saved recipes: \(error.localizedDescription, privacy: .public)")
                savedRecipes = []
                savedRecipeIds = []
            }
        } else {
            Self.logger.error("Failed to read saved recipes JSON as UTF-8")
            savedRecipes = []
            savedRecipeIds = []
        }
        savedRecipeIds = Set(savedRecipes.map { $0.id })
    }

    private func saveToDisk() {
        do {
            let encoded = try JSONEncoder().encode(savedRecipes)
            guard let jsonString = String(data: encoded, encoding: .utf8) else {
                Self.logger.error("Failed to encode saved recipes JSON as UTF-8")
                return
            }
            savedRecipesJSON = jsonString
            savedRecipeIds = Set(savedRecipes.map { $0.id })
        } catch {
            Self.logger.error("Failed to encode saved recipes: \(error.localizedDescription, privacy: .public)")
        }
    }


    private func saveCustomToDisk() {
        do {
            let encoded = try JSONEncoder().encode(customRecipes)
            guard let jsonString = String(data: encoded, encoding: .utf8) else {
                Self.logger.error("Failed to encode custom recipes JSON as UTF-8")
                return
            }
            customRecipesJSON = jsonString
        } catch {
            Self.logger.error("Failed to encode custom recipes: \(error.localizedDescription, privacy: .public)")
        }
    }
}
