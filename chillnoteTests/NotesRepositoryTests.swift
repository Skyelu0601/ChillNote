import XCTest
import SwiftData
@testable import chillnote

@MainActor
final class NotesRepositoryTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var repository: SwiftDataNotesRepository!

    override func setUpWithError() throws {
        let schema = Schema([Note.self, Tag.self, ChecklistItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
        repository = SwiftDataNotesRepository(contextProvider: { [weak self] in
            self?.context
        })

        UserDefaults.standard.set(false, forKey: "useLocalFTSSearch")
    }

    override func tearDownWithError() throws {
        UserDefaults.standard.removeObject(forKey: "useLocalFTSSearch")
        repository = nil
        context = nil
        container = nil
    }

    func testFetchPagePaginatesActiveNotes() async throws {
        for index in 0..<120 {
            let note = Note(content: "note-\(index)", userId: "u1")
            note.createdAt = Date(timeIntervalSince1970: TimeInterval(1_700_000_000 + index))
            context.insert(note)
        }
        try context.save()

        let first = try await repository.fetchPage(userId: "u1", mode: .active, tagId: nil, cursor: nil, limit: 50)
        XCTAssertEqual(first.items.count, 50)
        XCTAssertEqual(first.total, 120)
        XCTAssertEqual(first.nextCursor, 50)

        let second = try await repository.fetchPage(userId: "u1", mode: .active, tagId: nil, cursor: first.nextCursor, limit: 50)
        XCTAssertEqual(second.items.count, 50)
        XCTAssertEqual(second.nextCursor, 100)

        let third = try await repository.fetchPage(userId: "u1", mode: .active, tagId: nil, cursor: second.nextCursor, limit: 50)
        XCTAssertEqual(third.items.count, 20)
        XCTAssertNil(third.nextCursor)
    }

    func testFetchPagePinnedNotesFirst() async throws {
        let oldPinned = Note(content: "pinned-old", userId: "u1")
        oldPinned.createdAt = Date(timeIntervalSince1970: 100)
        oldPinned.pinnedAt = Date(timeIntervalSince1970: 1_000)

        let newUnpinned = Note(content: "new-unpinned", userId: "u1")
        newUnpinned.createdAt = Date(timeIntervalSince1970: 500)

        context.insert(oldPinned)
        context.insert(newUnpinned)
        try context.save()

        let page = try await repository.fetchPage(userId: "u1", mode: .active, tagId: nil, cursor: nil, limit: 10)
        XCTAssertEqual(page.items.first?.id, oldPinned.id)
    }

    func testSearchPageFallbackContainsAndTagFilter() async throws {
        let tag = Tag(name: "Work", userId: "u1")
        let note1 = Note(content: "meeting summary", userId: "u1")
        note1.tags.append(tag)
        let note2 = Note(content: "meeting private", userId: "u1")

        context.insert(tag)
        context.insert(note1)
        context.insert(note2)
        try context.save()

        let page = try await repository.searchPage(
            userId: "u1",
            query: "meeting",
            mode: .active,
            tagId: tag.id,
            cursor: nil,
            limit: 50
        )

        XCTAssertEqual(page.items.count, 1)
        XCTAssertEqual(page.items.first?.id, note1.id)
    }

    func testFetchPageWithTagFilterPaginatesByMatchedOffset() async throws {
        let tag = Tag(name: "Project", userId: "u1")
        context.insert(tag)

        var taggedNotes: [Note] = []
        for index in 0..<30 {
            let note = Note(content: "note-\(index)", userId: "u1")
            note.createdAt = Date(timeIntervalSince1970: TimeInterval(1_700_000_000 + index))
            if index % 6 == 0 {
                note.tags.append(tag)
                taggedNotes.append(note)
            }
            context.insert(note)
        }
        try context.save()

        let expectedTaggedCount = taggedNotes.count
        XCTAssertEqual(expectedTaggedCount, 5)

        let first = try await repository.fetchPage(userId: "u1", mode: .active, tagId: tag.id, cursor: nil, limit: 2)
        XCTAssertEqual(first.items.count, 2)
        XCTAssertEqual(first.total, expectedTaggedCount)
        XCTAssertEqual(first.nextCursor, 2)

        let second = try await repository.fetchPage(userId: "u1", mode: .active, tagId: tag.id, cursor: first.nextCursor, limit: 2)
        XCTAssertEqual(second.items.count, 2)
        XCTAssertEqual(second.total, expectedTaggedCount)
        XCTAssertEqual(second.nextCursor, 4)

        let third = try await repository.fetchPage(userId: "u1", mode: .active, tagId: tag.id, cursor: second.nextCursor, limit: 2)
        XCTAssertEqual(third.items.count, 1)
        XCTAssertEqual(third.total, expectedTaggedCount)
        XCTAssertNil(third.nextCursor)
    }
}
