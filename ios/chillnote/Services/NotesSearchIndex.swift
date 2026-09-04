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

enum NotesSearchIndexError: LocalizedError {
    case sqlite(operation: String, code: Int32, message: String)

    var errorDescription: String? {
        switch self {
        case .sqlite(let operation, let code, let message):
            return "Search index \(operation) failed (SQLite \(code)): \(message)"
        }
    }
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

    static func foldForSearch(_ text: String) -> String {
        let normalized = text
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        let punctuationCollapsed = normalized.replacingOccurrences(
            of: "[\\p{P}\\p{S}]+",
            with: " ",
            options: .regularExpression
        )
        let whitespaceCollapsed = punctuationCollapsed.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        return whitespaceCollapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizeQuery(_ query: String) -> String {
        normalizeContent(query)
            .replacingOccurrences(of: "[\"'`]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

actor SQLiteFTSNotesSearchIndex {
    private let schemaVersion = 2
    private var db: OpaquePointer?
    private var requiresRebuildAfterMigration = false
    private let databaseURLOverride: URL?

    init(databaseURL: URL? = nil) {
        databaseURLOverride = databaseURL
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    func upsert(documents: [NoteSearchDocument]) throws {
        guard !documents.isEmpty else { return }
        try openIfNeeded()
        guard let db else {
            throw NotesSearchIndexError.sqlite(operation: "open", code: SQLITE_CANTOPEN, message: "Database handle is unavailable")
        }

        try execute("BEGIN IMMEDIATE TRANSACTION;", operation: "begin transaction", db: db)
        var didCommit = false
        defer {
            if !didCommit {
                sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            }
        }

        let indexSQL = """
        INSERT INTO note_index (note_id, user_id, content_plain, tags_plain, content_folded, tags_folded, updated_at, deleted_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(note_id) DO UPDATE SET
            user_id=excluded.user_id,
            content_plain=excluded.content_plain,
            tags_plain=excluded.tags_plain,
            content_folded=excluded.content_folded,
            tags_folded=excluded.tags_folded,
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
            throw sqliteError(operation: "prepare upsert", db: db)
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
            bindText(indexStmt, index: 5, value: NoteTextNormalizer.foldForSearch(doc.contentPlain))
            bindText(indexStmt, index: 6, value: NoteTextNormalizer.foldForSearch(doc.tagsPlain))
            sqlite3_bind_double(indexStmt, 7, doc.updatedAt)
            if let deletedAt = doc.deletedAt {
                sqlite3_bind_double(indexStmt, 8, deletedAt)
            } else {
                sqlite3_bind_null(indexStmt, 8)
            }
            guard sqlite3_step(indexStmt) == SQLITE_DONE else {
                throw sqliteError(operation: "upsert note", db: db)
            }

            sqlite3_reset(ftsDeleteStmt)
            sqlite3_clear_bindings(ftsDeleteStmt)
            bindText(ftsDeleteStmt, index: 1, value: doc.noteId.uuidString)
            guard sqlite3_step(ftsDeleteStmt) == SQLITE_DONE else {
                throw sqliteError(operation: "remove stale full-text row", db: db)
            }

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
            guard sqlite3_step(ftsInsertStmt) == SQLITE_DONE else {
                throw sqliteError(operation: "insert full-text row", db: db)
            }
        }

        try execute("COMMIT;", operation: "commit transaction", db: db)
        didCommit = true
        requiresRebuildAfterMigration = false
    }

    func remove(noteIDs: [UUID]) throws {
        guard !noteIDs.isEmpty else { return }
        try openIfNeeded()
        guard let db else {
            throw NotesSearchIndexError.sqlite(operation: "open", code: SQLITE_CANTOPEN, message: "Database handle is unavailable")
        }

        let deleteIndexSQL = "DELETE FROM note_index WHERE note_id = ?;"
        let deleteFTSSQL = "DELETE FROM note_fts WHERE note_id = ?;"

        var deleteIndexStmt: OpaquePointer?
        var deleteFTSStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, deleteIndexSQL, -1, &deleteIndexStmt, nil) == SQLITE_OK,
              sqlite3_prepare_v2(db, deleteFTSSQL, -1, &deleteFTSStmt, nil) == SQLITE_OK else {
            sqlite3_finalize(deleteIndexStmt)
            sqlite3_finalize(deleteFTSStmt)
            throw sqliteError(operation: "prepare removal", db: db)
        }
        defer {
            sqlite3_finalize(deleteIndexStmt)
            sqlite3_finalize(deleteFTSStmt)
        }

        try execute("BEGIN IMMEDIATE TRANSACTION;", operation: "begin removal transaction", db: db)
        var didCommit = false
        defer {
            if !didCommit {
                sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            }
        }

        for id in noteIDs {
            let idString = id.uuidString

            sqlite3_reset(deleteIndexStmt)
            sqlite3_clear_bindings(deleteIndexStmt)
            bindText(deleteIndexStmt, index: 1, value: idString)
            guard sqlite3_step(deleteIndexStmt) == SQLITE_DONE else {
                throw sqliteError(operation: "remove indexed note", db: db)
            }

            sqlite3_reset(deleteFTSStmt)
            sqlite3_clear_bindings(deleteFTSStmt)
            bindText(deleteFTSStmt, index: 1, value: idString)
            guard sqlite3_step(deleteFTSStmt) == SQLITE_DONE else {
                throw sqliteError(operation: "remove full-text note", db: db)
            }
        }

        try execute("COMMIT;", operation: "commit removal transaction", db: db)
        didCommit = true
    }

    func searchNoteIDs(userId: String, query: String, includeDeleted: Bool, offset: Int, limit: Int) throws -> [UUID] {
        guard limit > 0 else { return [] }
        try openIfNeeded()
        guard let db else {
            throw NotesSearchIndexError.sqlite(operation: "open", code: SQLITE_CANTOPEN, message: "Database handle is unavailable")
        }

        guard let plan = SearchQueryPlan(query: query) else {
            return []
        }
        let deletedPredicate = includeDeleted ? "deleted_at IS NOT NULL" : "deleted_at IS NULL"
        let sql = makeRankedNoteIDsSQL(deletedPredicate: deletedPredicate, includeFTS: plan.ftsQuery != nil)

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            PerformanceTelemetry.mark("search_index.query_prepare_failed")
            sqlite3_finalize(stmt)
            throw sqliteError(operation: "prepare search", db: db)
        }
        defer { sqlite3_finalize(stmt) }

        bindSearchParameters(
            stmt: stmt,
            userId: userId,
            phrase: plan.foldedPhrase,
            ftsQuery: plan.ftsQuery,
            limit: limit,
            offset: offset
        )

        var ids: [UUID] = []
        ids.reserveCapacity(limit)
        while true {
            let result = sqlite3_step(stmt)
            if result == SQLITE_DONE {
                break
            }
            guard result == SQLITE_ROW else {
                throw sqliteError(operation: "execute search", db: db)
            }
            if let cString = sqlite3_column_text(stmt, 0),
               let id = UUID(uuidString: String(cString: cString)) {
                ids.append(id)
            }
        }
        return ids
    }

    func countMatches(userId: String, query: String, includeDeleted: Bool) throws -> Int {
        try openIfNeeded()
        guard let db else {
            throw NotesSearchIndexError.sqlite(operation: "open", code: SQLITE_CANTOPEN, message: "Database handle is unavailable")
        }
        guard let plan = SearchQueryPlan(query: query) else {
            return 0
        }
        let deletedPredicate = includeDeleted ? "deleted_at IS NOT NULL" : "deleted_at IS NULL"
        let sql = makeCountSQL(deletedPredicate: deletedPredicate, includeFTS: plan.ftsQuery != nil)

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            sqlite3_finalize(stmt)
            throw sqliteError(operation: "prepare result count", db: db)
        }
        defer { sqlite3_finalize(stmt) }

        bindCountParameters(
            stmt: stmt,
            userId: userId,
            phrase: plan.foldedPhrase,
            ftsQuery: plan.ftsQuery
        )

        let result = sqlite3_step(stmt)
        guard result == SQLITE_ROW else {
            if result == SQLITE_DONE { return 0 }
            throw sqliteError(operation: "count search results", db: db)
        }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    func needsRebuild() throws -> Bool {
        try openIfNeeded()
        return requiresRebuildAfterMigration
    }

    private func openIfNeeded() throws {
        if db != nil {
            return
        }

        do {
            let url: URL
            if let databaseURLOverride {
                url = databaseURLOverride
            } else {
                let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                let directory = root.appendingPathComponent("ChillScript", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                url = directory.appendingPathComponent("note_search.sqlite", isDirectory: false)
            }
            if sqlite3_open(url.path, &db) != SQLITE_OK {
                let error = sqliteError(operation: "open", db: db)
                if let db {
                    sqlite3_close(db)
                }
                db = nil
                PerformanceTelemetry.mark("search_index.open_failed")
                throw error
            }

            guard let db else {
                throw NotesSearchIndexError.sqlite(operation: "open", code: SQLITE_CANTOPEN, message: "Database handle is unavailable")
            }
            try execute("PRAGMA journal_mode=WAL;", operation: "configure journal mode", db: db)
            try execute("PRAGMA synchronous=NORMAL;", operation: "configure synchronous mode", db: db)

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
                content_folded TEXT NOT NULL,
                tags_folded TEXT NOT NULL,
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
                deleted_at UNINDEXED,
                tokenize = 'unicode61 remove_diacritics 2',
                prefix = '2 3 4 5 6'
            );
            """
            try execute(createMeta, operation: "create metadata table", db: db)

            let currentVersion = readSchemaVersion(db: db)
            if currentVersion != schemaVersion {
                try execute("DROP TABLE IF EXISTS note_fts;", operation: "drop old full-text table", db: db)
                try execute("DROP TABLE IF EXISTS note_index;", operation: "drop old index table", db: db)
                requiresRebuildAfterMigration = true
            }

            try execute(createIndex, operation: "create index table", db: db)
            try execute(createFTS, operation: "create full-text table", db: db)

            let setVersion = "INSERT INTO index_meta(k, v) VALUES('schema_version', ?) ON CONFLICT(k) DO UPDATE SET v=excluded.v;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, setVersion, -1, &stmt, nil) == SQLITE_OK else {
                sqlite3_finalize(stmt)
                throw sqliteError(operation: "prepare schema version", db: db)
            }
            bindText(stmt, index: 1, value: "\(schemaVersion)")
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                sqlite3_finalize(stmt)
                throw sqliteError(operation: "write schema version", db: db)
            }
            sqlite3_finalize(stmt)
        } catch {
            if let db {
                sqlite3_close(db)
                self.db = nil
            }
            PerformanceTelemetry.mark("search_index.open_exception", detail: error.localizedDescription)
            throw error
        }
    }

    private func execute(_ sql: String, operation: String, db: OpaquePointer) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw sqliteError(operation: operation, db: db)
        }
    }

