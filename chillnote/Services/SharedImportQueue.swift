import Foundation
import OSLog

enum SharedImportQueue {
    static let appGroupIdentifier = "group.com.sponteoai.chillnote"
    static let pendingImportsDirectoryName = "PendingShareImports"
    private static let logger = Logger(subsystem: "com.chillnote.app", category: "shared-imports")

    struct PendingImport: Codable, Sendable {
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

        var noteSourceMetadata: NoteSourceMetadata {
            NoteSourceMetadata(
                url: source.url,
                title: source.title,
                platformID: source.platformID,
                platformName: source.platformName,
                host: source.host
            )
        }
    }

    struct PendingImportFile: Sendable {
        let importItem: PendingImport
        let fileURL: URL
    }

    static func pendingImports() -> [PendingImportFile] {
        guard let directory = pendingImportsDirectoryURL() else {
            logger.error("Shared imports directory is unavailable")
            return []
        }

        let fileURLs: [URL]
        do {
            fileURLs = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            logger.error("Failed to list shared imports: \(error.localizedDescription, privacy: .public)")
            return []
        }

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

    static func remove(_ file: PendingImportFile) {
        do {
            try FileManager.default.removeItem(at: file.fileURL)
        } catch {
            logger.error("Failed to remove shared import \(file.fileURL.lastPathComponent, privacy: .private): \(error.localizedDescription, privacy: .public)")
        }
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
