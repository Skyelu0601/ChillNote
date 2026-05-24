import Foundation
import Supabase

enum ShareImportError: LocalizedError {
    case missingLink
    case missingAuthToken
    case invalidBackendURL
    case backendError(String)
    case emptyTranscript
    case sharedContainerUnavailable

    var errorDescription: String? {
        switch self {
        case .missingLink:
            return ShareL10n.text("share_extension.no_link")
        case .missingAuthToken:
            return ShareL10n.text("share_extension.sign_in_required")
        case .invalidBackendURL:
            return ShareL10n.text("share_extension.failed")
        case .backendError(let message):
            return message.isEmpty ? ShareL10n.text("share_extension.failed") : message
        case .emptyTranscript:
            return ShareL10n.text("share_extension.failed")
        case .sharedContainerUnavailable:
            return ShareL10n.text("share_extension.failed")
        }
    }
}

enum ShareImportStage {
    case readingContent
    case extractingTranscript
    case saving
    case completed

    var progress: Double {
        switch self {
        case .readingContent:
            return 0.08
        case .extractingTranscript:
            return 0.2
        case .saving:
            return 0.96
        case .completed:
            return 1.0
        }
    }

    var visualCeiling: Double {
        switch self {
        case .readingContent:
            return 0.2
        case .extractingTranscript:
            return 0.92
        case .saving:
            return 0.99
        case .completed:
            return 1.0
        }
    }

    var message: String {
        switch self {
        case .readingContent:
            return ShareL10n.text("share_extension.reading_content")
        case .extractingTranscript:
            return ShareL10n.text("share_extension.extracting_transcript")
        case .saving:
            return ShareL10n.text("share_extension.saving")
        case .completed:
            return ShareL10n.text("share_extension.saved")
        }
    }
}

struct ShareMediaTranscriptResult: Decodable {
    let available: Bool
    let text: String?
    let reason: String?
}

private struct ShareMediaLinkTranscriptSectionPreferences {
    static let descriptionStorageKey = "media_link_transcript_show_description"
    static let authorStorageKey = "media_link_transcript_show_author"
    static let hookStorageKey = "media_link_transcript_show_hook"
    static let transcriptStorageKey = "media_link_transcript_show_transcript"

    let showDescription: Bool
    let showAuthor: Bool
    let showHook: Bool
    let showTranscript: Bool

    var selectedCount: Int {
        [showDescription, showAuthor, showHook, showTranscript].filter { $0 }.count
    }

    static var all: ShareMediaLinkTranscriptSectionPreferences {
        ShareMediaLinkTranscriptSectionPreferences(
            showDescription: true,
            showAuthor: true,
            showHook: true,
            showTranscript: true
        )
    }

    static func load() -> ShareMediaLinkTranscriptSectionPreferences {
        let userDefaults = UserDefaults(suiteName: ShareConstants.appGroupIdentifier)
        let preferences = ShareMediaLinkTranscriptSectionPreferences(
            showDescription: userDefaults?.mediaLinkTranscriptSectionBool(forKey: descriptionStorageKey) ?? true,
            showAuthor: userDefaults?.mediaLinkTranscriptSectionBool(forKey: authorStorageKey) ?? true,
            showHook: userDefaults?.mediaLinkTranscriptSectionBool(forKey: hookStorageKey) ?? true,
            showTranscript: userDefaults?.mediaLinkTranscriptSectionBool(forKey: transcriptStorageKey) ?? true
        )

        return preferences.selectedCount == 0 ? .all : preferences
    }
}

private extension UserDefaults {
    func mediaLinkTranscriptSectionBool(forKey key: String) -> Bool {
        object(forKey: key) == nil ? true : bool(forKey: key)
    }
}

private struct ShareCreatorMediaMetadata {
    let title: String
    let authorName: String?
    let authorHandle: String?
}

private struct ShareOEmbedResponse: Decodable {
    let title: String?
    let authorName: String?
    let authorUniqueID: String?

    enum CodingKeys: String, CodingKey {
        case title
        case authorName = "author_name"
        case authorUniqueID = "author_unique_id"
    }
}

