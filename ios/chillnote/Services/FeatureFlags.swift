import Foundation

enum FeatureFlags {
    private static let defaults = UserDefaults.standard

    static var usePagedHomeFeed: Bool {
        defaults.object(forKey: "usePagedHomeFeed") as? Bool ?? true
    }

    static var useLocalFTSSearch: Bool {
        defaults.object(forKey: "useLocalFTSSearch") as? Bool ?? true
    }

    static var usePlainPreviewInList: Bool {
        defaults.object(forKey: "usePlainPreviewInList") as? Bool ?? true
    }


}
