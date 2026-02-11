import Foundation
import SwiftData

enum NotesFeedMode: Equatable {
    case active
    case trash
}

struct NotesPage {
    let items: [Note]
    let nextCursor: Int?
    let total: Int
}

@MainActor
protocol NotesRepository {
    func fetchPage(userId: String, mode: NotesFeedMode, tagId: UUID?, cursor: Int?, limit: Int) async throws -> NotesPage
    func searchPage(userId: String, query: String, mode: NotesFeedMode, tagId: UUID?, cursor: Int?, limit: Int) async throws -> NotesPage
    func count(userId: String, mode: NotesFeedMode, tagId: UUID?, query: String?) async throws -> Int
    func fetchByIDs(userId: String, ids: [UUID]) async throws -> [Note]
}

@MainActor
final class SwiftDataNotesRepository: NotesRepository {
    private let contextProvider: () -> ModelContext?

    init(contextProvider: @escaping () -> ModelContext?) {
        self.contextProvider = contextProvider
    }

    func fetchPage(userId: String, mode: NotesFeedMode, tagId: UUID?, cursor: Int?, limit: Int) async throws -> NotesPage {
        guard let context = contextProvider() else {
            return NotesPage(items: [], nextCursor: nil, total: 0)
        }

        let total = try await count(userId: userId, mode: mode, tagId: tagId, query: nil)
        let startOffset = cursor ?? 0
        guard total > startOffset else {
            return NotesPage(items: [], nextCursor: nil, total: total)
        }

        if let tagId {
            return try fetchPageWithTagFilter(context: context, userId: userId, mode: mode, tagId: tagId, startOffset: startOffset, limit: limit, total: total)
        }

        var descriptor = FetchDescriptor<Note>(sortBy: sortDescriptors())
        descriptor.fetchOffset = startOffset
        descriptor.fetchLimit = limit
        descriptor.predicate = basePredicate(userId: userId, mode: mode)

        let items = try context.fetch(descriptor)
        let nextOffset = startOffset + items.count
        return NotesPage(items: items, nextCursor: nextOffset < total ? nextOffset : nil, total: total)
    }

    func searchPage(userId: String, query: String, mode: NotesFeedMode, tagId: UUID?, cursor: Int?, limit: Int) async throws -> NotesPage {
        guard let context = contextProvider() else {
            return NotesPage(items: [], nextCursor: nil, total: 0)
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return try await fetchPage(userId: userId, mode: mode, tagId: tagId, cursor: cursor, limit: limit)
        }

        let includeDeleted = mode == .trash
        let startOffset = cursor ?? 0

        if FeatureFlags.useLocalFTSSearch {
            var collected: [Note] = []
            var searchOffset = startOffset
            let chunkSize = max(limit * 2, 50)
            let total = await NotesSearchIndexer.shared.countMatches(userId: userId, query: trimmed, includeDeleted: includeDeleted)

            while collected.count < limit {
                let ids = await NotesSearchIndexer.shared.searchNoteIDs(
                    userId: userId,
                    query: trimmed,
                    includeDeleted: includeDeleted,
                    offset: searchOffset,
                    limit: chunkSize
                )
                if ids.isEmpty {
                    break
                }

                let fetched = try await fetchByIDs(userId: userId, ids: ids)
                let filtered: [Note]
                if let tagId {
                    filtered = fetched.filter { note in
                        note.tags.contains(where: { $0.id == tagId })
                    }
                } else {
                    filtered = fetched
                }
                collected.append(contentsOf: filtered)
                searchOffset += ids.count

                if ids.count < chunkSize {
                    break
                }
            }

            let finalItems = Array(collected.prefix(limit))
            let nextCursor = searchOffset < max(total, startOffset + finalItems.count) ? searchOffset : nil
            return NotesPage(items: finalItems, nextCursor: nextCursor, total: max(total, finalItems.count))
        }

        PerformanceTelemetry.mark("search.fts_fallback")
        return try fallbackSearchPage(context: context, userId: userId, query: trimmed, mode: mode, tagId: tagId, startOffset: startOffset, limit: limit)
    }

