import Foundation

struct NoteSourcePlatform: Equatable, Sendable {
    let id: String
    let displayName: String
}

enum NoteSourcePlatformResolver {
    static func platform(for url: URL) -> NoteSourcePlatform {
        let host = normalizedHost(from: url)

        if host.matchesAnyDomain(["xiaohongshu.com", "xhslink.com"]) {
            return NoteSourcePlatform(id: "xiaohongshu", displayName: "小红书")
        }
        if host.matchesAnyDomain(["youtube.com", "youtu.be", "youtube-nocookie.com"]) {
            return NoteSourcePlatform(id: "youtube", displayName: "YouTube")
        }
        if host.matchesAnyDomain(["tiktok.com", "vm.tiktok.com", "vt.tiktok.com"]) {
            return NoteSourcePlatform(id: "tiktok", displayName: "TikTok")
        }
        if host.matchesAnyDomain(["instagram.com"]) {
            return NoteSourcePlatform(id: "instagram", displayName: "Instagram")
        }
        if host.matchesAnyDomain(["threads.net"]) {
            return NoteSourcePlatform(id: "threads", displayName: "Threads")
        }
        if host.matchesAnyDomain(["x.com", "twitter.com", "t.co"]) {
            return NoteSourcePlatform(id: "x", displayName: "X")
        }
        if host.matchesAnyDomain(["medium.com"]) {
            return NoteSourcePlatform(id: "medium", displayName: "Medium")
        }
        if host.matchesAnyDomain(["substack.com"]) {
            return NoteSourcePlatform(id: "substack", displayName: "Substack")
        }
        if host.matchesAnyDomain(["reddit.com", "redd.it"]) {
            return NoteSourcePlatform(id: "reddit", displayName: "Reddit")
        }
        if host.matchesAnyDomain(["pinterest.com", "pin.it"]) {
            return NoteSourcePlatform(id: "pinterest", displayName: "Pinterest")
        }
        if host.matchesAnyDomain(["linkedin.com", "lnkd.in"]) {
            return NoteSourcePlatform(id: "linkedin", displayName: "LinkedIn")
        }
        if host.matchesAnyDomain(["facebook.com", "fb.com", "fb.watch"]) {
            return NoteSourcePlatform(id: "facebook", displayName: "Facebook")
        }
        if host.matchesAnyDomain(["vimeo.com"]) {
            return NoteSourcePlatform(id: "vimeo", displayName: "Vimeo")
        }
        if host.matchesAnyDomain(["twitch.tv"]) {
            return NoteSourcePlatform(id: "twitch", displayName: "Twitch")
        }
        if host.matchesAnyDomain(["producthunt.com"]) {
            return NoteSourcePlatform(id: "product_hunt", displayName: "Product Hunt")
        }
        if host.matchesAnyDomain(["news.ycombinator.com"]) {
            return NoteSourcePlatform(id: "hacker_news", displayName: "Hacker News")
        }
        if host.matchesAnyDomain(["bilibili.com", "b23.tv"]) {
            return NoteSourcePlatform(id: "bilibili", displayName: "Bilibili")
        }
        if host.matchesAnyDomain(["spotify.com", "open.spotify.com"]) {
            return NoteSourcePlatform(id: "spotify", displayName: "Spotify")
        }
        if host.matchesAnyDomain(["podcasts.apple.com"]) {
            return NoteSourcePlatform(id: "apple_podcasts", displayName: "Apple Podcasts")
        }

        return NoteSourcePlatform(id: "web", displayName: displayHost(from: host))
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
