import Foundation
import SwiftData
import ZIPFoundation

protocol NotesExporting: Sendable {
    func countMarkdownNotes(request: ExportRequest) async throws -> Int
    func exportAllMarkdown(
        request: ExportRequest,
        onProgress: @escaping @Sendable (ExportProgress) -> Void
    ) async throws -> URL
    func cleanupExportArtifact(at url: URL) async
}

struct ExportRequest: Sendable {
    let userId: String
    var includeDeleted: Bool = false
    var batchSize: Int = 200
}

enum ExportStage: String, Sendable {
    case preparing
    case reading
    case writing
    case zipping
    case finishing
}

struct ExportProgress: Sendable {
    var stage: ExportStage
    var processed: Int
    var total: Int
    var elapsed: TimeInterval
    var message: String

    static let empty = ExportProgress(
        stage: .preparing,
        processed: 0,
        total: 0,
        elapsed: 0,
        message: String(localized: "Preparing export...")
    )

    var fraction: Double {
        guard total > 0 else { return 0 }
        return min(max(Double(processed) / Double(total), 0), 1)
    }
}

struct ExportResult: Sendable {
    let fileURL: URL
    let noteCount: Int
    let duration: TimeInterval
    let fileSizeBytes: Int64
}

enum ExportError: LocalizedError {
    case missingContainer
    case noNotes
    case insufficientStorage
    case cancelled
    case invalidArchive
    case writeFailed
    case zipFailed
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .missingContainer:
            return String(localized: "Export service is unavailable right now.")
        case .noNotes:
            return String(localized: "No notes to export.")
        case .insufficientStorage:
            return String(localized: "Not enough storage to create export file.")
        case .cancelled:
            return String(localized: "Export was cancelled.")
        case .invalidArchive:
            return String(localized: "Unable to create zip archive.")
        case .writeFailed:
            return String(localized: "Failed to write markdown files.")
        case .zipFailed:
            return String(localized: "Failed to package markdown files.")
        case .unknown(let message):
            return message
        }
    }
}

