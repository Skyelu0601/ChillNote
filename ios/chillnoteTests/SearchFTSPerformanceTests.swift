import XCTest
@testable import chillnote

final class SearchFTSPerformanceTests: XCTestCase {
    func testSearchFromFiveThousandIndexedDocs() {
        let index = SQLiteFTSNotesSearchIndex()
        let userId = "perf-user-\(UUID().uuidString)"

        let docs: [NoteSearchDocument] = (0..<5_000).map { idx in
            NoteSearchDocument(
                noteId: UUID(),
                userId: userId,
                contentPlain: "project plan sprint \(idx)",
                tagsPlain: idx % 2 == 0 ? "work" : "personal",
                updatedAt: Date().timeIntervalSince1970,
                deletedAt: nil
            )
        }

        let setup = expectation(description: "setup")
        Task {
            await index.upsert(documents: docs)
            setup.fulfill()
        }
        wait(for: [setup], timeout: 30)

        measure {
            let exp = expectation(description: "search")
            Task {
                _ = await index.searchNoteIDs(userId: userId, query: "sprint", includeDeleted: false, offset: 0, limit: 50)
                exp.fulfill()
            }
            wait(for: [exp], timeout: 2)
        }

        let cleanup = expectation(description: "cleanup")
        Task {
            await index.remove(noteIDs: docs.map { $0.noteId })
            cleanup.fulfill()
        }
        wait(for: [cleanup], timeout: 30)
    }
}