    private func sqliteError(operation: String, db: OpaquePointer?) -> NotesSearchIndexError {
        let code = db.map(sqlite3_errcode) ?? SQLITE_ERROR
        let message = db.flatMap(sqlite3_errmsg).map(String.init(cString:)) ?? "Unknown SQLite error"
        return .sqlite(operation: operation, code: code, message: message)
    }

    private func readSchemaVersion(db: OpaquePointer) -> Int {
        let sql = "SELECT v FROM index_meta WHERE k = 'schema_version' LIMIT 1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            sqlite3_finalize(stmt)
            return 0
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW, let raw = sqlite3_column_text(stmt, 0) else {
            return 0
        }
        return Int(String(cString: raw)) ?? 0
    }

    private func makeRankedNoteIDsSQL(deletedPredicate: String, includeFTS: Bool) -> String {
        """
        WITH candidates AS (
            SELECT note_id, updated_at,
                   1100.0 + CASE
                       WHEN instr(content_folded, ?) = 1 THEN 140.0
                       ELSE max(0.0, 80.0 - CAST(instr(content_folded, ?) AS REAL))
                   END AS score
            FROM note_index
            WHERE user_id = ? AND \(deletedPredicate) AND instr(content_folded, ?) > 0

            UNION ALL

            SELECT note_id, updated_at,
                   900.0 + CASE
                       WHEN instr(tags_folded, ?) = 1 THEN 100.0
                       ELSE max(0.0, 50.0 - CAST(instr(tags_folded, ?) AS REAL))
                   END AS score
            FROM note_index
            WHERE user_id = ? AND \(deletedPredicate) AND instr(tags_folded, ?) > 0
            \(includeFTS ? """

            UNION ALL

            SELECT ni.note_id, ni.updated_at,
                   700.0 - (bm25(note_fts, 6.0, 3.0) * 10.0) AS score
            FROM note_fts
            JOIN note_index ni ON ni.note_id = note_fts.note_id
            WHERE ni.user_id = ? AND ni.\(deletedPredicate) AND note_fts MATCH ?
            """ : "")
        )
        SELECT note_id
        FROM (
            SELECT note_id, MAX(score) AS best_score, MAX(updated_at) AS latest_updated_at
            FROM candidates
            GROUP BY note_id
        )
        ORDER BY best_score DESC, latest_updated_at DESC, note_id DESC
        LIMIT ? OFFSET ?;
        """
    }

