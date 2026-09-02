import Foundation

enum ShareL10n {
    private static let appGroupIdentifier = "group.com.sponteoai.chillnote"
    private static let contentLocaleStorageKey = "preferred_content_locale"

    static var contentLocaleIdentifier: String {
        // A share extension has its own process. Prefer the containing app's
        // per-app language, which the main app copies into the shared group.
        UserDefaults(suiteName: appGroupIdentifier)?.string(forKey: contentLocaleStorageKey)
            ?? Locale.current.identifier
    }

    static func text(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }

    static func text(_ key: String, _ args: CVarArg...) -> String {
        let format = text(key)
        return String(format: format, locale: Locale.current, arguments: args)
    }
}
