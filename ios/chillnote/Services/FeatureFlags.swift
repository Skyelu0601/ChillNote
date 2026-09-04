import Foundation

enum FeatureFlags {
    private static let defaults = UserDefaults.standard

    static var useLocalFTSSearch: Bool {
        defaults.object(forKey: "useLocalFTSSearch") as? Bool ?? true
    }

}
