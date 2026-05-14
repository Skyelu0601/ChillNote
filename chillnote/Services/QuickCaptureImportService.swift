import Foundation
import UIKit

enum QuickCaptureLinkParser {
    static func extractWebURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = makeWebURL(from: trimmed) {
            return url
        }

        if let detectedURL = firstDataDetectorURL(in: trimmed) {
            return detectedURL
        }

        return firstRegexURL(in: trimmed)
    }
}

enum QuickCaptureImportError: LocalizedError {
    case invalidURL
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return L10n.text("quick_capture.error.no_link")
        case .emptyContent:
            return L10n.text("quick_capture.error.link_empty")
        }
    }
}

struct MediaLinkTranscriptSectionPreferences: Equatable {
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

    static var all: MediaLinkTranscriptSectionPreferences {
        MediaLinkTranscriptSectionPreferences(
            showDescription: true,
            showAuthor: true,
            showHook: true,
            showTranscript: true
        )
    }

    static func load(from userDefaults: UserDefaults = .standard) -> MediaLinkTranscriptSectionPreferences {
        let preferences = MediaLinkTranscriptSectionPreferences(
            showDescription: userDefaults.mediaLinkTranscriptSectionBool(forKey: descriptionStorageKey),
            showAuthor: userDefaults.mediaLinkTranscriptSectionBool(forKey: authorStorageKey),
            showHook: userDefaults.mediaLinkTranscriptSectionBool(forKey: hookStorageKey),
            showTranscript: userDefaults.mediaLinkTranscriptSectionBool(forKey: transcriptStorageKey)
        )

        return preferences.selectedCount == 0 ? .all : preferences
    }
}

private extension UserDefaults {
    func mediaLinkTranscriptSectionBool(forKey key: String) -> Bool {
        object(forKey: key) == nil ? true : bool(forKey: key)
    }
}

