import Foundation
import SwiftData
import SQLite3

struct NoteSearchDocument: Sendable {
    let noteId: UUID
    let userId: String
    let contentPlain: String
    let tagsPlain: String
    let updatedAt: TimeInterval
    let deletedAt: TimeInterval?
}

enum NoteTextNormalizer {
    static func normalizeContent(_ content: String) -> String {
        var text = content
        text = text.replacingOccurrences(of: "^#{1,6}\\s+", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "**", with: "")
        text = text.replacingOccurrences(of: "`", with: "")
        text = text.replacingOccurrences(of: "- [ ] ", with: "")
        text = text.replacingOccurrences(of: "- [x] ", with: "")
        text = text.replacingOccurrences(of: "- [X] ", with: "")
        text = text.replacingOccurrences(of: "[\\n\\r\\t]+", with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func tagsText(_ tags: [Tag]) -> String {
        tags.map { $0.name }.joined(separator: " ")
    }
}

actor SQLiteFTSNotesSearchIndex {
    private let schemaVersion = 1
    private var db: OpaquePointer?
    private var dbURL: URL?

    init() {}

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    func upsert(documents: [NoteSearchDocument]) {
        guard !documents.isEmpty, openIfNeeded() else { return }
        guard let db else { return }

        sqlite3_exec(db, "BEGIN IMMEDIATE TRANSACTION;", nil, nil, nil)
        defer { sqlite3_exec(db, "COMMIT;", nil, nil, nil) }

        let indexSQL = """
        INSERT INTO note_index (note_id, user_id, content_plain, tags_plain, updated_at, deleted_at)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(note_id) DO UPDATE SET
            user_id=excluded.user_id,
            content_plain=excluded.content_plain,
            tags_plain=excluded.tags_plain,
            updated_at=excluded.updated_at,
            deleted_at=excluded.deleted_at;
        """

        let ftsDeleteSQL = "DELETE FROM note_fts WHERE note_id = ?;"
        let ftsInsertSQL = """
        INSERT INTO note_fts (note_id, user_id, content_plain, tags_plain, updated_at, deleted_at)
        VALUES (?, ?, ?, ?, ?, ?);
        """

        var indexStmt: OpaquePointer?
        var ftsDeleteStmt: OpaquePointer?
        var ftsInsertStmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, indexSQL, -1, &indexStmt, nil) == SQLITE_OK,
              sqlite3_prepare_v2(db, ftsDeleteSQL, -1, &ftsDeleteStmt, nil) == SQLITE_OK,
              sqlite3_prepare_v2(db, ftsInsertSQL, -1, &ftsInsertStmt, nil) == SQLITE_OK else {
            PerformanceTelemetry.mark("search_index.prepare_failed")
            sqlite3_finalize(indexStmt)
            sqlite3_finalize(ftsDeleteStmt)
            sqlite3_finalize(ftsInsertStmt)
            return
        }

        defer {
            sqlite3_finalize(indexStmt)
            sqlite3_finalize(ftsDeleteStmt)
            sqlite3_finalize(ftsInsertStmt)
        }

        for doc in documents {
            sqlite3_reset(indexStmt)
            sqlite3_clear_bindings(indexStmt)
            bindText(indexStmt, index: 1, value: doc.noteId.uuidString)
            bindText(indexStmt, index: 2, value: doc.userId)
            bindText(indexStmt, index: 3, value: doc.contentPlain)
            bindText(indexStmt, index: 4, value: doc.tagsPlain)
            sqlite3_bind_double(indexStmt, 5, doc.updatedAt)
            if let deletedAt = doc.deletedAt {
                sqlite3_bind_double(indexStmt, 6, deletedAt)
            } else {
                sqlite3_bind_null(indexStmt, 6)
            }
            _ = sqlite3_step(indexStmt)

            sqlite3_reset(ftsDeleteStmt)
            sqlite3_clear_bindings(ftsDeleteStmt)
            bindText(ftsDeleteStmt, index: 1, value: doc.noteId.uuidString)
            _ = sqlite3_step(ftsDeleteStmt)

            sqlite3_reset(ftsInsertStmt)
            sqlite3_clear_bindings(ftsInsertStmt)
            bindText(ftsInsertStmt, index: 1, value: doc.noteId.uuidString)
            bindText(ftsInsertStmt, index: 2, value: doc.userId)
            bindText(ftsInsertStmt, index: 3, value: doc.contentPlain)
            bindText(ftsInsertStmt, index: 4, value: doc.tagsPlain)
            sqlite3_bind_double(ftsInsertStmt, 5, doc.updatedAt)
            if let deletedAt = doc.deletedAt {
                sqlite3_bind_double(ftsInsertStmt, 6, deletedAt)
            } else {
                sqlite3_bind_null(ftsInsertStmt, 6)
            }
            _ = sqlite3_step(ftsInsertStmt)
        }
    }

    func remove(noteIDs: [UUID]) {
        guard !noteIDs.isEmpty, openIfNeeded() else { return }
        guard let db else { return }

        let deleteIndexSQL = "DELETE FROM note_index WHERE note_id = ?;"
        let deleteFTSSQL = "DELETE FROM note_fts WHERE note_id = ?;"

        var deleteIndexStmt: OpaquePointer?
        var deleteFTSStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, deleteIndexSQL, -1, &deleteIndexStmt, nil) == SQLITE_OK,
              sqlite3_prepare_v2(db, deleteFTSSQL, -1, &deleteFTSStmt, nil) == SQLITE_OK else {
            sqlite3_finalize(deleteIndexStmt)
            sqlite3_finalize(deleteFTSStmt)
            return
        }
        defer {
            sqlite3_finalize(deleteIndexStmt)
            sqlite3_finalize(deleteFTSStmt)
        }

        sqlite3_exec(db, "BEGIN IMMEDIATE TRANSACTION;", nil, nil, nil)
        defer { sqlite3_exec(db, "COMMIT;", nil, nil, nil) }

        for id in noteIDs {
            let idString = id.uuidString

            sqlite3_reset(deleteIndexStmt)
            sqlite3_clear_bindings(deleteIndexStmt)
            bindText(deleteIndexStmt, index: 1, value: idString)
            _ = sqlite3_step(deleteIndexStmt)

            sqlite3_reset(deleteFTSStmt)
            sqlite3_clear_bindings(deleteFTSStmt)
            bindText(deleteFTSStmt, index: 1, value: idString)
            _ = sqlite3_step(deleteFTSStmt)
        }
    }

