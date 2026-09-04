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
            defer { setup.fulfill() }
            do {
                try await index.upsert(documents: docs)
            } catch {
                XCTFail("Failed to prepare search index: \(error)")
            }
        }
        wait(for: [setup], timeout: 30)

        measure {
            let exp = expectation(description: "search")
            Task {
                defer { exp.fulfill() }
                do {
                    _ = try await index.searchNoteIDs(userId: userId, query: "sprint", includeDeleted: false, offset: 0, limit: 50)
                } catch {
                    XCTFail("Search failed: \(error)")
                }
            }
            wait(for: [exp], timeout: 2)
        }

        let cleanup = expectation(description: "cleanup")
        Task {
            defer { cleanup.fulfill() }
            do {
                try await index.remove(noteIDs: docs.map { $0.noteId })
            } catch {
                XCTFail("Failed to clean up search index: \(error)")
            }
        }
        wait(for: [cleanup], timeout: 30)
    }
}
