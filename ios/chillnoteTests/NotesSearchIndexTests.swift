import XCTest
@testable import chillnote

final class NotesSearchIndexTests: XCTestCase {
    func testFTSUpsertAndSearchAndDeleteFilter() async {
        let index = SQLiteFTSNotesSearchIndex()
        let userId = "test-user-\(UUID().uuidString)"

        let id1 = UUID()
        let id2 = UUID()

        await index.upsert(documents: [
            NoteSearchDocument(
                noteId: id1,
                userId: userId,
                contentPlain: "apple banana",
                tagsPlain: "fruit",
                updatedAt: Date().timeIntervalSince1970,
                deletedAt: nil
            ),
            NoteSearchDocument(
                noteId: id2,
                userId: userId,
                contentPlain: "apple deleted",
                tagsPlain: "archive",
                updatedAt: Date().timeIntervalSince1970,
                deletedAt: Date().timeIntervalSince1970
            )
        ])

        let active = await index.searchNoteIDs(userId: userId, query: "apple", includeDeleted: false, offset: 0, limit: 10)
        XCTAssertTrue(active.contains(id1))
        XCTAssertFalse(active.contains(id2))

        let deleted = await index.searchNoteIDs(userId: userId, query: "apple", includeDeleted: true, offset: 0, limit: 10)
        XCTAssertTrue(deleted.contains(id2))

        let countActive = await index.countMatches(userId: userId, query: "apple", includeDeleted: false)
        XCTAssertGreaterThanOrEqual(countActive, 1)

        await index.remove(noteIDs: [id1, id2])
        let afterRemove = await index.searchNoteIDs(userId: userId, query: "apple", includeDeleted: true, offset: 0, limit: 10)
        XCTAssertFalse(afterRemove.contains(id1))
        XCTAssertFalse(afterRemove.contains(id2))
    }

    func testSearchSupportsCJKFragmentsLatinPrefixesAndAccentInsensitiveRanking() async {
        let index = SQLiteFTSNotesSearchIndex()
        let userId = "search-user-\(UUID().uuidString)"

        let cjkID = UUID()
        let accentID = UUID()
        let prefixID = UUID()
        await index.upsert(documents: [
            NoteSearchDocument(
                noteId: cjkID,
                userId: userId,
                contentPlain: "今天要去东京塔散步",
                tagsPlain: "旅行",
                updatedAt: Date().timeIntervalSince1970,
                deletedAt: nil
            ),
            NoteSearchDocument(
                noteId: accentID,
                userId: userId,
                contentPlain: "Let's meet at the cafe after lunch",
                tagsPlain: "coffee",
                updatedAt: Date().timeIntervalSince1970 + 1,
                deletedAt: nil
            ),
            NoteSearchDocument(
                noteId: prefixID,
                userId: userId,
                contentPlain: "Project planning checklist for spring launch",
                tagsPlain: "work",
                updatedAt: Date().timeIntervalSince1970 + 2,
                deletedAt: nil
            )
        ])

        let cjkMatches = await index.searchNoteIDs(userId: userId, query: "东京", includeDeleted: false, offset: 0, limit: 10)
        XCTAssertEqual(cjkMatches.first, cjkID)

        let accentMatches = await index.searchNoteIDs(userId: userId, query: "café", includeDeleted: false, offset: 0, limit: 10)
        XCTAssertEqual(accentMatches.first, accentID)

        let prefixMatches = await index.searchNoteIDs(userId: userId, query: "plan", includeDeleted: false, offset: 0, limit: 10)
        XCTAssertEqual(prefixMatches.first, prefixID)
    }
}