    private func makeCountSQL(deletedPredicate: String, includeFTS: Bool) -> String {
        """
        WITH candidates AS (
            SELECT note_id
            FROM note_index
            WHERE instr(content_folded, ?) > 0 AND user_id = ? AND \(deletedPredicate)

            UNION

            SELECT note_id
            FROM note_index
            WHERE instr(tags_folded, ?) > 0 AND user_id = ? AND \(deletedPredicate)
            \(includeFTS ? """

            UNION

            SELECT ni.note_id
            FROM note_fts
            JOIN note_index ni ON ni.note_id = note_fts.note_id
            WHERE ni.user_id = ? AND ni.\(deletedPredicate) AND note_fts MATCH ?
            """ : "")
        )
        SELECT COUNT(*)
        FROM candidates;
        """
    }

    private func bindSearchParameters(
        stmt: OpaquePointer?,
        userId: String,
        phrase: String,
        ftsQuery: String?,
        limit: Int?,
        offset: Int?
    ) {
        var index: Int32 = 1

        bindText(stmt, index: index, value: phrase)
        index += 1
        bindText(stmt, index: index, value: phrase)
        index += 1
        bindText(stmt, index: index, value: userId)
        index += 1
        bindText(stmt, index: index, value: phrase)
        index += 1

        bindText(stmt, index: index, value: phrase)
        index += 1
        bindText(stmt, index: index, value: phrase)
        index += 1
        bindText(stmt, index: index, value: userId)
        index += 1
        bindText(stmt, index: index, value: phrase)
        index += 1

        if let ftsQuery {
            bindText(stmt, index: index, value: userId)
            index += 1
            bindText(stmt, index: index, value: ftsQuery)
            index += 1
        }

        if let limit {
            sqlite3_bind_int(stmt, index, Int32(limit))
            index += 1
        }

        if let offset {
            sqlite3_bind_int(stmt, index, Int32(offset))
        }
    }