actor NotesExportService: NotesExporting {
    static let shared = NotesExportService()

    private let fileManager: FileManager
    private let isoFormatter: ISO8601DateFormatter
    private let fileDateFormatter: DateFormatter

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.isoFormatter = isoFormatter

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        self.fileDateFormatter = formatter
    }

    func countMarkdownNotes(request: ExportRequest) async throws -> Int {
        let container = try await resolveContainer()
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Note>()
        descriptor.predicate = buildPredicate(userId: request.userId, includeDeleted: request.includeDeleted)
        return try context.fetchCount(descriptor)
    }

    func exportAllMarkdown(
        request: ExportRequest,
        onProgress: @escaping @Sendable (ExportProgress) -> Void
    ) async throws -> URL {
        let startedAt = Date()
        var stagingRootURL: URL?

        do {
            let container = try await resolveContainer()
            let context = ModelContext(container)

            var countDescriptor = FetchDescriptor<Note>()
            countDescriptor.predicate = buildPredicate(userId: request.userId, includeDeleted: request.includeDeleted)
            let total = try context.fetchCount(countDescriptor)
            guard total > 0 else { throw ExportError.noNotes }

            emitProgress(
                onProgress,
                stage: .preparing,
                processed: 0,
                total: total,
                startedAt: startedAt,
                message: String(localized: "Preparing export package...")
            )

            try ensureSufficientStorage(totalNotes: total)
            try Task.checkCancellation()

            let sessionId = UUID().uuidString
            let containerName = "ChillNote-Export-\(fileDateFormatter.string(from: Date()))"
            let tempRoot = fileManager.temporaryDirectory
                .appendingPathComponent("export-\(sessionId)", isDirectory: true)
            let exportRoot = tempRoot.appendingPathComponent(containerName, isDirectory: true)
            let notesRoot = exportRoot.appendingPathComponent("notes", isDirectory: true)
            stagingRootURL = tempRoot

            try fileManager.createDirectory(at: notesRoot, withIntermediateDirectories: true)

            let sortedBy: [SortDescriptor<Note>] = [
                SortDescriptor(\Note.createdAt, order: .forward),
                SortDescriptor(\Note.id, order: .forward)
            ]

            var processed = 0
            var usedFilenames = Set<String>()
            var duplicateCounterByBase: [String: Int] = [:]
            var lastProgressEmission = Date.distantPast
            let chunk = max(50, request.batchSize)

            while processed < total {
                try Task.checkCancellation()

                var descriptor = FetchDescriptor<Note>(sortBy: sortedBy)
                descriptor.fetchOffset = processed
                descriptor.fetchLimit = chunk
                descriptor.predicate = buildPredicate(userId: request.userId, includeDeleted: request.includeDeleted)
                let notes = try context.fetch(descriptor)
                guard !notes.isEmpty else { break }

                emitProgress(
                    onProgress,
                    stage: .reading,
                    processed: processed,
                    total: total,
                    startedAt: startedAt,
                    message: String(localized: "Reading notes...")
                )

                var writeFailed = false
                autoreleasepool {
                    for note in notes {
                        if Task.isCancelled {
                            return
                        }
                        let fileName = NotesExportFormatter.makeNoteFilename(
                            content: note.content,
                            createdAt: note.createdAt,
                            noteId: note.id,
                            usedNames: &usedFilenames,
                            collisionCounter: &duplicateCounterByBase,
                            timestampFormatter: fileDateFormatter
                        )
                        let markdown = NotesExportFormatter.makeMarkdownDocument(
                            note: note,
                            isoFormatter: isoFormatter
                        )
                        let fileURL = notesRoot.appendingPathComponent(fileName)
                        do {
                            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
                        } catch {
                            writeFailed = true
                            return
                        }

                        processed += 1
                        let now = Date()
                        if processed == total || processed % 20 == 0 || now.timeIntervalSince(lastProgressEmission) >= 0.1 {
                            lastProgressEmission = now
                            emitProgress(
                                onProgress,
                                stage: .writing,
                                processed: processed,
                                total: total,
                                startedAt: startedAt,
                                message: String(localized: "Writing markdown files...")
                            )
                        }
                    }
                }

                if Task.isCancelled {
                    throw ExportError.cancelled
                }
                if writeFailed {
                    throw ExportError.writeFailed
                }
            }

            try Task.checkCancellation()

            emitProgress(
                onProgress,
                stage: .zipping,
                processed: processed,
                total: total,
                startedAt: startedAt,
                message: String(localized: "Packaging zip file...")
            )

            let zipURL = fileManager.temporaryDirectory
                .appendingPathComponent("\(containerName).zip", isDirectory: false)
            if fileManager.fileExists(atPath: zipURL.path) {
                try? fileManager.removeItem(at: zipURL)
            }

            let archive: Archive
            do {
                archive = try Archive(url: zipURL, accessMode: .create)
            } catch {
                throw ExportError.invalidArchive
            }

            try addFilesRecursively(from: exportRoot, baseURL: tempRoot, to: archive)

            try? fileManager.removeItem(at: tempRoot)

            emitProgress(
                onProgress,
                stage: .finishing,
                processed: total,
                total: total,
                startedAt: startedAt,
                message: String(localized: "Export ready")
            )

            return zipURL
        } catch is CancellationError {
            if let stagingRootURL {
                try? fileManager.removeItem(at: stagingRootURL)
            }
            throw ExportError.cancelled
        } catch let exportError as ExportError {
            if let stagingRootURL {
                try? fileManager.removeItem(at: stagingRootURL)
            }
            throw exportError
        } catch {
            if let stagingRootURL {
                try? fileManager.removeItem(at: stagingRootURL)
            }
            throw ExportError.unknown(error.localizedDescription)
        }
    }

    func cleanupExportArtifact(at url: URL) async {
        try? fileManager.removeItem(at: url)
    }

    private func resolveContainer() async throws -> ModelContainer {
        guard let container = await MainActor.run(body: { DataService.shared.container }) else {
            throw ExportError.missingContainer
        }
        return container
    }

    private func buildPredicate(userId: String, includeDeleted: Bool) -> Predicate<Note> {
        if includeDeleted {
            return #Predicate<Note> { note in
                note.userId == userId
            }
        }

        return #Predicate<Note> { note in
            note.userId == userId && note.deletedAt == nil
        }
    }

    private func ensureSufficientStorage(totalNotes: Int) throws {
        let estimatedBytes = max(2_000_000, totalNotes * 2_500)
        let estimatedRequired = Int64(Double(estimatedBytes) * 1.5)

        let capacity = try fileManager.temporaryDirectory
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage

        if let capacity, Int64(capacity) < estimatedRequired {
            throw ExportError.insufficientStorage
        }
    }

    private func addFilesRecursively(from root: URL, baseURL: URL, to archive: Archive) throws {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw ExportError.zipFailed
        }

        for case let fileURL as URL in enumerator {
            try Task.checkCancellation()
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }
            let relativePath = fileURL.path.replacingOccurrences(of: baseURL.path + "/", with: "")
            do {
                try archive.addEntry(with: relativePath, relativeTo: baseURL, compressionMethod: .deflate)
            } catch {
                throw ExportError.zipFailed
            }
        }
    }

    private func emitProgress(
        _ onProgress: @escaping @Sendable (ExportProgress) -> Void,
        stage: ExportStage,
        processed: Int,
        total: Int,
        startedAt: Date,
        message: String
    ) {
        onProgress(
            ExportProgress(
                stage: stage,
                processed: processed,
                total: total,
                elapsed: Date().timeIntervalSince(startedAt),
                message: message
            )
        )
    }
}

