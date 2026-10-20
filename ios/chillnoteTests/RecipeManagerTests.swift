import XCTest
@testable import chillnote

@MainActor
final class RecipeManagerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        suiteName = "recipe-manager-tests-" + UUID().uuidString
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testCustomSkillAppearsOnceAndSurvivesReopening() {
        let manager = RecipeManager(userDefaults: defaults)
        let custom = manager.addCustomRecipe(name: "My skill", systemIcon: "star", prompt: "My instructions")
        XCTAssertEqual(manager.savedRecipes.filter { $0.id == custom.id }, [custom])
        XCTAssertFalse(manager.favoriteRecipes.contains(custom))
        let reopened = RecipeManager(userDefaults: defaults)
        XCTAssertEqual(reopened.customRecipes, [custom])
        XCTAssertEqual(reopened.savedRecipes.filter { $0.id == custom.id }, [custom])
        XCTAssertFalse(reopened.savedRecipes.contains { RecipeManager.retiredRecipeIds.contains($0.id) })
    }

    func testFavoriteReplacementAndCustomDeletionPersist() throws {
        let manager = RecipeManager(userDefaults: defaults)
        let custom = manager.addCustomRecipe(name: "My skill", systemIcon: "star", prompt: "My instructions")
        let old = try XCTUnwrap(manager.favoriteRecipes.first)
        manager.replaceFavorite(old, with: custom)
        XCTAssertEqual(manager.favoriteRecipes.first, custom)
        XCTAssertEqual(RecipeManager(userDefaults: defaults).favoriteRecipes, manager.favoriteRecipes)
        manager.deleteCustomRecipe(custom)
        let reopened = RecipeManager(userDefaults: defaults)
        XCTAssertFalse(reopened.savedRecipes.contains(custom))
        XCTAssertFalse(reopened.favoriteRecipes.contains(custom))
        XCTAssertEqual(reopened.favoriteRecipes, manager.favoriteRecipes)
        XCTAssertFalse(reopened.favoriteRecipes.isEmpty)
    }

    func testObsoleteLibraryCacheCannotOverrideCurrentSkillsOrFavorites() throws {
        defaults.set("invalid obsolete cache", forKey: "savedRecipesJSON")
        defaults.set("[\"timed_script\",\"title_thumbnail\",\"title_thumbnail\",\"missing\"]", forKey: "favoriteSkillIDsJSON")
        let manager = RecipeManager(userDefaults: defaults)
        XCTAssertEqual(manager.favoriteSkillIDs, ["title_thumbnail"])
        XCTAssertEqual(manager.savedRecipes.count, AgentRecipe.allRecipes.count)
        XCTAssertEqual(defaults.string(forKey: "savedRecipesJSON"), "invalid obsolete cache")
    }
}
