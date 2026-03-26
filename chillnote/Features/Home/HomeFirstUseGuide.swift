import Foundation

enum HomeFirstUseGuideStep: String {
    case recordFirstNote
    case openSelection
    case addSkill
    case runSkill
    case completed

    var isActive: Bool {
        self != .completed
    }
}

enum HomeFirstUseGuideStorage {
    static let stepKey = "home.firstUseGuide.step"
    static let targetNoteIDKey = "home.firstUseGuide.targetNoteID"
    static let highlightedRecipeIDKey = "home.firstUseGuide.highlightedRecipeID"
}

struct HomeFirstUseGuideState {
    var stepRawValue: String = HomeFirstUseGuideStep.recordFirstNote.rawValue
    var targetNoteID: String = ""
    var highlightedRecipeID: String = ""
}

enum HomeFirstUseGuideStore {
    private static let defaults = UserDefaults.standard

    static func load(for userId: String?) -> HomeFirstUseGuideState {
        guard let userId, !userId.isEmpty else {
            return HomeFirstUseGuideState()
        }

        return HomeFirstUseGuideState(
            stepRawValue: defaults.string(forKey: scopedKey(HomeFirstUseGuideStorage.stepKey, userId: userId))
                ?? HomeFirstUseGuideStep.recordFirstNote.rawValue,
            targetNoteID: defaults.string(forKey: scopedKey(HomeFirstUseGuideStorage.targetNoteIDKey, userId: userId))
                ?? "",
            highlightedRecipeID: defaults.string(forKey: scopedKey(HomeFirstUseGuideStorage.highlightedRecipeIDKey, userId: userId))
                ?? ""
        )
    }

    static func save(_ state: HomeFirstUseGuideState, for userId: String?) {
        guard let userId, !userId.isEmpty else { return }

        defaults.set(state.stepRawValue, forKey: scopedKey(HomeFirstUseGuideStorage.stepKey, userId: userId))
        defaults.set(state.targetNoteID, forKey: scopedKey(HomeFirstUseGuideStorage.targetNoteIDKey, userId: userId))
        defaults.set(state.highlightedRecipeID, forKey: scopedKey(HomeFirstUseGuideStorage.highlightedRecipeIDKey, userId: userId))
    }

    private static func scopedKey(_ baseKey: String, userId: String) -> String {
        "\(baseKey).\(userId)"
    }
}
