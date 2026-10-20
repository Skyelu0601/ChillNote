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
        "timed_script",
        "youtube_script"
    ]

    @AppStorage("customRecipesJSON") private var customRecipesJSON: String = "[]"
    @AppStorage("favoriteSkillIDsJSON") private var favoriteSkillIDsJSON = ""
    @Published private(set) var favoriteSkillIDs: [String] = []
    static let defaultFavoriteIDs = ["rewrite", "hook_generator", "caption_pack", "repurpose_pack"]

    var favoriteRecipes: [AgentRecipe] {
        favoriteSkillIDs.compactMap { id in savedRecipes.first { $0.id == id } }
    }

    var savedRecipes: [AgentRecipe] {
        AgentRecipe.allRecipes.filter { !Self.retiredRecipeIds.contains($0.id) } + customRecipes
    }
    @Published private(set) var customRecipes: [AgentRecipe] = [] {
        didSet { saveCustomToDisk() }
    }

    init(userDefaults: UserDefaults = .standard) {
        _customRecipesJSON = AppStorage(wrappedValue: "[]", "customRecipesJSON", store: userDefaults)
        _favoriteSkillIDsJSON = AppStorage(wrappedValue: "", "favoriteSkillIDsJSON", store: userDefaults)
        loadCustomFromDisk()
        favoriteSkillIDs = favoriteSkillIDsJSON.isEmpty
            ? Self.defaultFavoriteIDs
            : (favoriteSkillIDsJSON.data(using: .utf8).flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? Self.defaultFavoriteIDs)
        persistFavorites()
    }

    func toggleRecipe(_ recipe: AgentRecipe) {
        if isAdded(recipe) {
            guard favoriteSkillIDs.count > 1 else { return }
            favoriteSkillIDs.removeAll { $0 == recipe.id }
        } else if favoriteSkillIDs.count < 4 {
            favoriteSkillIDs.append(recipe.id)
        }
        persistFavorites()
    }

    func replaceFavorite(_ old: AgentRecipe, with recipe: AgentRecipe) {
        guard !isAdded(recipe), let index = favoriteSkillIDs.firstIndex(of: old.id) else { return }
        favoriteSkillIDs[index] = recipe.id
        persistFavorites()
    }

    func isAdded(_ recipe: AgentRecipe) -> Bool {
        favoriteSkillIDs.contains(recipe.id)
    }

    private func persistFavorites() {
        let validIDs = Set(savedRecipes.map(\.id))
        var seen = Set<String>()
        favoriteSkillIDs = Array(favoriteSkillIDs.filter { validIDs.contains($0) && seen.insert($0).inserted }.prefix(4))
        if favoriteSkillIDs.isEmpty, let fallback = Self.defaultFavoriteIDs.first(where: { validIDs.contains($0) }) {
            favoriteSkillIDs = [fallback]
        }
        if let data = try? JSONEncoder().encode(favoriteSkillIDs), let json = String(data: data, encoding: .utf8) {
            favoriteSkillIDsJSON = json
        }
    }

    func addCustomRecipe(name: String, systemIcon: String, prompt: String) -> AgentRecipe {
        let recipe = AgentRecipe(
            id: "custom_\(UUID().uuidString)",
            systemIcon: systemIcon,
            name: name,
            description: L10n.text("recipes.custom_skill"),
            prompt: prompt,
            isCustom: true
        )
        customRecipes.append(recipe)
        return recipe
    }

    func deleteCustomRecipe(_ recipe: AgentRecipe) {
        customRecipes.removeAll { $0.id == recipe.id }
        favoriteSkillIDs.removeAll { $0 == recipe.id }
        persistFavorites()
    }

    private func loadCustomFromDisk() {
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