    func count(userId: String, mode: NotesFeedMode, tagId: UUID?, query: String?) async throws -> Int {
        guard let context = contextProvider() else { return 0 }

        if let query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, FeatureFlags.useLocalFTSSearch, tagId == nil {
            return await NotesSearchIndexer.shared.countMatches(
                userId: userId,
                query: query,
                includeDeleted: mode == .trash
            )
        }

        var descriptor = FetchDescriptor<Note>()
        descriptor.predicate = basePredicate(userId: userId, mode: mode)

        if tagId == nil, query == nil || query?.isEmpty == true {
            return try context.fetchCount(descriptor)
        }

        let notes = try context.fetch(descriptor)
        return notes.filter { note in
            let passesTag: Bool
            if let tagId {
                passesTag = note.tags.contains(where: { $0.id == tagId })
            } else {
                passesTag = true
            }

            let passesQuery: Bool
            if let query, !query.isEmpty {
                passesQuery = note.content.localizedCaseInsensitiveContains(query) || note.tags.contains { $0.name.localizedCaseInsensitiveContains(query) }
            } else {
                passesQuery = true
            }
            return passesTag && passesQuery
        }.count
    }

    func fetchByIDs(userId: String, ids: [UUID]) async throws -> [Note] {
        guard let context = contextProvider(), !ids.isEmpty else { return [] }

        var descriptor = FetchDescriptor<Note>()
        descriptor.predicate = #Predicate<Note> { note in
            note.userId == userId && ids.contains(note.id)
        }

        let fetched = try context.fetch(descriptor)
        let map = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
        return ids.compactMap { map[$0] }
    }

    private func fetchPageWithTagFilter(
        context: ModelContext,
        userId: String,
        mode: NotesFeedMode,
        tagId: UUID,
        startOffset: Int,
        limit: Int,
        total: Int
    ) throws -> NotesPage {
        let chunk = max(limit * 2, 100)
        var scanOffset = startOffset
        var result: [Note] = []

        while result.count < limit {
            var descriptor = FetchDescriptor<Note>(sortBy: sortDescriptors())
            descriptor.fetchOffset = scanOffset
            descriptor.fetchLimit = chunk
            descriptor.predicate = basePredicate(userId: userId, mode: mode)

            let batch = try context.fetch(descriptor)
            if batch.isEmpty {
                break
            }

            let filtered = batch.filter { note in
                note.tags.contains(where: { $0.id == tagId })
            }
            result.append(contentsOf: filtered)
            scanOffset += batch.count

            if batch.count < chunk {
                break
            }
        }

        let finalItems = Array(result.prefix(limit))
        return NotesPage(items: finalItems, nextCursor: scanOffset < total ? scanOffset : nil, total: total)
    }

    private func fallbackSearchPage(
        context: ModelContext,
        userId: String,
        query: String,
        mode: NotesFeedMode,
        tagId: UUID?,
        startOffset: Int,
        limit: Int
    ) throws -> NotesPage {
        var descriptor = FetchDescriptor<Note>(sortBy: sortDescriptors())
        descriptor.predicate = basePredicate(userId: userId, mode: mode)
        let notes = try context.fetch(descriptor)

        let filtered = notes.filter { note in
            let tagPass: Bool
            if let tagId {
                tagPass = note.tags.contains(where: { $0.id == tagId })
            } else {
                tagPass = true
            }

            let queryPass = note.content.localizedCaseInsensitiveContains(query) || note.tags.contains { $0.name.localizedCaseInsensitiveContains(query) }
            return tagPass && queryPass
        }

        let end = min(filtered.count, startOffset + limit)
        guard startOffset < end else {
            return NotesPage(items: [], nextCursor: nil, total: filtered.count)
        }

        let page = Array(filtered[startOffset..<end])
        let nextCursor = end < filtered.count ? end : nil
        return NotesPage(items: page, nextCursor: nextCursor, total: filtered.count)
    }

    private func basePredicate(userId: String, mode: NotesFeedMode) -> Predicate<Note> {
        switch mode {
        case .active:
            return #Predicate<Note> { note in
                note.userId == userId && note.deletedAt == nil
            }
        case .trash:
            return #Predicate<Note> { note in
                note.userId == userId && note.deletedAt != nil
            }
        }
    }

    private func sortDescriptors() -> [SortDescriptor<Note>] {
        [
            SortDescriptor(\Note.pinnedAt, order: .reverse),
            SortDescriptor(\Note.createdAt, order: .reverse),
            SortDescriptor(\Note.id, order: .reverse)
        ]
    }
}
