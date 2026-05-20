import Foundation

enum SharedImportQueue {
    static let appGroupIdentifier = "group.com.sponteoai.chillnote"
    static let pendingImportsDirectoryName = "PendingShareImports"

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
        guard let directory = pendingImportsDirectoryURL(),
              let fileURLs = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
              ) else {
            return []
        }

        return fileURLs
            .filter { $0.pathExtension == "json" }
            .compactMap { fileURL in
                guard let data = try? Data(contentsOf: fileURL),
                      let importItem = try? JSONDecoder.sharedImportDecoder.decode(PendingImport.self, from: data) else {
                    return nil
                }
                return PendingImportFile(importItem: importItem, fileURL: fileURL)
            }
            .sorted { $0.importItem.createdAt < $1.importItem.createdAt }
    }

    static func remove(_ file: PendingImportFile) {
        try? FileManager.default.removeItem(at: file.fileURL)
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