private struct ShareAuthTokenProvider {
    let supabase = SupabaseClient(
        supabaseURL: ShareConstants.supabaseURL,
        supabaseKey: ShareConstants.supabaseAnonKey,
        options: SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(
                storage: KeychainLocalStorage(
                    service: ShareConstants.keychainService,
                    accessGroup: ShareConstants.keychainAccessGroup
                ),
                autoRefreshToken: true
            )
        )
    )

    func sessionToken() async -> String? {
        do {
            let session = try await supabase.auth.session
            cache(session: session)
            return session.accessToken
        } catch {
            return cachedSessionToken()
        }
    }

    private func cache(session: Session) {
        let defaults = UserDefaults(suiteName: ShareConstants.appGroupIdentifier)
        defaults?.set(session.accessToken, forKey: ShareConstants.authTokenKey)
        defaults?.set(session.user.id.uuidString, forKey: ShareConstants.lastAuthenticatedUserIdKey)
    }

    private func cachedSessionToken() -> String? {
        UserDefaults(suiteName: ShareConstants.appGroupIdentifier)?
            .string(forKey: ShareConstants.authTokenKey)
    }
}

struct ShareImportService {
    let backendBaseURL = "https://api.chillnoteai.com"
    private let authTokenProvider = ShareAuthTokenProvider()

    func importSharedURL(
        _ url: URL,
        progress: @escaping @MainActor (ShareImportStage) -> Void
    ) async throws -> SharePendingImport {
        await progress(.readingContent)
        guard let token = await authToken(), !token.isEmpty else {
            throw ShareImportError.missingAuthToken
        }

        try? await Task.sleep(for: .milliseconds(1_400))
        await progress(.extractingTranscript)
        let transcript = try await transcribeMediaLink(url, token: token)
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else {
            throw ShareImportError.emptyTranscript
        }

        await progress(.saving)
        let pendingImport = await makePendingImport(url: url, transcript: trimmedTranscript)
        try save(pendingImport)
        await progress(.completed)
        return pendingImport
    }

    private func authToken() async -> String? {
        await authTokenProvider.sessionToken()
    }

    private func transcribeMediaLink(_ url: URL, token: String) async throws -> String {
        guard let endpoint = URL(string: backendBaseURL + "/ai/media-link-transcript") else {
            throw ShareImportError.invalidBackendURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["url": url.absoluteString])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ShareImportError.backendError("")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ShareImportError.backendError("Status code: \(httpResponse.statusCode)")
        }

        let result = try JSONDecoder().decode(ShareMediaTranscriptResult.self, from: data)
        guard result.available else {
            throw ShareImportError.backendError(result.reason ?? "")
        }