    func searchNoteIDs(userId: String, query: String, includeDeleted: Bool, offset: Int, limit: Int) -> [UUID] {
        guard openIfNeeded(), let db, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        let cleanedQuery = query
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let sql: String
        if includeDeleted {
            sql = """
            SELECT note_id
            FROM note_fts
            WHERE user_id = ? AND note_fts MATCH ? AND deleted_at IS NOT NULL
            ORDER BY bm25(note_fts)
            LIMIT ? OFFSET ?;
            """
        } else {
            sql = """
            SELECT note_id
            FROM note_fts
            WHERE user_id = ? AND note_fts MATCH ? AND deleted_at IS NULL
            ORDER BY bm25(note_fts)
            LIMIT ? OFFSET ?;
            """
        }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            PerformanceTelemetry.mark("search_index.query_prepare_failed")
            sqlite3_finalize(stmt)
            return []
        }
        defer { sqlite3_finalize(stmt) }

        bindText(stmt, index: 1, value: userId)
        bindText(stmt, index: 2, value: cleanedQuery)
        sqlite3_bind_int(stmt, 3, Int32(limit))
        sqlite3_bind_int(stmt, 4, Int32(offset))

        var ids: [UUID] = []
        ids.reserveCapacity(limit)
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let cString = sqlite3_column_text(stmt, 0) else { continue }
            let raw = String(cString: cString)
            if let id = UUID(uuidString: raw) {
                ids.append(id)
            }
        }
        return ids
    }

    func countMatches(userId: String, query: String, includeDeleted: Bool) -> Int {
        guard openIfNeeded(), let db, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return 0
        }

        let sql: String
        if includeDeleted {
            sql = """
            SELECT COUNT(*)
            FROM note_fts
            WHERE user_id = ? AND note_fts MATCH ? AND deleted_at IS NOT NULL;
            """
        } else {
            sql = """
            SELECT COUNT(*)
            FROM note_fts
            WHERE user_id = ? AND note_fts MATCH ? AND deleted_at IS NULL;
            """
        }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            sqlite3_finalize(stmt)
            return 0
        }
        defer { sqlite3_finalize(stmt) }

        let cleanedQuery = query
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        bindText(stmt, index: 1, value: userId)
        bindText(stmt, index: 2, value: cleanedQuery)

        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    private func openIfNeeded() -> Bool {
        if db != nil {
            return true
        }

        do {
            let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let directory = root.appendingPathComponent("ChillNote", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("note_search.sqlite", isDirectory: false)
            dbURL = url

            if sqlite3_open(url.path, &db) != SQLITE_OK {
                db = nil
                PerformanceTelemetry.mark("search_index.open_failed")
                return false
            }

            guard let db else { return false }
            sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA synchronous=NORMAL;", nil, nil, nil)

            let createMeta = """
            CREATE TABLE IF NOT EXISTS index_meta (
                k TEXT PRIMARY KEY,
                v TEXT
            );
            """
            let createIndex = """
            CREATE TABLE IF NOT EXISTS note_index (
                note_id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                content_plain TEXT NOT NULL,
                tags_plain TEXT NOT NULL,
                updated_at REAL NOT NULL,
                deleted_at REAL
            );
            """
            let createFTS = """
            CREATE VIRTUAL TABLE IF NOT EXISTS note_fts USING fts5(
                note_id UNINDEXED,
                user_id UNINDEXED,
                content_plain,
                tags_plain,
                updated_at UNINDEXED,
                deleted_at UNINDEXED
            );
            """
            sqlite3_exec(db, createMeta, nil, nil, nil)
            sqlite3_exec(db, createIndex, nil, nil, nil)
            sqlite3_exec(db, createFTS, nil, nil, nil)

            let setVersion = "INSERT INTO index_meta(k, v) VALUES('schema_version', ?) ON CONFLICT(k) DO UPDATE SET v=excluded.v;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, setVersion, -1, &stmt, nil) == SQLITE_OK {
                bindText(stmt, index: 1, value: "\(schemaVersion)")
                _ = sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
            return true
        } catch {
            PerformanceTelemetry.mark("search_index.open_exception", detail: error.localizedDescription)
            return false
        }
    }
}

