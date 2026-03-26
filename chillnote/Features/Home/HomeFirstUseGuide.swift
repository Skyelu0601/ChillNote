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
