import Foundation

enum ShareL10n {
    static func text(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }

    static func text(_ key: String, _ args: CVarArg...) -> String {
        let format = text(key)
        return String(format: format, locale: Locale.current, arguments: args)
    }
}
