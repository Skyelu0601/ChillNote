import XCTest
import SwiftData
@testable import chillnote

@MainActor
final class SharedImportQueueTests: XCTestCase {
    func testAdoptionWaitsForSyncWithoutUploadingOrDuplicatingPlaceholder() throws {
        for status in ["queued", "processing", "completed", "failed"] {
            let container = try makeContainer()
            let context = container.mainContext
            let item = makeItem(status: status)
            let note = try SharedImportQueue.adoptStartedLinkImport(item, context: context)
            let again = try SharedImportQueue.adoptStartedLinkImport(item, context: context)
            XCTAssertEqual(note.id, item.id)
            XCTAssertEqual(again.id, note.id)
            XCTAssertEqual(note.section, .inbox)
            XCTAssertTrue(note.isLinkImportInProgress)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<Note>()), 1)
            let payload = try SyncEngine().makePayload(
                context: context, since: nil, userId: "u1", cursor: "1", deviceId: "device",
                hardDeletedNoteIds: [], hardDeletedTagIds: []
            )
            XCTAssertTrue(payload.notes.isEmpty, "Adoption must not upload an independent placeholder mutation")
        }
    }

    func testOldShareQueueDoesNotRegressDownloadedCompletion() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let item = makeItem(status: "queued")
        let completed = Note(content: "Finished transcript with user edits", userId: "u1")
        completed.id = item.id
        completed.importStatus = .completed
        completed.importJobId = item.importJobId
        completed.section = .drafts
        completed.sourceTitle = "Updated title"
        context.insert(completed)
        try context.save()

        let adopted = try SharedImportQueue.adoptStartedLinkImport(item, context: context)
        XCTAssertEqual(adopted.content, "Finished transcript with user edits")
        XCTAssertEqual(adopted.importStatus, .completed)
        XCTAssertEqual(adopted.section, .drafts)
        XCTAssertEqual(adopted.sourceTitle, "Updated title")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Note>()), 1)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Note.self, Tag.self, ChecklistItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeItem(status: String) -> SharedImportQueue.PendingImport {
        .init(
            id: UUID(), kind: .linkImport, noteText: nil,
            source: .init(url: "https://www.tiktok.com/@creator/video/123", title: "TikTok",
                          platformID: "tiktok", platformName: "TikTok", host: "www.tiktok.com",
                          authorName: nil, authorHandle: nil),
            importJobId: "job-1", importStatus: status, createdAt: Date(), userId: "u1"
        )
    }
}
