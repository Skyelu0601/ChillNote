import Foundation

struct OnboardingStateStore {
    private static let completedGlobalKey = "onboarding.hasCompleted"
    private static let completedPerUserKey = "onboarding.completedByUserId"
    private static let paywallGlobalKey = "onboarding.hasShownIntroPaywall"
    private static let paywallPerUserKey = "onboarding.introPaywallShownByUserId"

    static func hasCompleted(for userId: String?) -> Bool {
        value(for: userId, perUserKey: completedPerUserKey, globalKey: completedGlobalKey)
    }

    static func setHasCompleted(_ value: Bool, for userId: String?) {
        setValue(value, for: userId, perUserKey: completedPerUserKey, globalKey: completedGlobalKey)
    }

    static func hasShownIntroPaywall(for userId: String?) -> Bool {
        value(for: userId, perUserKey: paywallPerUserKey, globalKey: paywallGlobalKey)
    }

    static func setHasShownIntroPaywall(_ value: Bool, for userId: String?) {
        setValue(value, for: userId, perUserKey: paywallPerUserKey, globalKey: paywallGlobalKey)
    }

    private static func value(for userId: String?, perUserKey: String, globalKey: String) -> Bool {
        let defaults = UserDefaults.standard

        if let userId,
           let map = defaults.dictionary(forKey: perUserKey) as? [String: Bool],
           let value = map[userId] {
            return value
        }

        if userId != nil {
            return false
        }

        return defaults.bool(forKey: globalKey)
    }

    private static func setValue(_ value: Bool, for userId: String?, perUserKey: String, globalKey: String) {
        let defaults = UserDefaults.standard

        if let userId {
            var map = defaults.dictionary(forKey: perUserKey) as? [String: Bool] ?? [:]
            map[userId] = value
            defaults.set(map, forKey: perUserKey)
        }

        defaults.set(value, forKey: globalKey)
    }
}
