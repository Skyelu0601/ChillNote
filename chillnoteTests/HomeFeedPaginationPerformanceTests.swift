import XCTest
import SwiftData
@testable import chillnote

@MainActor
final class HomeFeedPaginationPerformanceTests: XCTestCase {
    func testFetchFirstPageFromFiveThousandNotes() throws {
        let schema = Schema([Note.self, Tag.self, ChecklistItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        let repository = SwiftDataNotesRepository(contextProvider: { context })

        for index in 0..<5_000 {
            let note = Note(content: "note \(index)", userId: "u1")
            note.createdAt = Date(timeIntervalSince1970: TimeInterval(1_700_000_000 + index))
            context.insert(note)
        }
        try context.save()

        measure {
            let exp = expectation(description: "page")
            Task { @MainActor in
                _ = try? await repository.fetchPage(userId: "u1", mode: .active, tagId: nil, cursor: nil, limit: 50)
                exp.fulfill()
            }
            wait(for: [exp], timeout: 3)
        }
    }
}