enum NotesExportFormatter {
    static func makeNoteFilename(
        content: String,
        createdAt: Date,
        noteId: UUID,
        usedNames: inout Set<String>,
        collisionCounter: inout [String: Int],
        timestampFormatter: DateFormatter
    ) -> String {
        let title = firstTitleLine(from: content)
        let sanitizedTitle = sanitizeFileComponent(title.isEmpty ? "ChillNote" : title)
        let timestamp = timestampFormatter.string(from: createdAt)
        let idSuffix = noteId.uuidString.prefix(6)

        let base = "\(sanitizedTitle)-\(timestamp)-\(idSuffix)"
        var finalBase = base

        if usedNames.contains("\(finalBase).md") {
            let next = (collisionCounter[base] ?? 1) + 1
            collisionCounter[base] = next
            finalBase = "\(base)-\(next)"
        } else {
            collisionCounter[base] = 1
        }

        var finalName = "\(finalBase).md"
        while usedNames.contains(finalName) {
            let next = (collisionCounter[base] ?? 1) + 1
            collisionCounter[base] = next
            finalName = "\(base)-\(next).md"
        }

        usedNames.insert(finalName)
        return finalName
    }

    static func makeMarkdownDocument(note: Note, isoFormatter: ISO8601DateFormatter) -> String {
        let stableSortLocale = Locale(identifier: "en_US_POSIX")
        let tags = note.tags
            .filter { $0.deletedAt == nil }
            .map { $0.name }
            .sorted { lhs, rhs in
                let leftKey = lhs.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: stableSortLocale)
                let rightKey = rhs.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: stableSortLocale)
                if leftKey == rightKey {
                    return lhs < rhs
                }
                return leftKey < rightKey
            }

        let tagsValue = tags.map { "\"\(escapeYAMLString($0))\"" }.joined(separator: ", ")

        return """
        ---
        created_at: "\(isoFormatter.string(from: note.createdAt))"
        tags: [\(tagsValue)]
        ---

        \(note.content)
        """
    }

    static func sanitizeFileComponent(_ raw: String) -> String {
        let withoutIllegal = raw.replacingOccurrences(
            of: #"[\\/:*?\"<>|]"#,
            with: "-",
            options: .regularExpression
        )
        let withoutLineBreaks = withoutIllegal.replacingOccurrences(of: "\n", with: " ")
        let squashed = withoutLineBreaks.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        let fallback = squashed.isEmpty ? "ChillNote" : squashed
        return String(fallback.prefix(60))
    }

    static func firstTitleLine(from markdown: String) -> String {
        for rawLine in markdown.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            return line
        }
        return ""
    }

    static func escapeYAMLString(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