        return result.text ?? ""
    }

    private func makePendingImport(url: URL, transcript: String) async -> SharePendingImport {
        let platform = SharePlatformResolver.platform(for: url)
        let host = SharePlatformResolver.normalizedHost(from: url)
        let metadata = await creatorMediaMetadata(for: url, platform: platform, host: host)
        let title = metadata.title.isEmpty ? (platform.displayName.isEmpty ? host : platform.displayName) : metadata.title
        let noteText = makeCreatorMediaTranscriptNote(
            metadata: metadata,
            transcript: transcript,
            preferences: .load()
        )

        return SharePendingImport(
            id: UUID(),
            noteText: noteText,
            source: SharePendingImport.Source(
                url: url.absoluteString,
                title: title,
                platformID: platform.id,
                platformName: platform.displayName,
                host: host
            ),
            createdAt: Date()
        )
    }

    private func creatorMediaMetadata(for url: URL, platform: SharePlatform, host: String) async -> ShareCreatorMediaMetadata {
        switch platform.id {
        case "tiktok":
            for candidateURL in await tikTokMetadataCandidateURLs(for: url) {
                if let metadata = try? await fetchOEmbed(
                    endpoint: "https://www.tiktok.com/oembed",
                    url: candidateURL
                ) {
                    return ShareCreatorMediaMetadata(
                        title: sanitizedCreatorMediaTitle(metadata.title ?? platform.displayName),
                        authorName: metadata.authorName,
                        authorHandle: metadata.authorUniqueID
                    )
                }
            }
        case "youtube":
            if let metadata = try? await fetchOEmbed(
                endpoint: "https://www.youtube.com/oembed",
                url: url,
                extraQueryItems: [URLQueryItem(name: "format", value: "json")]
            ) {
                return ShareCreatorMediaMetadata(
                    title: sanitizedCreatorMediaTitle(metadata.title ?? platform.displayName),
                    authorName: metadata.authorName,
                    authorHandle: nil
                )
            }
        case "instagram":
            if let metadata = try? await fetchInstagramMetadata(for: url, fallback: platform.displayName) {
                return metadata
            }
        default:
            break
        }

        return ShareCreatorMediaMetadata(
            title: platform.displayName.isEmpty ? host : platform.displayName,
            authorName: nil,
            authorHandle: nil
        )
    }

    private func makeCreatorMediaTranscriptNote(
        metadata: ShareCreatorMediaMetadata,
        transcript: String,
        preferences: ShareMediaLinkTranscriptSectionPreferences
    ) -> String {
        let cleanedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectivePreferences = preferences.selectedCount == 0 ? .all : preferences
        var sections: [String] = []

        if effectivePreferences.showDescription {
            sections.append(markdownSection(
                heading: ShareL10n.text("quick_capture.media_link.description_heading"),
                body: metadata.title
            ))
        }

        if effectivePreferences.showAuthor {
            sections.append(markdownSection(
                heading: ShareL10n.text("quick_capture.media_link.author_label"),
                body: creatorMediaAuthorDisplayName(metadata: metadata)
            ))
        }

        if effectivePreferences.showHook {
            sections.append(markdownSection(
                heading: ShareL10n.text("quick_capture.media_link.hook_heading"),
                body: fallbackCreatorMediaHook(transcript: cleanedTranscript)
            ))
        }

        if effectivePreferences.showTranscript {
            sections.append(markdownSection(
                heading: ShareL10n.text("quick_capture.media_link.transcript_heading"),
                body: cleanedTranscript
            ))
        }

        if sections.isEmpty {
            sections.append(markdownSection(
                heading: ShareL10n.text("quick_capture.media_link.transcript_heading"),
                body: cleanedTranscript
            ))
        }

        return sections.joined(separator: "\n\n")
    }

    private func creatorMediaAuthorDisplayName(metadata: ShareCreatorMediaMetadata) -> String {
        let authorName = metadata.authorName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !authorName.isEmpty {
            return authorName
        }

        let authorHandle = metadata.authorHandle?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
            ?? ""

        return authorHandle.isEmpty ? ShareL10n.text("quick_capture.media_link.author_unknown") : authorHandle
    }

    private func fallbackCreatorMediaHook(transcript: String) -> String {
        let source = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = source
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? source

        let sentenceEndings = CharacterSet(charactersIn: ".!?。！？")
        let firstSentence = firstLine.rangeOfCharacter(from: sentenceEndings).map {
            String(firstLine[firstLine.startIndex...$0.lowerBound])
        } ?? firstLine

        let collapsed = collapseWhitespace(firstSentence)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else {
            return ShareL10n.text("quick_capture.link.summary_unavailable")
        }

        if collapsed.count <= 160 {
            return collapsed
        }

        return String(collapsed.prefix(160)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private func markdownSection(heading: String, body: String) -> String {
        """
        ## \(heading)

        \(body)
        """
    }

    private func fetchOEmbed(
        endpoint: String,
        url: URL,
        extraQueryItems: [URLQueryItem] = []
    ) async throws -> ShareOEmbedResponse {
        var components = URLComponents(string: endpoint)
        components?.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)] + extraQueryItems

        guard let oEmbedURL = components?.url else {
            throw ShareImportError.invalidBackendURL
        }

        var request = URLRequest(url: oEmbedURL)
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ShareImportError.backendError("")
        }

        return try JSONDecoder().decode(ShareOEmbedResponse.self, from: data)
    }

    private func fetchInstagramMetadata(for url: URL, fallback: String) async throws -> ShareCreatorMediaMetadata {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, _) = try await URLSession.shared.data(for: request)
        let html = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        let rawTitle = firstMetaContent(in: html, names: ["og:title", "twitter:title"])
            ?? firstMatch(in: html, pattern: #"<title[^>]*>(.*?)</title>"#)
            ?? fallback
        let components = instagramTitleComponents(htmlDecoded(rawTitle), fallback: fallback)

        return ShareCreatorMediaMetadata(
            title: components.title,
            authorName: components.authorName,
            authorHandle: instagramAuthorHandle(from: url)
        )
    }

    private func tikTokMetadataCandidateURLs(for url: URL) async -> [URL] {
        var candidates = [url]

        if isTikTokShortLink(url),
           let redirectedURL = try? await finalRedirectedURL(from: url),
           redirectedURL.absoluteString != url.absoluteString {
            candidates.append(redirectedURL)
        }

        return candidates
    }

    private func isTikTokShortLink(_ url: URL) -> Bool {
        let host = SharePlatformResolver.normalizedHost(from: url)
        return host == "vm.tiktok.com" || host == "vt.tiktok.com"
    }

    private func finalRedirectedURL(from url: URL) async throws -> URL {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )

        let (_, response) = try await URLSession.shared.data(for: request)
        return response.url ?? url
    }

    private func sanitizedCreatorMediaTitle(_ rawTitle: String) -> String {
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        let hashtagPattern = #"(?:(?<=^)|(?<=\s)|(?<=[\p{P}\p{S}]))#[^\s#]+"#
        let titleWithoutHashtags = replaceMatches(in: trimmed, pattern: hashtagPattern, with: " ")
        let cleaned = collapseWhitespace(titleWithoutHashtags)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? trimmed.replacingOccurrences(of: "#", with: "") : cleaned
    }

    private func instagramTitleComponents(_ rawTitle: String, fallback: String) -> (title: String, authorName: String?) {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let patterns = [
            #"^Instagram\s+用户\s+(.+?)\s*:\s*"(.+)"$"#,
            #"^(.+?)\s+on\s+Instagram\s*:\s*"(.+)"$"#,
            #"^(.+?)\s+on\s+Instagram:\s*(.+)$"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(title.startIndex..<title.endIndex, in: title)
            guard let match = regex.firstMatch(in: title, range: range), match.numberOfRanges >= 3,
                  let authorRange = Range(match.range(at: 1), in: title),
                  let titleRange = Range(match.range(at: 2), in: title) else { continue }

            let extractedTitle = sanitizedCreatorMediaTitle(String(title[titleRange]))
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"“”"))
            let author = String(title[authorRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (extractedTitle.isEmpty ? fallback : extractedTitle, author.isEmpty ? nil : author)
        }

        let cleaned = sanitizedCreatorMediaTitle(title)
        return (cleaned.isEmpty ? fallback : cleaned, nil)
    }

    private func instagramAuthorHandle(from url: URL) -> String? {
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard pathComponents.first?.lowercased() == "reel", pathComponents.count > 2 else {
            return nil
        }
        return pathComponents[1]
    }

    private func firstMetaContent(in html: String, names: [String]) -> String? {
        for name in names {
            let escaped = NSRegularExpression.escapedPattern(for: name)
            let patterns = [
                #"<meta[^>]+(?:property|name)=["']\#(escaped)["'][^>]+content=["']([^"']*)["'][^>]*>"#,
                #"<meta[^>]+content=["']([^"']*)["'][^>]+(?:property|name)=["']\#(escaped)["'][^>]*>"#
            ]

            for pattern in patterns {
                if let match = firstMatch(in: html, pattern: pattern, group: 1) {
                    return htmlDecoded(match)
                }
            }
        }

        return nil
    }

    private func firstMatch(in text: String, pattern: String, group: Int = 1) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > group,
              let matchRange = Range(match.range(at: group), in: text) else {
            return nil
        }
        return String(text[matchRange])
    }

    private func replaceMatches(in text: String, pattern: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }

    private func collapseWhitespace(_ text: String) -> String {
        replaceMatches(in: text, pattern: #"\s+"#, with: " ")
    }

    private func htmlDecoded(_ text: String) -> String {
        var result = text
        let entities = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#39;": "'",
            "&apos;": "'",
            "&nbsp;": " "
        ]
        for (entity, value) in entities {
            result = result.replacingOccurrences(of: entity, with: value)
        }
        return result
    }

    private func save(_ pendingImport: SharePendingImport) throws {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ShareConstants.appGroupIdentifier) else {
            throw ShareImportError.sharedContainerUnavailable
        }

        let directory = containerURL.appendingPathComponent(ShareConstants.pendingImportsDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("\(pendingImport.id.uuidString).json")
        let data = try JSONEncoder.shareImportEncoder.encode(pendingImport)
        try data.write(to: fileURL, options: .atomic)
    }
}

extension JSONEncoder {
    static var shareImportEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var shareImportDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