private extension QuickCaptureLinkParser {
    static let linkDetector: NSDataDetector? = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    static let inlineWebURLRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)(https?://[^\s<>"'“”‘’]+|www\.[^\s<>"'“”‘’]+)"#
    )

    static let bareDomainRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+(?:\:\d{2,5})?(?:/[^\s<>"'“”‘’]*)?$"#
    )

    static let edgeTrimCharacters = CharacterSet.whitespacesAndNewlines.union(
        CharacterSet(charactersIn: "<>[]{}()\"'“”‘’`.,;:!?，。；：！？、")
    )

    static func firstDataDetectorURL(in text: String) -> URL? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = linkDetector?.matches(in: text, options: [], range: range) ?? []

        for match in matches {
            if let url = match.url, let webURL = makeWebURL(from: url.absoluteString) {
                return webURL
            }

            guard let matchRange = Range(match.range, in: text) else { continue }
            let candidate = String(text[matchRange])
            if let webURL = makeWebURL(from: candidate) {
                return webURL
            }
        }

        return nil
    }

    static func firstRegexURL(in text: String) -> URL? {
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

    static func makeWebURL(from candidate: String) -> URL? {
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

    static func isBareDomain(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return bareDomainRegex?.firstMatch(in: text, options: [], range: range) != nil
    }
}

struct QuickCaptureImportService {
    static let shared = QuickCaptureImportService()

    struct LinkImportResult: Equatable, Sendable {
        let noteText: String
        let source: NoteSourceMetadata
    }

    enum LinkImportPhase: Sendable {
        case resolvingSource
        case fetchingContent
        case extractingContent
        case organizingNote
        case finalizing
    }

    func importWebLink(_ url: URL) async throws -> LinkImportResult {
        try await importWebLink(url) { _ in }
    }

    func importWebLink(
        _ url: URL,
        onProgress: @escaping @Sendable (LinkImportPhase) async -> Void
    ) async throws -> LinkImportResult {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            throw QuickCaptureImportError.invalidURL
        }

        await onProgress(.resolvingSource)
        let platformID = NoteSourcePlatformResolver.platform(for: url).id
        if ["tiktok", "youtube", "instagram"].contains(platformID),
           let result = await importCreatorMediaLink(url, platformID: platformID) {
            await onProgress(.finalizing)
            return result
        }

        let fetched: FetchedWebContent
        do {
            await onProgress(.fetchingContent)
            fetched = try await fetchWebContent(from: url)
        } catch {
            let source = makeSourceMetadata(url: url, extracted: .empty(for: url))
            await onProgress(.finalizing)
            return LinkImportResult(
                noteText: makeSourceOnlyLinkNote(source: source),
                source: source
            )
        }

        await onProgress(.extractingContent)
        let extracted = extractReadableContent(from: fetched.html, url: url)
        let fallback = makeFallbackLinkNote(extracted: extracted, url: url)
        let source = makeSourceMetadata(url: url, extracted: extracted)

        guard !fallback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await onProgress(.finalizing)
            return LinkImportResult(
                noteText: makeSourceOnlyLinkNote(source: source),
                source: source
            )
        }

        do {
            await onProgress(.organizingNote)
            let noteText = try await makeAIOrganizedLinkNote(url: url, extracted: extracted, fallback: fallback)
            await onProgress(.finalizing)
            return LinkImportResult(noteText: noteText, source: source)
        } catch {
            await onProgress(.finalizing)
            return LinkImportResult(noteText: fallback, source: source)
        }
    }

    func makeImageTextNote(_ text: String) async -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = """
        # Image Capture

        ## Extracted Text

        \(trimmed)
        """

        guard !trimmed.isEmpty else { return fallback }

        do {
            let prompt = """
            Turn this OCR result into a clean, useful quick-capture note.

            Rules:
            - Preserve the original meaning.
            - Do not invent facts.
            - Fix obvious OCR line-break noise only when safe.
            - Use concise Markdown.
            - Include a short title if one is obvious.
            - Keep the extracted text available.

            OCR text:
            \(trimmed.prefix(12_000))
            """

            let systemInstruction = """
            You organize captured image text for a personal quick-capture notes app.
            Return only Markdown. Do not explain your work.
            """

            let organized = try await GeminiService.shared.generateContent(
                prompt: prompt,
                systemInstruction: systemInstruction,
                countUsage: false
            )
            let result = organized.trimmingCharacters(in: .whitespacesAndNewlines)
            return result.isEmpty ? fallback : result
        } catch {
            return fallback
        }
    }

    func makeMediaTranscriptNote(fileName: String, transcript: String) async throws -> String {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw QuickCaptureImportError.emptyContent
        }

        let safeFileName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackTitle = safeFileName.isEmpty ? "Imported Media" : safeFileName
        let fallback = """
        # \(fallbackTitle)

        ## Transcript

        \(trimmed)
        """

        do {
            let prompt = """
            Turn this imported audio/video transcript into a useful ChillNote note.

            Source file:
            \(fallbackTitle)

            Transcript:
            \(trimmed.prefix(30_000))
            """

            let systemInstruction = """
            You organize imported audio/video transcripts for a personal notes app.
            Return only Markdown.

            Rules:
            - Preserve the transcript's original language. Do not translate unless the transcript asks for translation.
            - Start with a concise title.
            - Add a short summary when the transcript has enough substance.
            - Capture key points and action items when present.
            - Do not invent facts, dates, names, decisions, or tasks.
            - Include a "Transcript" section with a polished transcript, not the raw transcript.
            - In the polished transcript, remove filler words, false starts, repeated fragments, and obvious speech-to-text noise.
            - Keep the speaker's meaning, order, names, numbers, and concrete details intact.
            - If the transcript is very short, keep the note simple.
            """

            let organized = try await GeminiService.shared.generateContent(
                prompt: prompt,
                systemInstruction: systemInstruction,
                countUsage: false
            )
            let result = organized.trimmingCharacters(in: .whitespacesAndNewlines)
            return result.isEmpty ? fallback : result
        } catch {
            return fallback
        }
    }
}

extension QuickCaptureImportService {
    struct FetchedWebContent {
        let html: String
        let contentType: String?
    }

    struct ExtractedWebContent {
        let title: String
        let description: String
        let siteName: String
        let text: String

        static func empty(for url: URL) -> ExtractedWebContent {
            ExtractedWebContent(
                title: url.host(percentEncoded: false) ?? url.absoluteString,
                description: "",
                siteName: "",
                text: ""
            )
        }
    }

    struct TikTokOEmbedResponse: Decodable {
        let title: String?
        let authorName: String?
        let authorURL: String?
        let authorUniqueID: String?

