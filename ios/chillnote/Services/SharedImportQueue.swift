import Foundation
import OSLog

enum SharedImportQueue {
    static let appGroupIdentifier = "group.com.sponteoai.chillnote"
    static let pendingImportsDirectoryName = "PendingShareImports"
    private static let logger = Logger(subsystem: "com.chillnote.app", category: "shared-imports")

    struct PendingImport: Codable, Sendable {
        enum Kind: String, Codable, Sendable {
            case note
            case linkImport
        }

        struct Source: Codable, Sendable {
            let url: String
            let title: String
            let platformID: String
            let platformName: String
            let host: String
            let authorName: String?
            let authorHandle: String?
        }

        let id: UUID
        let kind: Kind?
        let noteText: String?
        let source: Source
        let importJobId: String?
        let importStatus: String?
        let createdAt: Date
        let userId: String?

        var importKind: Kind {
            kind ?? .note
        }

        func belongs(to currentUserId: String) -> Bool {
            guard let userId else {
                // There is no reliable way to infer which account created an old
                // unowned item after an account switch. Keep it isolated instead
                // of exposing it to whichever account happens to sign in first.
                return false
            }
            return userId.caseInsensitiveCompare(currentUserId) == .orderedSame
        }

        var noteSourceMetadata: NoteSourceMetadata {
            NoteSourceMetadata(
                url: source.url,
                title: source.title,
                platformID: source.platformID,
                platformName: source.platformName,
                host: source.host,
                authorName: source.authorName,
                authorHandle: source.authorHandle
            )
        }
    }

    struct PendingImportFile: Sendable {
        let importItem: PendingImport
        let fileURL: URL
    }

    static func pendingImports() throws -> [PendingImportFile] {
        guard let directory = pendingImportsDirectoryURL() else {
            logger.error("Shared imports directory is unavailable")
            throw CocoaError(.fileNoSuchFile)
        }

        guard FileManager.default.fileExists(atPath: directory.path) else {
            return []
        }

        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        return fileURLs
            .filter { $0.pathExtension == "json" }
            .compactMap { fileURL in
                do {
                    let data = try Data(contentsOf: fileURL)
                    let importItem = try JSONDecoder.sharedImportDecoder.decode(PendingImport.self, from: data)
                    return PendingImportFile(importItem: importItem, fileURL: fileURL)
                } catch {
                    logger.error("Failed to read shared import \(fileURL.lastPathComponent, privacy: .private): \(error.localizedDescription, privacy: .public)")
                    return nil
                }
            }
            .sorted { $0.importItem.createdAt < $1.importItem.createdAt }
    }

    static func remove(_ file: PendingImportFile) throws {
        try FileManager.default.removeItem(at: file.fileURL)
    }

    static func sharedDefaults() -> UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    private static func pendingImportsDirectoryURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(pendingImportsDirectoryName, isDirectory: true)
    }
}

extension JSONDecoder {
    static var sharedImportDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension Notification.Name {
    static let sharedImportsRequested = Notification.Name("SharedImportsRequested")
}
