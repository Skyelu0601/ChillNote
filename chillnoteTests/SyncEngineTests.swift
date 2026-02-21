import XCTest
import SwiftData
@testable import chillnote

@MainActor
final class SyncEngineTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private let engine = SyncEngine()

    override func setUpWithError() throws {
        let schema = Schema([Note.self, Tag.self, ChecklistItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
    }

    func testApplyRemoteDoesNotReviveLocallyDeletedNoteWhenVersionIsEqual() throws {
        let userId = "u1"
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let localDeleteAt = base.addingTimeInterval(90)
        let remoteUpdateAt = base.addingTimeInterval(180)

        let note = Note(content: "local", userId: userId)
        note.version = 3
        note.createdAt = base
        note.serverUpdatedAt = base
        note.updatedAt = base
        context.insert(note)
        try context.save()

        note.deletedAt = localDeleteAt
        note.updatedAt = localDeleteAt
        try context.save()

        let response = SyncResponse(
            cursor: "1",
            changes: SyncChanges(
                notes: [
                    NoteDTO(
                        id: note.id.uuidString,
                        content: "remote",
                        createdAt: iso(base),
                        updatedAt: iso(remoteUpdateAt),
                        deletedAt: nil,
                        pinnedAt: nil,
                        tagIds: [],
                        version: 3,
                        baseVersion: nil,
                        clientUpdatedAt: nil,
                        lastModifiedByDeviceId: nil
                    )
                ],
                tags: nil,
                preferences: nil
            ),
            conflicts: [],
            serverTime: iso(remoteUpdateAt)
        )

        engine.apply(remote: response, context: context, userId: userId)

        XCTAssertNotNil(note.deletedAt, "本地未同步删除不应被同版本远端数据覆盖")
        XCTAssertEqual(note.content, "local")
        XCTAssertEqual(note.version, 3)
    }

    func testApplyRemoteCanReviveNoteWhenRemoteVersionIsHigher() throws {
        let userId = "u1"
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let localDeleteAt = base.addingTimeInterval(90)
        let remoteUpdateAt = base.addingTimeInterval(180)

        let note = Note(content: "local", userId: userId)
        note.version = 3
        note.createdAt = base
        note.serverUpdatedAt = base
        note.updatedAt = base
        context.insert(note)
        try context.save()

        note.deletedAt = localDeleteAt
        note.updatedAt = localDeleteAt
        try context.save()

        let response = SyncResponse(
            cursor: "1",
            changes: SyncChanges(
                notes: [
                    NoteDTO(
                        id: note.id.uuidString,
                        content: "remote-newer",
                        createdAt: iso(base),
                        updatedAt: iso(remoteUpdateAt),
                        deletedAt: nil,
                        pinnedAt: nil,
                        tagIds: [],
                        version: 4,
                        baseVersion: nil,
                        clientUpdatedAt: nil,
                        lastModifiedByDeviceId: nil
                    )
                ],
                tags: nil,
                preferences: nil
            ),
            conflicts: [],
            serverTime: iso(remoteUpdateAt)
        )

        engine.apply(remote: response, context: context, userId: userId)

        XCTAssertNil(note.deletedAt)
        XCTAssertEqual(note.content, "remote-newer")
        XCTAssertEqual(note.version, 4)
    }

    func testApplyRemoteDoesNotReviveLocallyDeletedTagWhenVersionIsEqual() throws {
        let userId = "u1"
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let localDeleteAt = base.addingTimeInterval(90)
        let remoteUpdateAt = base.addingTimeInterval(180)

        let tag = Tag(name: "local-tag", userId: userId)
        tag.version = 5
        tag.createdAt = base
        tag.serverUpdatedAt = base
        tag.updatedAt = base
        context.insert(tag)
        try context.save()

        tag.deletedAt = localDeleteAt
        tag.updatedAt = localDeleteAt
        try context.save()

        let response = SyncResponse(
            cursor: "1",
            changes: SyncChanges(
                notes: [],
                tags: [
                    TagDTO(
                        id: tag.id.uuidString,
                        name: "remote-tag",
                        colorHex: tag.colorHex,
                        createdAt: iso(base),
                        updatedAt: iso(remoteUpdateAt),
                        lastUsedAt: iso(remoteUpdateAt),
                        sortOrder: 0,
                        parentId: nil,
                        deletedAt: nil,
                        version: 5,
                        baseVersion: nil,
                        clientUpdatedAt: nil,
                        lastModifiedByDeviceId: nil
                    )
                ],
                preferences: nil
            ),
            conflicts: [],
            serverTime: iso(remoteUpdateAt)
        )

        engine.apply(remote: response, context: context, userId: userId)

        XCTAssertNotNil(tag.deletedAt)
        XCTAssertEqual(tag.name, "local-tag")
        XCTAssertEqual(tag.version, 5)
    }

    private func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