        enum CodingKeys: String, CodingKey {
            case title
            case authorName = "author_name"
            case authorURL = "author_url"
            case authorUniqueID = "author_unique_id"
        }
    }

    struct CreatorMediaMetadata {
        let title: String
        let authorName: String?
        let authorURL: String?
        let authorHandle: String?
    }

    func importCreatorMediaLink(_ url: URL, platformID: String) async -> LinkImportResult? {
        switch platformID {
        case "tiktok":
            return await importTikTokLink(url)
        case "youtube":
            return await importYouTubeLink(url)
        case "instagram":
            return await importInstagramLink(url)
        default:
            return nil
        }
    }

    func importTikTokLink(_ url: URL) async -> LinkImportResult? {
        let candidateURLs = await tikTokMetadataCandidateURLs(for: url)

        for candidateURL in candidateURLs {
            guard let metadata = try? await fetchTikTokOEmbed(for: candidateURL) else { continue }

            let title = metadata.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let sourceTitle = sanitizedCreatorMediaTitle(
                title.isEmpty ? NoteSourcePlatformResolver.platform(for: url).displayName : title
            )
            let source = NoteSourceMetadata(
                url: url.absoluteString,
                title: sourceTitle,
                platformID: "tiktok",
                platformName: NoteSourcePlatformResolver.platform(for: url).displayName,
                host: NoteSourcePlatformResolver.normalizedHost(from: url)
            )

            let creatorMetadata = CreatorMediaMetadata(
                title: sourceTitle,
                authorName: metadata.authorName,
                authorURL: metadata.authorURL,
                authorHandle: metadata.authorUniqueID
            )

            if let transcript = await fetchCreatorMediaTranscript(for: candidateURL),
               !transcript.isEmpty {
                return LinkImportResult(
                    noteText: await makeCreatorMediaTranscriptNote(
                        metadata: creatorMetadata,
                        transcript: transcript
                    ),
                    source: source
                )
            }

            return LinkImportResult(
                noteText: makeCreatorMediaLinkNote(metadata: creatorMetadata),
                source: source
            )
        }

        return nil
    }

    func importYouTubeLink(_ url: URL) async -> LinkImportResult? {
        let metadata = try? await fetchYouTubeOEmbed(for: url)
        let title = metadata?.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let sourceTitle = sanitizedCreatorMediaTitle(
            title.isEmpty ? NoteSourcePlatformResolver.platform(for: url).displayName : title
        )
        let source = NoteSourceMetadata(
            url: url.absoluteString,
            title: sourceTitle,
            platformID: "youtube",
            platformName: NoteSourcePlatformResolver.platform(for: url).displayName,
            host: NoteSourcePlatformResolver.normalizedHost(from: url)
        )
        let creatorMetadata = CreatorMediaMetadata(
            title: sourceTitle,
            authorName: metadata?.authorName,
            authorURL: metadata?.authorURL,
            authorHandle: nil
        )

        if let transcript = await fetchCreatorMediaTranscript(for: url),
           !transcript.isEmpty {
            return LinkImportResult(
                noteText: await makeCreatorMediaTranscriptNote(
                    metadata: creatorMetadata,
                    transcript: transcript
                ),
                source: source
            )
        }

        return LinkImportResult(
            noteText: makeCreatorMediaLinkNote(metadata: creatorMetadata),
            source: source
        )
    }

    func importInstagramLink(_ url: URL) async -> LinkImportResult? {
        let creatorMetadata = (try? await fetchInstagramMetadata(for: url)) ?? CreatorMediaMetadata(
            title: NoteSourcePlatformResolver.platform(for: url).displayName,
            authorName: nil,
            authorURL: nil,
            authorHandle: nil
        )

        let source = NoteSourceMetadata(
            url: url.absoluteString,
            title: creatorMetadata.title,
            platformID: "instagram",
            platformName: NoteSourcePlatformResolver.platform(for: url).displayName,
            host: NoteSourcePlatformResolver.normalizedHost(from: url)
        )

        if let transcript = await fetchCreatorMediaTranscript(for: url),
           !transcript.isEmpty {
            return LinkImportResult(
                noteText: await makeCreatorMediaTranscriptNote(
                    metadata: creatorMetadata,
                    transcript: transcript
                ),
                source: source
            )
        }

        return LinkImportResult(
            noteText: makeCreatorMediaLinkNote(metadata: creatorMetadata),
            source: source
        )
    }

