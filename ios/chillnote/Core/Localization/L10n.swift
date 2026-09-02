import Foundation

enum L10n {
    static let contentLocaleStorageKey = "preferred_content_locale"

    static var contentLocaleIdentifier: String {
        // Locale.current explicitly includes the per-app language selected in
        // Settings > Apps > ChillScript > Preferred Language. Without an
        // override, it naturally falls back to the device language/region.
        Locale.current.identifier
    }

    static func text(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    static func text(_ key: String, _ args: CVarArg...) -> String {
        let format = NSLocalizedString(key, comment: "")
        return String(format: format, locale: Locale.current, arguments: args)
    }

    static func weeklyTopicsSummary(topicCount: Int, sourceCount: Int) -> String {
        let topics = text("weekly_topics.count.topics", Int64(topicCount))
        let sources = text("weekly_topics.count.sources", Int64(sourceCount))
        return text("weekly_topics.summary", topics, sources)
    }
}
