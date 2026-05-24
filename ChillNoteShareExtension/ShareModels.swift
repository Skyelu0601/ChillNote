import Foundation

enum ShareConstants {
    static let appGroupIdentifier = "group.com.sponteoai.chillnote"
    static let authTokenKey = "syncAuthToken"
    static let lastAuthenticatedUserIdKey = "auth.lastAuthenticatedUserId"
    static let pendingImportsDirectoryName = "PendingShareImports"
    static let keychainAccessGroup = "Y6A6D9322M.com.sponteoai.chillnote.auth"
    static let keychainService = "supabase.gotrue.swift"
    static let supabaseURL = URL(string: "https://qsyhkpaeyzhjojdvbntq.supabase.co")!
    static let supabaseAnonKey = "sb_publishable_smWWadjejdbKYvmg3fidsg_41XPu70e"
}

struct SharePendingImport: Codable, Sendable {
    struct Source: Codable, Sendable {
        let url: String
        let title: String
        let platformID: String
        let platformName: String
        let host: String
    }

    let id: UUID
    let noteText: String
    let source: Source
    let createdAt: Date
}

struct SharePlatform: Equatable, Sendable {
    let id: String
    let displayName: String
}

enum SharePlatformResolver {
    static func platform(for url: URL) -> SharePlatform {
        let host = normalizedHost(from: url)

        if host.matchesAnyDomain(["youtube.com", "youtu.be", "youtube-nocookie.com"]) {
            return SharePlatform(id: "youtube", displayName: "YouTube")
        }
        if host.matchesAnyDomain(["tiktok.com", "vm.tiktok.com", "vt.tiktok.com"]) {
            return SharePlatform(id: "tiktok", displayName: "TikTok")
        }
        if host.matchesAnyDomain(["instagram.com"]) {
            return SharePlatform(id: "instagram", displayName: "Instagram Reels")
        }

        return SharePlatform(id: "web", displayName: displayHost(from: host))
    }

    static func normalizedHost(from url: URL) -> String {
        let host = url.host(percentEncoded: false) ?? ""
        if host.hasPrefix("www.") {
            return String(host.dropFirst(4)).lowercased()
        }
        return host.lowercased()
    }

    static func displayHost(from host: String) -> String {
        if host.hasPrefix("www.") {
            return String(host.dropFirst(4))
        }
        return host
    }
}

private extension String {
    func matchesAnyDomain(_ domains: [String]) -> Bool {
        domains.contains { domain in
            self == domain || self.hasSuffix(".\(domain)")
        }
    }
}

enum ShareLinkParser {
    static func extractWebURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = makeWebURL(from: trimmed) {
            return url
        }

        return firstRegexURL(in: trimmed)
    }

    private static let inlineWebURLRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)(https?://[^\s<>"'“”‘’]+|www\.[^\s<>"'“”‘’]+)"#
    )

    private static let bareDomainRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+(?:\:\d{2,5})?(?:/[^\s<>"'“”‘’]*)?$"#
    )

    private static let edgeTrimCharacters = CharacterSet.whitespacesAndNewlines.union(
        CharacterSet(charactersIn: "<>[]{}()\"'“”‘’`.,;:!?，。；：！？、")
    )

    private static func firstRegexURL(in text: String) -> URL? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = inlineWebURLRegex?.matches(in: text, options: [], range: range) ?? []

        for match in matches {
            guard let matchRange = Range(match.range, in: text) else { continue }
            let candidate = String(text[matchRange])
            if let webURL = makeWebURL(from: candidate) {
                return webURL
            }
        }

        return nil
    }

    private static func makeWebURL(from candidate: String) -> URL? {
        let cleaned = candidate
            .replacingOccurrences(of: "\u{200B}", with: "")
            .trimmingCharacters(in: edgeTrimCharacters)

        guard !cleaned.isEmpty else { return nil }

        let stringWithScheme: String
        if cleaned.range(of: #"(?i)^https?://"#, options: .regularExpression) != nil {
            stringWithScheme = cleaned.replacingOccurrences(
                of: #"(?i)^http://"#,
                with: "https://",
                options: .regularExpression
            )
        } else if cleaned.range(of: #"(?i)^www\."#, options: .regularExpression) != nil || isBareDomain(cleaned) {
            stringWithScheme = "https://\(cleaned)"
        } else {
            return nil
        }

        guard let url = URL(string: stringWithScheme),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host(percentEncoded: false)?.isEmpty == false else {
            return nil
        }

        return url
    }

    private static func isBareDomain(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return bareDomainRegex?.firstMatch(in: text, options: [], range: range) != nil
    }
}