    func sanitizedCreatorMediaTitle(_ rawTitle: String) -> String {
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        let hashtagPattern = #"(?:(?<=^)|(?<=\s)|(?<=[\p{P}\p{S}]))#[^\s#]+"#
        let titleWithoutHashtags = replaceMatches(in: trimmed, pattern: hashtagPattern, with: " ")
        let cleaned = collapseWhitespace(titleWithoutHashtags)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? trimmed.replacingOccurrences(of: "#", with: "") : cleaned
    }

    func sanitizedTikTokTitle(_ rawTitle: String) -> String {
        sanitizedCreatorMediaTitle(rawTitle)
    }

    func fetchCreatorMediaTranscript(for url: URL) async -> String? {
        do {
            let result = try await GeminiService.shared.transcribeMediaLink(url)
            guard result.available else { return nil }
            return result.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    func tikTokMetadataCandidateURLs(for url: URL) async -> [URL] {
        var candidates = [url]

        if isTikTokShortLink(url),
           let redirectedURL = try? await finalRedirectedURL(from: url),
           redirectedURL.absoluteString != url.absoluteString {
            candidates.append(redirectedURL)
        }

        return candidates
    }

    func isTikTokShortLink(_ url: URL) -> Bool {
        let host = NoteSourcePlatformResolver.normalizedHost(from: url)
        return host == "vm.tiktok.com" || host == "vt.tiktok.com"
    }

    func finalRedirectedURL(from url: URL) async throws -> URL {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )

        let (_, response) = try await URLSession.shared.data(for: request)
        return response.url ?? url
    }

    func fetchTikTokOEmbed(for url: URL) async throws -> TikTokOEmbedResponse {
        var components = URLComponents(string: "https://www.tiktok.com/oembed")
        components?.queryItems = [
            URLQueryItem(name: "url", value: url.absoluteString)
        ]

        guard let oEmbedURL = components?.url else {
            throw QuickCaptureImportError.invalidURL
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
            throw QuickCaptureImportError.emptyContent
        }

        let metadata = try JSONDecoder().decode(TikTokOEmbedResponse.self, from: data)
        let hasTitle = metadata.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let hasAuthor = metadata.authorName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        guard hasTitle || hasAuthor else {
            throw QuickCaptureImportError.emptyContent
        }

        return metadata
    }

    func fetchYouTubeOEmbed(for url: URL) async throws -> TikTokOEmbedResponse {
        var components = URLComponents(string: "https://www.youtube.com/oembed")
        components?.queryItems = [
            URLQueryItem(name: "url", value: url.absoluteString),
            URLQueryItem(name: "format", value: "json")
        ]

        guard let oEmbedURL = components?.url else {
            throw QuickCaptureImportError.invalidURL
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
            throw QuickCaptureImportError.emptyContent
        }

        let metadata = try JSONDecoder().decode(TikTokOEmbedResponse.self, from: data)
        let hasTitle = metadata.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let hasAuthor = metadata.authorName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        guard hasTitle || hasAuthor else {
            throw QuickCaptureImportError.emptyContent
        }

        return metadata
    }

    func fetchInstagramMetadata(for url: URL) async throws -> CreatorMediaMetadata {
        let fetched = try await fetchWebContent(from: url)
        let extracted = extractReadableContent(from: fetched.html, url: url)
        let components = instagramTitleComponents(
            extracted.title,
            fallback: NoteSourcePlatformResolver.platform(for: url).displayName
        )

        return CreatorMediaMetadata(
            title: components.title,
            authorName: components.authorName,
            authorURL: nil,
            authorHandle: instagramAuthorHandle(from: url)
        )
    }

    func fetchWebContent(from url: URL) async throws -> FetchedWebContent {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        let contentType = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type")

        let encoding = stringEncoding(from: contentType) ?? .utf8
        let html = String(data: data, encoding: encoding)
            ?? String(data: data, encoding: .utf8)
            ?? String(decoding: data, as: UTF8.self)

        return FetchedWebContent(html: html, contentType: contentType)
    }

    func stringEncoding(from contentType: String?) -> String.Encoding? {
        guard let contentType else { return nil }
        let parts = contentType
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        guard let charsetPart = parts.first(where: { $0.hasPrefix("charset=") }) else { return nil }
        let charset = charsetPart.replacingOccurrences(of: "charset=", with: "")

        switch charset {
        case "utf-8", "utf8":
            return .utf8
        case "iso-8859-1", "latin1":
            return .isoLatin1
        case "utf-16":
            return .utf16
        default:
            return nil
        }
    }

    func extractReadableContent(from html: String, url: URL) -> ExtractedWebContent {
        let title = firstMetaContent(in: html, names: ["og:title", "twitter:title"])
            ?? firstMatch(in: html, pattern: #"<title[^>]*>(.*?)</title>"#)
            ?? url.host(percentEncoded: false)
            ?? url.absoluteString

        let description = firstMetaContent(in: html, names: ["description", "og:description", "twitter:description"]) ?? ""
        let siteName = firstMetaContent(in: html, names: ["og:site_name"]) ?? url.host(percentEncoded: false) ?? ""
        let bodyHTML = preferredBodyHTML(from: html)
        let text = htmlToPlainText(bodyHTML)

        return ExtractedWebContent(
            title: htmlDecoded(title).trimmingCharacters(in: .whitespacesAndNewlines),
            description: htmlDecoded(description).trimmingCharacters(in: .whitespacesAndNewlines),
            siteName: htmlDecoded(siteName).trimmingCharacters(in: .whitespacesAndNewlines),
            text: text
        )
    }

    func preferredBodyHTML(from html: String) -> String {
        if let article = firstMatch(in: html, pattern: #"<article[^>]*>([\s\S]*?)</article>"#) {
            return article
        }
        if let main = firstMatch(in: html, pattern: #"<main[^>]*>([\s\S]*?)</main>"#) {
            return main
        }
        if let body = firstMatch(in: html, pattern: #"<body[^>]*>([\s\S]*?)</body>"#) {
            return body
        }
        return html
    }

    func htmlToPlainText(_ html: String) -> String {
        var text = html
        text = replaceMatches(in: text, pattern: #"<!--[\s\S]*?-->"#, with: " ")
        text = replaceMatches(in: text, pattern: #"<script[\s\S]*?</script>"#, with: " ")
        text = replaceMatches(in: text, pattern: #"<style[\s\S]*?</style>"#, with: " ")
        text = replaceMatches(in: text, pattern: #"<noscript[\s\S]*?</noscript>"#, with: " ")
        text = replaceMatches(in: text, pattern: #"<(br|p|div|li|h[1-6]|blockquote|section|tr)[^>]*>"#, with: "\n")
        text = replaceMatches(in: text, pattern: #"<[^>]+>"#, with: " ")
        text = htmlDecoded(text)
        text = text.replacingOccurrences(of: "\u{00a0}", with: " ")

        let lines = text
            .components(separatedBy: .newlines)
            .map { collapseWhitespace($0) }
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.count >= 2 && !boilerplatePhrases.contains(trimmed.lowercased())
            }

        var uniqueLines: [String] = []
        var seen = Set<String>()
        for line in lines {
            let key = line.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            uniqueLines.append(line)
        }

        return uniqueLines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var boilerplatePhrases: Set<String> {
        [
            "menu",
            "subscribe",
            "sign in",
            "log in",
            "privacy policy",
            "terms of service",
            "cookie policy",
            "all rights reserved"
        ]
    }

    func makeSourceMetadata(url: URL, extracted: ExtractedWebContent) -> NoteSourceMetadata {
        let platform = NoteSourcePlatformResolver.platform(for: url)
        let host = NoteSourcePlatformResolver.normalizedHost(from: url)
        let title = extracted.title.trimmingCharacters(in: .whitespacesAndNewlines)

        return NoteSourceMetadata(
            url: url.absoluteString,
            title: title.isEmpty ? platform.displayName : title,
            platformID: platform.id,
            platformName: platform.displayName,
            host: host
        )
    }

    func makeFallbackLinkNote(extracted: ExtractedWebContent, url: URL) -> String {
        let platform = NoteSourcePlatformResolver.platform(for: url)
        let excerpt = String(extracted.text.prefix(500))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let title = extracted.title.isEmpty ? platform.displayName : extracted.title
        let summary = fallbackSummaryText(
            description: extracted.description,
            excerpt: excerpt,
            siteName: extracted.siteName
        )

        return """
        # \(title)

        ## \(L10n.text("quick_capture.link.summary_heading"))

        \(summary)
        """
    }

    func makeSourceOnlyLinkNote(source: NoteSourceMetadata) -> String {
        if ["tiktok", "youtube", "instagram"].contains(source.platformID) {
            return """
            # \(source.title)
            """
        }

        return """
        # \(source.title)

        ## \(L10n.text("quick_capture.link.summary_heading"))

        \(L10n.text("quick_capture.link.summary_unavailable"))
        """
    }

    func makeCreatorMediaLinkNote(
        metadata: CreatorMediaMetadata,
        preferences: MediaLinkTranscriptSectionPreferences = .load()
    ) -> String {
        let authorLine = creatorMediaAuthorDisplayName(metadata: metadata)
        let description = metadata.title.trimmingCharacters(in: .whitespacesAndNewlines)
        var sections: [String] = []

        if preferences.showDescription {
            sections.append(markdownSection(
                heading: L10n.text("quick_capture.media_link.description_heading"),
                body: description
            ))
        }

        if preferences.showAuthor {
            sections.append(markdownSection(
                heading: L10n.text("quick_capture.media_link.author_label"),
                body: authorLine
            ))
        }

        if sections.isEmpty {
            sections.append(markdownSection(
                heading: L10n.text("quick_capture.media_link.description_heading"),
                body: description
            ))
        }

        return sections.joined(separator: "\n\n")
    }

    func creatorMediaAuthorDisplayName(metadata: CreatorMediaMetadata) -> String {
        let authorName = metadata.authorName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !authorName.isEmpty {
            return authorName
        }

        let authorHandle = metadata.authorHandle?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
            ?? ""

        return authorHandle.isEmpty ? L10n.text("quick_capture.media_link.author_unknown") : authorHandle
    }

    func makeTikTokLinkNote(title: String, metadata: TikTokOEmbedResponse) -> String {
        makeCreatorMediaLinkNote(
            metadata: CreatorMediaMetadata(
                title: title,
                authorName: metadata.authorName,
                authorURL: metadata.authorURL,
                authorHandle: metadata.authorUniqueID
            )
        )
    }

    func makeCreatorMediaTranscriptNote(
        metadata: CreatorMediaMetadata,
        transcript: String,
        polishTranscript: Bool = true,
        extractHook: Bool = true,
        preferences: MediaLinkTranscriptSectionPreferences = .load()
    ) async -> String {
        let cleanedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectivePreferences = preferences.selectedCount == 0 ? .all : preferences

        guard !cleanedTranscript.isEmpty else {
            return makeCreatorMediaLinkNote(metadata: metadata, preferences: effectivePreferences)
        }

        let hook = effectivePreferences.showHook && extractHook
            ? await extractedCreatorMediaHook(metadata: metadata, transcript: cleanedTranscript)
            : fallbackCreatorMediaHook(transcript: cleanedTranscript)

        let finalTranscript: String
        if effectivePreferences.showTranscript && polishTranscript {
            finalTranscript = await polishedCreatorMediaTranscript(cleanedTranscript)
        } else {
            finalTranscript = cleanedTranscript
        }

        var sections: [String] = []

        if effectivePreferences.showDescription || effectivePreferences.showAuthor {
            sections.append(makeCreatorMediaLinkNote(metadata: metadata, preferences: effectivePreferences))
        }

        if effectivePreferences.showHook {
            sections.append(markdownSection(
                heading: L10n.text("quick_capture.media_link.hook_heading"),
                body: hook
            ))
        }

        if effectivePreferences.showTranscript {
            sections.append(markdownSection(
                heading: L10n.text("quick_capture.media_link.transcript_heading"),
                body: finalTranscript
            ))
        }

        if sections.isEmpty {
            sections.append(markdownSection(
                heading: L10n.text("quick_capture.media_link.transcript_heading"),
                body: cleanedTranscript
            ))
        }

        return sections.joined(separator: "\n\n")
    }

    func extractedCreatorMediaHook(metadata: CreatorMediaMetadata, transcript: String) async -> String {
        let fallback = fallbackCreatorMediaHook(transcript: transcript)
        let title = metadata.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else { return fallback }

        let prompt = """
        Video description:
        \(title)

        Transcript:
        \(trimmedTranscript.prefix(20_000))
        """

        let systemInstruction = """
        You identify the hook in short-form videos for a personal notes app.

        Return only the opening hook that is used to grab attention.
        Use the same language as the transcript when possible.
        Prefer the creator's exact opening wording if it is present in the transcript.
        If the hook is implied instead of spoken directly, write one concise sentence that captures it.
        Do not add a heading, bullet, quote, or explanation.
        Do not invent facts that are not supported by the description or transcript.
        """

        do {
            let extracted = try await GeminiService.shared.generateContent(
                prompt: prompt,
                systemInstruction: systemInstruction,
                countUsage: false
            )
            let result = collapseWhitespace(extracted)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return result.isEmpty ? fallback : result
        } catch {
            return fallback
        }
    }

    func fallbackCreatorMediaHook(transcript: String) -> String {
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
            return L10n.text("quick_capture.link.summary_unavailable")
        }

        if collapsed.count <= 160 {
            return collapsed
        }

        return String(collapsed.prefix(160)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    func polishedCreatorMediaTranscript(_ transcript: String) async -> String {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        let prompt = """
        Polish this media transcript for a personal quick-capture note.

        Raw transcript:
        \(trimmed.prefix(30_000))
        """

        let systemInstruction = """
        You clean up audio/video transcripts for a personal notes app.

        Return only the cleaned transcript text.
        Keep the speaker's original language, meaning, order, and wording.
        Add helpful punctuation and paragraph breaks.
        Clean obvious transcription noise when needed.
        """

        do {
            let polished = try await GeminiService.shared.generateContent(
                prompt: prompt,
                systemInstruction: systemInstruction,
                countUsage: false
            )
            let result = polished.trimmingCharacters(in: .whitespacesAndNewlines)
            return result.isEmpty ? trimmed : result
        } catch {
            return trimmed
        }
    }

    func makeTikTokTranscriptNote(
        title: String,
        metadata: TikTokOEmbedResponse,
        transcript: String,
        polishTranscript: Bool = true,
        extractHook: Bool = true,
        preferences: MediaLinkTranscriptSectionPreferences = .load()
    ) async -> String {
        await makeCreatorMediaTranscriptNote(
            metadata: CreatorMediaMetadata(
                title: title,
                authorName: metadata.authorName,
                authorURL: metadata.authorURL,
                authorHandle: metadata.authorUniqueID
            ),
            transcript: transcript,
            polishTranscript: polishTranscript,
            extractHook: extractHook,
            preferences: preferences
        )
    }

    func markdownSection(heading: String, body: String) -> String {
        """
        ## \(heading)

        \(body)
        """
    }

    func makeAIOrganizedLinkNote(url: URL, extracted: ExtractedWebContent, fallback: String) async throws -> String {
        let summaryHeading = L10n.text("quick_capture.link.summary_heading")
        let preferredLanguage = preferredQuickCaptureOutputLanguage()
        let prompt = """
        Create a clean quick-capture note from this web page.

        Source URL:
        \(url.absoluteString)

        Page title:
        \(extracted.title)

        Page description:
        \(extracted.description)

        Extracted text:
        \(extracted.text.prefix(16_000))
        """

        let systemInstruction = """
        You organize web content for a personal quick-capture notes app.

        STRICT RULES:
        - Return only Markdown.
        - Do not include a Source URL line; the app displays the source separately.
        - Preserve facts from the source.
        - Do not invent claims, quotes, dates, or recommendations.
        - Write the note in the app's current language: \(preferredLanguage).
        - Always use exactly this structure and no other section headings:
          # Title
          ## \(summaryHeading)
        - If the source text is thin, say so briefly inside the summary instead of adding extra sections.
        - Do not create bullet lists unless the page is impossible to summarize clearly in paragraphs.
        """

        let organized = try await GeminiService.shared.generateContent(
            prompt: prompt,
            systemInstruction: systemInstruction,
            countUsage: false
        )
        let result = organized.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? fallback : result
    }

    func fallbackSummaryText(description: String, excerpt: String, siteName: String) -> String {
        let cleanedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedExcerpt = excerpt.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedSiteName = siteName.trimmingCharacters(in: .whitespacesAndNewlines)

        var parts: [String] = []

        if !cleanedDescription.isEmpty {
            parts.append(cleanedDescription)
        }

        if !cleanedExcerpt.isEmpty, cleanedExcerpt != cleanedDescription {
            parts.append(cleanedExcerpt)
        }

        if parts.isEmpty, !cleanedSiteName.isEmpty {
            parts.append(L10n.text("quick_capture.link.summary_site_only", cleanedSiteName))
        }

        if parts.isEmpty {
            return L10n.text("quick_capture.link.summary_unavailable")
        }

        return parts.joined(separator: "\n\n")
    }

    func preferredQuickCaptureOutputLanguage() -> String {
        let appLanguageIdentifier = Bundle.main.preferredLocalizations.first
            ?? Locale.preferredLanguages.first
            ?? Locale.current.identifier

        if let localizedName = Locale.current.localizedString(forIdentifier: appLanguageIdentifier),
           !localizedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return localizedName
        }

        return appLanguageIdentifier
    }

    func sanitizedInstagramTitle(_ rawTitle: String, fallback: String) -> String {
        instagramTitleComponents(rawTitle, fallback: fallback).title
    }

    func instagramTitleComponents(_ rawTitle: String, fallback: String) -> (title: String, authorName: String?) {
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (fallback, nil) }

        let parsed = parseInstagramChromeTitle(trimmed)
        let withoutInstagramChrome = (parsed.title ?? trimmed)
            .replacingOccurrences(of: #"^\s*Instagram\s*$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’ ").union(.whitespacesAndNewlines))

        let cleaned = sanitizedCreatorMediaTitle(withoutInstagramChrome)
        let authorName = parsed.authorName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (
            cleaned.isEmpty ? fallback : cleaned,
            authorName?.isEmpty == false ? authorName : nil
        )
    }

    func parseInstagramChromeTitle(_ title: String) -> (title: String?, authorName: String?) {
        let patterns = [
            #"^\s*(?:Instagram\s+用户|Instagram\s+user)\s+(.+?)\s*:\s*(.+?)\s*$"#,
            #"^\s*(.+?)\s+on\s+Instagram\s*:\s*(.+?)\s*$"#,
            #"^\s*Reel\s+by\s+(.+?)\s*:\s*(.+?)\s*$"#
        ]

        for pattern in patterns {
            guard let match = firstRegexMatch(in: title, pattern: pattern, captureGroups: 2) else { continue }
            return (title: match[1], authorName: match[0])
        }

        return (nil, nil)
    }

    func instagramAuthorHandle(from url: URL) -> String? {
        let components = url.pathComponents.filter { $0 != "/" }
        guard let reelIndex = components.firstIndex(of: "reel"), reelIndex > 0 else {
            return nil
        }
        return components[reelIndex - 1].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func firstMetaContent(in html: String, names: [String]) -> String? {
        for name in names {
            let escaped = NSRegularExpression.escapedPattern(for: name)
            let patterns = [
                #"<meta[^>]+(?:name|property)=["']\#(escaped)["'][^>]+content=["']([^"']+)["'][^>]*>"#,
                #"<meta[^>]+content=["']([^"']+)["'][^>]+(?:name|property)=["']\#(escaped)["'][^>]*>"#
            ]

            for pattern in patterns {
                if let match = firstMatch(in: html, pattern: pattern, captureGroup: 1) {
                    return match
                }
            }
        }
        return nil
    }

    func firstRegexMatch(in text: String, pattern: String, captureGroups: Int) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > captureGroups else {
            return nil
        }

        var captures: [String] = []
        for index in 1...captureGroups {
            guard let swiftRange = Range(match.range(at: index), in: text) else {
                return nil
            }
            captures.append(String(text[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return captures
    }

    func firstMatch(in text: String, pattern: String, captureGroup: Int = 1) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > captureGroup,
              let swiftRange = Range(match.range(at: captureGroup), in: text) else {
            return nil
        }
        return String(text[swiftRange])
    }

    func replaceMatches(in text: String, pattern: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }

    func collapseWhitespace(_ text: String) -> String {
        replaceMatches(in: text, pattern: #"\s+"#, with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func htmlDecoded(_ text: String) -> String {
        guard let data = text.data(using: .utf8),
              let attributed = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              ) else {
            return text
        }
        return attributed.string
    }
}
