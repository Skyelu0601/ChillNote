import Foundation

struct AppConfig {
    private static func nonEmptyString(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func stringConfig(_ key: String) -> String? {
        if let env = nonEmptyString(ProcessInfo.processInfo.environment[key]) {
            return env
        }
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            return nonEmptyString(plistValue)
        }
        return nil
    }

    private static func boolConfig(_ key: String, defaultValue: Bool = false) -> Bool {
        if let envRaw = nonEmptyString(ProcessInfo.processInfo.environment[key])?.lowercased() {
            return ["1", "true", "yes", "y"].contains(envRaw)
        }
        if let plistBool = Bundle.main.object(forInfoDictionaryKey: key) as? Bool {
            return plistBool
        }
        if let plistString = nonEmptyString(Bundle.main.object(forInfoDictionaryKey: key) as? String)?.lowercased() {
            return ["1", "true", "yes", "y"].contains(plistString)
        }
        return defaultValue
    }

    static let backendBaseURL: String = {
        if let env = ProcessInfo.processInfo.environment["BACKEND_BASE_URL"], !env.isEmpty {
            return env
        }
        return "https://api.chillnoteai.com"
    }()
    
    // Supabase Configuration
    static let supabaseURL = URL(string: "https://qsyhkpaeyzhjojdvbntq.supabase.co")!
    // TODO: Replace with your actual Anon Key from Supabase Dashboard -> Settings -> API
    static let supabaseAnonKey = "sb_publishable_smWWadjejdbKYvmg3fidsg_41XPu70e" 
    
    static var isAIEnabled: Bool {
        return !backendBaseURL.isEmpty
    }

    // MARK: - App Review Login

    static let appReviewWhitelistEmails: [String] = {
        guard let raw = stringConfig("APP_REVIEW_WHITELIST_EMAILS") else { return [] }
        var seen = Set<String>()
        var result: [String] = []
        for item in raw.split(separator: ",") {
            let normalized = item.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !normalized.isEmpty && !seen.contains(normalized) {
                seen.insert(normalized)
                result.append(normalized)
            }
        }
        return result
    }()

    static let appReviewVerificationCode: String = stringConfig("APP_REVIEW_VERIFICATION_CODE") ?? ""

    static var appReviewPrimaryEmail: String? {
        appReviewWhitelistEmails.first
    }

    static var isAppReviewQuickLoginEnabled: Bool {
        boolConfig("APP_REVIEW_LOGIN_ENABLED", defaultValue: false)
            && !appReviewWhitelistEmails.isEmpty
            && !appReviewVerificationCode.isEmpty
    }
}
