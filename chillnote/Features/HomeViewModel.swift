import Foundation
import SwiftData

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var items: [Note] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var hasMore: Bool = true
    @Published private(set) var totalCount: Int = 0

    @Published var query: String = ""
    @Published var mode: NotesFeedMode = .active
    @Published var selectedTagId: UUID?

    private var cursor: Int?
    private let pageSize: Int
    private var userId: String?
    private var repository: NotesRepository?
    private var reloadTask: Task<Void, Never>?

    init(pageSize: Int = FeatureFlags.usePagedHomeFeed ? 50 : 5_000) {
        self.pageSize = pageSize
    }

    func configure(context: ModelContext, userId: String) {
        let shouldReset = self.userId != userId || repository == nil
        self.userId = userId
        self.repository = SwiftDataNotesRepository(contextProvider: { context })

        if shouldReset {
            resetPagination()
        }
    }

    func switchMode(_ mode: NotesFeedMode) async {
        guard self.mode != mode else { return }
        self.mode = mode
        await reload()
    }

    func switchTag(_ tagId: UUID?) async {
        guard selectedTagId != tagId else { return }
        selectedTagId = tagId
        await reload()
    }

    func updateSearchQuery(_ value: String) async {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query != normalized else { return }
        query = normalized
        await reload()
    }

    func scheduleDebouncedSearchUpdate(_ value: String, delayNanoseconds: UInt64 = 150_000_000) {
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: delayNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            guard let self else { return }
            await self.updateSearchQuery(value)
        }
    }

    func reload() async {
        guard let repository, let userId else { return }

        let startedAt = PerformanceTelemetry.begin(query.isEmpty ? "home_feed.reload" : "home_feed.search_reload")
        isLoading = true
        defer { isLoading = false }

        resetPagination(keepItems: false)
        do {
            let page: NotesPage
            if query.isEmpty {
                page = try await repository.fetchPage(
                    userId: userId,
                    mode: mode,
                    tagId: selectedTagId,
                    cursor: nil,
                    limit: pageSize
                )
            } else {
                page = try await repository.searchPage(
                    userId: userId,
                    query: query,
                    mode: mode,
                    tagId: selectedTagId,
                    cursor: nil,
                    limit: pageSize
                )
            }

            items = page.items
            cursor = page.nextCursor
            hasMore = page.nextCursor != nil
            totalCount = page.total
            PerformanceTelemetry.end(query.isEmpty ? "home_feed.reload" : "home_feed.search_reload", from: startedAt, extra: "count=\(items.count)")
        } catch {
            PerformanceTelemetry.mark("home_feed.reload_failed", detail: error.localizedDescription)
            items = []
            cursor = nil
            hasMore = false
            totalCount = 0
        }
    }

    func loadMoreIfNeeded(currentItem: Note) {
        guard hasMore, !isLoading, items.last?.id == currentItem.id else { return }
        Task { await loadMore() }
    }

    func loadMore() async {
        guard let repository, let userId, hasMore, !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        let startedAt = PerformanceTelemetry.begin("home_feed.load_more")

        do {
            let page: NotesPage
            if query.isEmpty {
                page = try await repository.fetchPage(
                    userId: userId,
                    mode: mode,
                    tagId: selectedTagId,
                    cursor: cursor,
                    limit: pageSize
                )
            } else {
                page = try await repository.searchPage(
                    userId: userId,
                    query: query,
                    mode: mode,
                    tagId: selectedTagId,
                    cursor: cursor,
                    limit: pageSize
                )
            }

            cursor = page.nextCursor
            hasMore = page.nextCursor != nil
            totalCount = page.total
            items.append(contentsOf: page.items)
            PerformanceTelemetry.end("home_feed.load_more", from: startedAt, extra: "append=\(page.items.count)")
        } catch {
            hasMore = false
            PerformanceTelemetry.mark("home_feed.load_more_failed", detail: error.localizedDescription)
        }
    }

    func note(with id: UUID) -> Note? {
        items.first(where: { $0.id == id })
    }

    private func resetPagination(keepItems: Bool = false) {
        cursor = nil
        hasMore = true
        totalCount = 0
        if !keepItems {
            items = []
        }
    }
}