@MainActor
final class NotesSearchIndexer {
    static let shared = NotesSearchIndexer()

    private let index = SQLiteFTSNotesSearchIndex()
    private let defaults = UserDefaults.standard
    private let lastIndexedPrefix = "searchIndex.lastIndexedAt."

    private init() { }

    func rebuildIfNeeded(context: ModelContext, userId: String) async {
        if getLastIndexedAt(userId: userId).timeIntervalSince1970 > 0 {
            await syncIncremental(context: context, userId: userId)
            return
        }

        let start = PerformanceTelemetry.begin("search_index.rebuild")
        do {
            var descriptor = FetchDescriptor<Note>()
            descriptor.predicate = #Predicate<Note> { note in
                note.userId == userId
            }
            let notes = try context.fetch(descriptor)
            let docs = notes.map(makeDocument)
            await index.upsert(documents: docs)
            setLastIndexedAt(Date(), userId: userId)
            PerformanceTelemetry.end("search_index.rebuild", from: start, extra: "count=\(docs.count)")
        } catch {
            PerformanceTelemetry.mark("search_index.rebuild_failed", detail: error.localizedDescription)
        }
    }

    func syncIncremental(context: ModelContext, userId: String) async {
        let start = PerformanceTelemetry.begin("search_index.incremental")
        let lastIndexedAt = getLastIndexedAt(userId: userId)
        let lowerBound = Date(timeIntervalSince1970: max(0, lastIndexedAt.timeIntervalSince1970 - 1))

        do {
            var descriptor = FetchDescriptor<Note>()
            descriptor.predicate = #Predicate<Note> { note in
                note.userId == userId
            }
            let notes = try context.fetch(descriptor)

            // Keep predicate simple for SwiftData compatibility, then filter in-memory.
            let changed = notes.filter { note in
                note.updatedAt >= lowerBound || ((note.deletedAt ?? .distantPast) >= lowerBound)
            }

            if !changed.isEmpty {
                await index.upsert(documents: changed.map(makeDocument))
            }
            setLastIndexedAt(Date(), userId: userId)
            PerformanceTelemetry.end("search_index.incremental", from: start, extra: "count=\(changed.count)")
        } catch {
            PerformanceTelemetry.mark("search_index.incremental_failed", detail: error.localizedDescription)
        }
    }

    func reindex(noteIDs: [UUID], context: ModelContext, userId: String) async {
        guard !noteIDs.isEmpty else { return }
        do {
            var descriptor = FetchDescriptor<Note>()
            descriptor.predicate = #Predicate<Note> { note in
                note.userId == userId && noteIDs.contains(note.id)
            }
            let notes = try context.fetch(descriptor)
            let existingIDs = Set(notes.map(\.id))
            let missingIDs = noteIDs.filter { !existingIDs.contains($0) }
            if !notes.isEmpty {
                await index.upsert(documents: notes.map(makeDocument))
            }
            if !missingIDs.isEmpty {
                await index.remove(noteIDs: missingIDs)
            }
        } catch {
            PerformanceTelemetry.mark("search_index.reindex_failed", detail: error.localizedDescription)
        }
    }

    func remove(noteIDs: [UUID]) async {
        await index.remove(noteIDs: noteIDs)
    }

    func searchNoteIDs(userId: String, query: String, includeDeleted: Bool, offset: Int, limit: Int) async -> [UUID] {
        await index.searchNoteIDs(userId: userId, query: query, includeDeleted: includeDeleted, offset: offset, limit: limit)
    }

    func countMatches(userId: String, query: String, includeDeleted: Bool) async -> Int {
        await index.countMatches(userId: userId, query: query, includeDeleted: includeDeleted)
    }

    private func makeDocument(note: Note) -> NoteSearchDocument {
        let normalizedContent = NoteTextNormalizer.normalizeContent(note.content)
        return NoteSearchDocument(
            noteId: note.id,
            userId: note.userId,
            contentPlain: normalizedContent,
            tagsPlain: NoteTextNormalizer.tagsText(note.tags),
            updatedAt: note.updatedAt.timeIntervalSince1970,
            deletedAt: note.deletedAt?.timeIntervalSince1970
        )
    }

    private func getLastIndexedAt(userId: String) -> Date {
        let key = lastIndexedPrefix + userId
        let ts = defaults.double(forKey: key)
        if ts <= 0 {
            return Date(timeIntervalSince1970: 0)
        }
        return Date(timeIntervalSince1970: ts)
    }

    private func setLastIndexedAt(_ date: Date, userId: String) {
        let key = lastIndexedPrefix + userId
        defaults.set(date.timeIntervalSince1970, forKey: key)
    }
}

private let transientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private func bindText(_ statement: OpaquePointer?, index: Int32, value: String) {
    _ = value.withCString { raw in
        sqlite3_bind_text(statement, index, raw, -1, transientDestructor)
    }
}