    private func bindCountParameters(
        stmt: OpaquePointer?,
        userId: String,
        phrase: String,
        ftsQuery: String?
    ) {
        var index: Int32 = 1

        bindText(stmt, index: index, value: phrase)
        index += 1
        bindText(stmt, index: index, value: userId)
        index += 1

        bindText(stmt, index: index, value: phrase)
        index += 1
        bindText(stmt, index: index, value: userId)
        index += 1

        if let ftsQuery {
            bindText(stmt, index: index, value: userId)
            index += 1
            bindText(stmt, index: index, value: ftsQuery)
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
        do {
            if try await index.needsRebuild() {
                await rebuildAll(context: context, userId: userId)
                return
            }

            if getLastIndexedAt(userId: userId).timeIntervalSince1970 > 0 {
                await syncIncremental(context: context, userId: userId)
                return
            }

            await rebuildAll(context: context, userId: userId)
        } catch {
            PerformanceTelemetry.mark("search_index.availability_failed", detail: error.localizedDescription)
        }
    }

    private func rebuildAll(context: ModelContext, userId: String) async {
        let start = PerformanceTelemetry.begin("search_index.rebuild")
        do {
            var descriptor = FetchDescriptor<Note>()
            descriptor.predicate = #Predicate<Note> { note in
                note.userId == userId
            }
            let notes = try context.fetch(descriptor)
            let docs = notes.map(makeDocument)
            try await index.upsert(documents: docs)
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
                try await index.upsert(documents: changed.map(makeDocument))
            }
            setLastIndexedAt(Date(), userId: userId)
            PerformanceTelemetry.end("search_index.incremental", from: start, extra: "count=\(changed.count)")
        } catch {
            PerformanceTelemetry.mark("search_index.incremental_failed", detail: error.localizedDescription)
        }
    }

    func remove(noteIDs: [UUID]) async {
        do {
            try await index.remove(noteIDs: noteIDs)
        } catch {
            PerformanceTelemetry.mark("search_index.remove_failed", detail: error.localizedDescription)
        }
    }

    func searchNoteIDs(userId: String, query: String, includeDeleted: Bool, offset: Int, limit: Int) async throws -> [UUID] {
        try await index.searchNoteIDs(userId: userId, query: query, includeDeleted: includeDeleted, offset: offset, limit: limit)
    }

    func countMatches(userId: String, query: String, includeDeleted: Bool) async throws -> Int {
        try await index.countMatches(userId: userId, query: query, includeDeleted: includeDeleted)
    }

    private func makeDocument(note: Note) -> NoteSearchDocument {
        let sourceSearchText = [
            note.sourcePlatformName,
            note.sourceHost,
            note.sourceTitle,
            note.sourceAuthorName,
            note.sourceAuthorHandle
        ]
            .compactMap { $0 }
            .joined(separator: " ")
        let normalizedContent = NoteTextNormalizer.normalizeContent([note.content, sourceSearchText].joined(separator: " "))
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

private struct SearchQueryPlan {
    let foldedPhrase: String
    let ftsQuery: String?

    init?(query: String) {
        let normalized = NoteTextNormalizer.normalizeQuery(query)
        let folded = NoteTextNormalizer.foldForSearch(normalized)
        guard !folded.isEmpty else {
            return nil
        }

        foldedPhrase = folded

        let latinTokens = folded
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }
            .compactMap(SearchQueryPlan.makeFTSToken)

        ftsQuery = latinTokens.isEmpty ? nil : latinTokens.joined(separator: " AND ")
    }

    private static func makeFTSToken(_ token: String) -> String? {
        let filtered = token.filter { character in
            character.isLetter || character.isNumber
        }
        guard !filtered.isEmpty else {
            return nil
        }
        return "\(filtered)*"
    }
}
