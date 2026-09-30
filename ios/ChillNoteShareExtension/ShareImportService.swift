import Foundation

enum ShareImportError: LocalizedError {
    case missingLink
    case missingAuthToken
    case invalidBackendURL
    case backendError(String)
    case insufficientCredits
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
        case .insufficientCredits:
            return ShareL10n.text("share_extension.insufficient_credits")
        case .emptyTranscript:
            return ShareL10n.text("share_extension.failed")
        case .sharedContainerUnavailable:
            return ShareL10n.text("share_extension.failed")
        }
    }

    var analyticsCode: String {
        switch self {
        case .missingLink: return "missing_link"
        case .missingAuthToken: return "not_authenticated"
        case .invalidBackendURL: return "invalid_backend"
        case .backendError: return "backend_error"
        case .insufficientCredits: return "insufficient_credits"
        case .emptyTranscript: return "empty_transcript"
        case .sharedContainerUnavailable: return "shared_container_unavailable"
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

    static var transcriptOnly: ShareMediaLinkTranscriptSectionPreferences {
        ShareMediaLinkTranscriptSectionPreferences(
            showDescription: false,
            showAuthor: false,
            showHook: false,
            showTranscript: true
        )
    }

    static func load() -> ShareMediaLinkTranscriptSectionPreferences {
        .transcriptOnly
    }
}

private struct ShareAsyncLinkImportJob: Decodable {
    let jobId: String
    let status: String
}

struct ShareImportService {
    var session: URLSession = .shared
    var sharedDefaults: UserDefaults? = UserDefaults(suiteName: ShareConstants.appGroupIdentifier)
    var containerURL: URL? = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: ShareConstants.appGroupIdentifier
    )

    func importSharedURL(
        _ url: URL,
        progress: @escaping @MainActor (ShareImportStage) -> Void
    ) async throws -> SharePendingImport {
        await progress(.readingContent)
        let pendingImport = makePendingLinkImport(url: url)
        await progress(.saving)
        try save(pendingImport)
        do {
            let remoteImport = try await startRemoteLinkImport(pendingImport)
            try? save(remoteImport)
        } catch ShareImportError.insufficientCredits {
            // The link is already durable. Surface the paid boundary truthfully
            // instead of presenting a successful conversion that never started.
            throw ShareImportError.insufficientCredits
        } catch {
            // Network/auth failures remain recoverable from the containing app.
            // The durable queue item is intentionally kept for the next foreground.
        }
        await progress(.completed)
        return pendingImport
    }

    private func makePendingLinkImport(url: URL) -> SharePendingImport {
        let platform = SharePlatformResolver.platform(for: url)
        let host = SharePlatformResolver.normalizedHost(from: url)
        // Capture only what can be derived locally. The server's queued job
        // resolves redirects, title, author and transcript after acceptance.

        return SharePendingImport(
            id: UUID(),
            kind: .linkImport,
            noteText: nil,
            source: SharePendingImport.Source(
                url: url.absoluteString,
                title: platform.displayName.isEmpty ? host : platform.displayName,
                platformID: platform.id,
                platformName: platform.displayName,
                host: host,
                authorName: nil,
                authorHandle: nil
            ),
            importJobId: nil,
            importStatus: nil,
            createdAt: Date(),
            userId: currentAuthenticatedUserId()
        )
    }

    private func startRemoteLinkImport(_ pendingImport: SharePendingImport) async throws -> SharePendingImport {
        guard let token = sharedDefaults?
            .string(forKey: ShareConstants.authTokenKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else {
            throw ShareImportError.missingAuthToken
        }
        guard let endpoint = URL(string: ShareConstants.backendBaseURL + "/link-import-jobs"),
              let url = URL(string: pendingImport.source.url) else {
            throw ShareImportError.invalidBackendURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        var sourcePayload: [String: Any] = [
            "url": pendingImport.source.url,
            "title": pendingImport.source.title,
            "platformID": pendingImport.source.platformID,
            "platformName": pendingImport.source.platformName,
            "host": pendingImport.source.host
        ]
        if let authorName = pendingImport.source.authorName {
            sourcePayload["authorName"] = authorName
        }
        if let authorHandle = pendingImport.source.authorHandle {
            sourcePayload["authorHandle"] = authorHandle
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "noteId": pendingImport.id.uuidString,
            "url": pendingImport.source.url,
            "placeholderContent": placeholderNoteText(for: url, source: pendingImport.source),
            "section": "inbox",
            "source": sourcePayload,
            "contentLocale": ShareL10n.contentLocaleIdentifier,
            "mediaLinkSections": mediaLinkSectionsPayload()
        ])

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ShareImportError.backendError("")
        }
        if httpResponse.statusCode == 402 {
            throw ShareImportError.insufficientCredits
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ShareImportError.backendError("Status code: \(httpResponse.statusCode)")
        }

        let job = try JSONDecoder().decode(ShareAsyncLinkImportJob.self, from: data)
        return SharePendingImport(
            id: pendingImport.id,
            kind: pendingImport.kind,
            noteText: pendingImport.noteText,
            source: pendingImport.source,
            importJobId: job.jobId,
            importStatus: job.status,
            createdAt: pendingImport.createdAt,
            userId: pendingImport.userId
        )
    }

    private func currentAuthenticatedUserId() -> String? {
        let userId = sharedDefaults?
            .string(forKey: ShareConstants.authenticatedUserIdKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return userId?.isEmpty == false ? userId : nil
    }

    private func placeholderNoteText(for url: URL, source: SharePendingImport.Source) -> String {
        """
        # \(ShareL10n.text("quick_capture.link_import.placeholder.title"))

        \(ShareL10n.text("quick_capture.link_import.placeholder.body", source.host.isEmpty ? url.absoluteString : source.host))
        """
    }

    private func mediaLinkSectionsPayload() -> [String: Bool] {
        let preferences = ShareMediaLinkTranscriptSectionPreferences.load()
        return [
            "showDescription": preferences.showDescription,
            "showAuthor": preferences.showAuthor,
            "showHook": preferences.showHook,
            "showTranscript": preferences.showTranscript
        ]
    }

    private func save(_ pendingImport: SharePendingImport) throws {
        guard let containerURL else {
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
