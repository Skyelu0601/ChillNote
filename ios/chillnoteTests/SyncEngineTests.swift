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
                hardDeletedNoteIds: nil,
                hardDeletedTagIds: nil,
                preferences: nil
            ),
            conflicts: [],
            serverTime: iso(remoteUpdateAt)
        )

        try engine.apply(remote: response, context: context, userId: userId)

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
                hardDeletedNoteIds: nil,
                hardDeletedTagIds: nil,
                preferences: nil
            ),
            conflicts: [],
            serverTime: iso(remoteUpdateAt)
        )

        try engine.apply(remote: response, context: context, userId: userId)

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
                hardDeletedNoteIds: nil,
                hardDeletedTagIds: nil,
                preferences: nil
            ),
            conflicts: [],
            serverTime: iso(remoteUpdateAt)
        )

        try engine.apply(remote: response, context: context, userId: userId)

        XCTAssertNotNil(tag.deletedAt)
        XCTAssertEqual(tag.name, "local-tag")
        XCTAssertEqual(tag.version, 5)
    }

    func testMakePayloadUsesFingerprintInsteadOfTimestampBoundary() throws {
        let userId = "u1"
        let boundary = Date(timeIntervalSince1970: 1_700_000_000)

        let note = Note(content: "boundary-note", userId: userId)
        note.updatedAt = boundary
        context.insert(note)

        let tag = Tag(name: "boundary-tag", userId: userId)
        tag.updatedAt = boundary
        context.insert(tag)
        note.acknowledgedFingerprint = SyncEntityFingerprint.note(note)
        tag.acknowledgedFingerprint = SyncEntityFingerprint.tag(tag)
        try context.save()

        let payload = try engine.makePayload(
            context: context,
            since: boundary,
            userId: userId,
            cursor: nil,
            deviceId: nil,
            hardDeletedNoteIds: [],
            hardDeletedTagIds: []
        )

        XCTAssertEqual(payload.protocolVersion, 4)
        let encodedPayload = try JSONEncoder().encode(payload)
        let encodedObject = try XCTUnwrap(JSONSerialization.jsonObject(with: encodedPayload) as? [String: Any])
        XCTAssertEqual(encodedObject["protocolVersion"] as? Int, 4)
        XCTAssertEqual(payload.notes.count, 0)
        XCTAssertEqual(payload.tags?.count ?? 0, 0)

        // Deliberately do not advance updatedAt: durable content fingerprints,
        // rather than device clocks, must discover both edits.
        note.updateContent("changed without timestamp")
        note.updatedAt = boundary
        tag.name = "changed without timestamp"
        tag.updatedAt = boundary
        try context.save()

        let changedPayload = try engine.makePayload(
            context: context,
            since: boundary,
            userId: userId,
            cursor: nil,
            deviceId: nil,
            hardDeletedNoteIds: [],
            hardDeletedTagIds: []
        )
        XCTAssertEqual(changedPayload.notes.count, 1)
        XCTAssertEqual(changedPayload.tags?.count, 1)
        XCTAssertNotNil(changedPayload.notes.first?.mutationId)
        XCTAssertNotNil(changedPayload.tags?.first?.mutationId)
    }

    func testNewNoteAndTagRecoverA2AfterA1AcknowledgementLoss() throws {
        let userId = "u1"
        let note = Note(content: "A1 note", userId: userId)
        let tag = Tag(name: "A1 tag", userId: userId)
        note.tags = [tag]
        context.insert(tag)
        context.insert(note)
        try context.save()

        let a1 = try engine.makePayload(
            context: context,
            since: nil,
            userId: userId,
            cursor: nil,
            deviceId: "device-a",
            hardDeletedNoteIds: [],
            hardDeletedTagIds: []
        )
        let a1Note = try XCTUnwrap(a1.notes.first)
        let a1Tag = try XCTUnwrap(a1.tags?.first)
        XCTAssertEqual(a1Note.baseVersion, 0)
        XCTAssertEqual(a1Tag.baseVersion, 0)
        XCTAssertNil(a1Note.previousMutationId)
        XCTAssertNil(a1Tag.previousMutationId)

        // The server committed A1, but its HTTP response was lost. The user
        // makes A2 before the next sync.
        note.updateContent("A2 note")
        tag.name = "A2 tag"
        try context.save()
        let a2 = try engine.makePayload(
            context: context,
            since: nil,
            userId: userId,
            cursor: nil,
            deviceId: "device-a",
            hardDeletedNoteIds: [],
            hardDeletedTagIds: []
        )
        let a2Note = try XCTUnwrap(a2.notes.first)
        let a2Tag = try XCTUnwrap(a2.tags?.first)
        XCTAssertNotEqual(a2Note.mutationId, a1Note.mutationId)
        XCTAssertNotEqual(a2Tag.mutationId, a1Tag.mutationId)
        XCTAssertEqual(a2Note.previousMutationId, a1Note.mutationId)
        XCTAssertEqual(a2Tag.previousMutationId, a1Tag.mutationId)
        XCTAssertEqual(a2Note.baseVersion, 0)
        XCTAssertEqual(a2Tag.baseVersion, 0)

        let response = SyncResponse(
            cursor: "2",
            changes: SyncChanges(
                notes: [
                    NoteDTO(
                        id: note.id.uuidString,
                        content: "A2 note",
                        createdAt: iso(note.createdAt),
                        updatedAt: iso(Date()),
                        deletedAt: nil,
                        pinnedAt: nil,
                        tagIds: [tag.id.uuidString],
                        version: 2,
                        baseVersion: nil,
                        clientUpdatedAt: nil,
                        lastModifiedByDeviceId: "device-a",
                        mutationId: a2Note.mutationId,
                        previousMutationId: a1Note.mutationId
                    )
                ],
                tags: [
                    TagDTO(
                        id: tag.id.uuidString,
                        name: "A2 tag",
                        colorHex: tag.colorHex,
                        createdAt: iso(tag.createdAt),
                        updatedAt: iso(Date()),
                        lastUsedAt: iso(tag.lastUsedAt),
                        sortOrder: tag.sortOrder,
                        parentId: nil,
                        deletedAt: nil,
                        version: 2,
                        baseVersion: nil,
                        clientUpdatedAt: nil,
                        lastModifiedByDeviceId: "device-a",
                        mutationId: a2Tag.mutationId,
                        previousMutationId: a1Tag.mutationId
                    )
                ],
                hardDeletedNoteIds: nil,
                hardDeletedTagIds: nil,
                preferences: nil
            ),
            conflicts: [],
            serverTime: iso(Date())
        )
        try engine.apply(remote: response, context: context, userId: userId)
        try context.save()

        XCTAssertEqual(note.content, "A2 note")
        XCTAssertEqual(tag.name, "A2 tag")
        XCTAssertEqual(note.version, 2)
        XCTAssertEqual(tag.version, 2)
        let clean = try engine.makePayload(
            context: context,
            since: nil,
            userId: userId,
            cursor: "2",
            deviceId: "device-a",
            hardDeletedNoteIds: [],
            hardDeletedTagIds: []
        )
        XCTAssertTrue(clean.notes.isEmpty)
        XCTAssertTrue(clean.tags?.isEmpty ?? false)
    }

    func testSyncPayloadDecodesLegacyJSONWithoutProtocolVersion() throws {
        let data = Data(#"{"cursor":null,"deviceId":null,"notes":[],"tags":null,"hardDeletedNoteIds":null,"hardDeletedTagIds":null,"preferences":null}"#.utf8)

        let payload = try JSONDecoder().decode(SyncPayload.self, from: data)

        XCTAssertNil(payload.protocolVersion)
        XCTAssertTrue(payload.notes.isEmpty)
    }

    func testSyncResponseDecodesDurableMutationAndForcedIds() throws {
        let noteId = UUID().uuidString
        let json = """
        {
          "cursor":"1",
          "changes":{
            "notes":[{
              "id":"\(noteId)","content":"server","createdAt":"2023-11-14T22:13:20.000Z",
              "updatedAt":null,"deletedAt":null,"pinnedAt":null,"tagIds":[],
              "version":2,"baseVersion":null,"clientUpdatedAt":null,
              "lastModifiedByDeviceId":"server","mutationId":"mutation-server",
              "previousMutationId":null
            }],
            "tags":null,"hardDeletedNoteIds":null,"hardDeletedTagIds":null,"preferences":null
          },
          "conflicts":[],"forcedNoteIds":["\(noteId)"],"forcedTagIds":[],
          "serverTime":"2023-11-14T22:13:20.000Z"
        }
        """

        let response = try JSONDecoder().decode(SyncResponse.self, from: Data(json.utf8))

        XCTAssertEqual(response.changes.notes.first?.mutationId, "mutation-server")
        XCTAssertEqual(response.forcedNoteIds, [noteId])
        XCTAssertEqual(response.forcedTagIds, [])
    }

    func testApplyRemoteClampsUpdatedAtToLocalSyncAnchor() throws {
        let userId = "u1"
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let anchor = base.addingTimeInterval(60)
        let remoteUpdateAt = base.addingTimeInterval(300)
        let noteId = UUID()

        let response = SyncResponse(
            cursor: "1",
            changes: SyncChanges(
                notes: [
                    NoteDTO(
                        id: noteId.uuidString,
                        content: "remote note",
                        createdAt: iso(base),
                        updatedAt: iso(remoteUpdateAt),
                        deletedAt: nil,
                        pinnedAt: nil,
                        tagIds: [],
                        version: 1,
                        baseVersion: nil,
                        clientUpdatedAt: nil,
                        lastModifiedByDeviceId: nil
                    )
                ],
                tags: nil,
                hardDeletedNoteIds: nil,
                hardDeletedTagIds: nil,
                preferences: nil
            ),
            conflicts: [],
            serverTime: iso(remoteUpdateAt)
        )

        try engine.apply(remote: response, context: context, userId: userId, localSyncAnchor: anchor)

        let fetched = try context.fetch(FetchDescriptor<Note>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].serverUpdatedAt, remoteUpdateAt)
        XCTAssertEqual(fetched[0].updatedAt, anchor)
    }

    func testRejectedRemoteTagDoesNotOverwriteLocalParent() throws {
        let userId = "u1"
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let localParent = Tag(name: "local-parent", userId: userId)
        let remoteParent = Tag(name: "remote-parent", userId: userId)
        let child = Tag(name: "child", userId: userId)
        child.version = 5
        child.updatedAt = base.addingTimeInterval(60)
        child.parent = localParent
        context.insert(localParent)
        context.insert(remoteParent)
        context.insert(child)
        try context.save()

        let response = SyncResponse(
            cursor: "1",
            changes: SyncChanges(
                notes: [],
                tags: [
                    TagDTO(
                        id: child.id.uuidString,
                        name: "stale-child",
                        colorHex: child.colorHex,
                        createdAt: iso(base),
                        updatedAt: iso(base),
                        lastUsedAt: iso(base),
                        sortOrder: 0,
                        parentId: remoteParent.id.uuidString,
                        deletedAt: nil,
                        version: 5,
                        baseVersion: nil,
                        clientUpdatedAt: nil,
                        lastModifiedByDeviceId: nil
                    )
                ],
                hardDeletedNoteIds: nil,
                hardDeletedTagIds: nil,
                preferences: nil
            ),
            conflicts: [],
            serverTime: iso(base)
        )

        try engine.apply(remote: response, context: context, userId: userId)

        XCTAssertEqual(child.name, "child")
        XCTAssertEqual(child.parent?.id, localParent.id)
    }

    func testAcceptedRemoteTagUpdatesParent() throws {
        let userId = "u1"
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let localParent = Tag(name: "local-parent", userId: userId)
        let remoteParent = Tag(name: "remote-parent", userId: userId)
        let child = Tag(name: "child", userId: userId)
        child.version = 5
        child.updatedAt = base
        child.parent = localParent
        context.insert(localParent)
        context.insert(remoteParent)
        context.insert(child)
        try context.save()

        let response = SyncResponse(
            cursor: "2",
            changes: SyncChanges(
                notes: [],
                tags: [
                    TagDTO(
                        id: child.id.uuidString,
                        name: "remote-child",
                        colorHex: child.colorHex,
                        createdAt: iso(base),
                        updatedAt: iso(base.addingTimeInterval(120)),
                        lastUsedAt: iso(base),
                        sortOrder: 0,
                        parentId: remoteParent.id.uuidString,
                        deletedAt: nil,
                        version: 6,
                        baseVersion: nil,
                        clientUpdatedAt: nil,
                        lastModifiedByDeviceId: nil
                    )
                ],
                hardDeletedNoteIds: nil,
                hardDeletedTagIds: nil,
                preferences: nil
            ),
            conflicts: [],
            serverTime: iso(base.addingTimeInterval(120))
        )

        try engine.apply(remote: response, context: context, userId: userId)

        XCTAssertEqual(child.name, "remote-child")
        XCTAssertEqual(child.parent?.id, remoteParent.id)
    }

    func testApplyRemoteRebasesVersionWithoutOverwritingNoteEditedAfterAnchor() throws {
        let userId = "u1"
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let anchor = base.addingTimeInterval(60)
        let localEditAt = anchor.addingTimeInterval(30)
        let remoteUpdateAt = anchor.addingTimeInterval(60)
        let localTag = Tag(name: "local-tag", userId: userId)
        let note = Note(content: "local edit during sync", userId: userId)
        note.version = 3
        note.updatedAt = localEditAt
        note.serverUpdatedAt = base
        note.tags = [localTag]
        context.insert(localTag)
        context.insert(note)
        try context.save()

        let response = SyncResponse(
            cursor: "2",
            changes: SyncChanges(
                notes: [
                    NoteDTO(
                        id: note.id.uuidString,
                        content: "remote snapshot",
                        createdAt: iso(base),
                        updatedAt: iso(remoteUpdateAt),
                        deletedAt: nil,
                        pinnedAt: nil,
                        tagIds: [],
                        version: 4,
                        baseVersion: nil,
                        clientUpdatedAt: nil,
                        lastModifiedByDeviceId: "remote-device"
                    )
                ],
                tags: nil,
                hardDeletedNoteIds: nil,
                hardDeletedTagIds: nil,
                preferences: nil
            ),
            conflicts: [],
            serverTime: iso(remoteUpdateAt)
        )

        try engine.apply(remote: response, context: context, userId: userId, localSyncAnchor: anchor)

        XCTAssertEqual(note.content, "local edit during sync")
        XCTAssertEqual(note.tags.map(\.id), [localTag.id])
        XCTAssertEqual(note.updatedAt, localEditAt)
        XCTAssertEqual(note.version, 4)
        XCTAssertEqual(note.serverUpdatedAt, remoteUpdateAt)
        XCTAssertNil(note.lastModifiedByDeviceId)
    }

    func testApplyRemoteRebasesVersionWithoutOverwritingTagEditedAfterAnchor() throws {
        let userId = "u1"
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let anchor = base.addingTimeInterval(60)
        let localEditAt = anchor.addingTimeInterval(30)
        let remoteUpdateAt = anchor.addingTimeInterval(60)
        let localParent = Tag(name: "local-parent", userId: userId)
        let remoteParent = Tag(name: "remote-parent", userId: userId)
        let tag = Tag(name: "local name", userId: userId, colorHex: "#123456")
        tag.version = 5
        tag.updatedAt = localEditAt
        tag.serverUpdatedAt = base
        tag.sortOrder = 7
        tag.parent = localParent
        context.insert(localParent)
        context.insert(remoteParent)
        context.insert(tag)
        try context.save()

        let response = SyncResponse(
            cursor: "2",
            changes: SyncChanges(
                notes: [],
                tags: [
                    TagDTO(
                        id: tag.id.uuidString,
                        name: "remote name",
                        colorHex: "#ABCDEF",
                        createdAt: iso(base),
                        updatedAt: iso(remoteUpdateAt),
                        lastUsedAt: iso(remoteUpdateAt),
                        sortOrder: 99,
                        parentId: remoteParent.id.uuidString,
                        deletedAt: nil,
                        version: 6,
                        baseVersion: nil,
                        clientUpdatedAt: nil,
                        lastModifiedByDeviceId: "remote-device"
                    )
                ],
                hardDeletedNoteIds: nil,
                hardDeletedTagIds: nil,
                preferences: nil
            ),
            conflicts: [],
            serverTime: iso(remoteUpdateAt)
        )

        try engine.apply(remote: response, context: context, userId: userId, localSyncAnchor: anchor)

        XCTAssertEqual(tag.name, "local name")
        XCTAssertEqual(tag.colorHex, "#123456")
        XCTAssertEqual(tag.sortOrder, 7)
        XCTAssertEqual(tag.parent?.id, localParent.id)
        XCTAssertEqual(tag.updatedAt, localEditAt)
        XCTAssertEqual(tag.version, 6)
        XCTAssertEqual(tag.serverUpdatedAt, remoteUpdateAt)
        XCTAssertNil(tag.lastModifiedByDeviceId)
    }

    func testFreshApplyContextSeesMainContextEditMadeAfterPayloadSnapshot() throws {
        let userId = "u1"
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let anchor = base.addingTimeInterval(60)
        let localEditAt = anchor.addingTimeInterval(30)
        let remoteUpdateAt = anchor.addingTimeInterval(60)
        let note = Note(content: "payload snapshot", userId: userId)
        note.version = 1
        note.updatedAt = base
        note.serverUpdatedAt = base
        context.insert(note)
        try context.save()

        let payloadContext = ModelContext(container)
        let payload = try engine.makePayload(
            context: payloadContext,
            since: nil,
            userId: userId,
            cursor: nil,
            deviceId: "test-device",
            hardDeletedNoteIds: [],
            hardDeletedTagIds: []
        )
        XCTAssertEqual(payload.notes.first?.content, "payload snapshot")

        note.updateContent("main context edit during request")
        note.updatedAt = localEditAt
        try context.save()

        let response = SyncResponse(
            cursor: "2",
            changes: SyncChanges(
                notes: [
                    NoteDTO(
                        id: note.id.uuidString,
                        content: "payload snapshot",
                        createdAt: iso(base),
                        updatedAt: iso(remoteUpdateAt),
                        deletedAt: nil,
                        pinnedAt: nil,
                        tagIds: [],
                        version: 2,
                        baseVersion: nil,
                        clientUpdatedAt: nil,
                        lastModifiedByDeviceId: "test-device"
                    )
                ],
                tags: nil,
                hardDeletedNoteIds: nil,
                hardDeletedTagIds: nil,
                preferences: nil
            ),
            conflicts: [],
            serverTime: iso(remoteUpdateAt)
        )

        try RemoteSyncService.applyRemoteResponseUsingFreshContext(
            sourceContext: payloadContext,
            response: response,
            userId: userId,
            localSyncAnchor: anchor
        )

        let verificationContext = ModelContext(container)
        let verified = try XCTUnwrap(verificationContext.fetch(FetchDescriptor<Note>()).first)
        XCTAssertEqual(verified.content, "main context edit during request")
        XCTAssertEqual(verified.updatedAt, localEditAt)
        XCTAssertEqual(verified.version, 2)
        XCTAssertEqual(verified.serverUpdatedAt, remoteUpdateAt)
    }

    func testApplyRemoteDoesNotCreateConflictCopyNotes() throws {
        let userId = "u1"
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        let response = SyncResponse(
            cursor: "1",
            changes: SyncChanges(
                notes: [],
                tags: nil,
                hardDeletedNoteIds: nil,
                hardDeletedTagIds: nil,
                preferences: nil
            ),
            conflicts: [
                ConflictDTO(
                    entityType: "note",
                    id: UUID().uuidString,
                    serverVersion: 2,
                    serverContent: "server",
                    clientContent: "client",
                    message: "笔记在其他设备已更新，发生冲突。"
                )
            ],
            serverTime: iso(base)
        )

        try engine.apply(remote: response, context: context, userId: userId)

        let fetched = try context.fetch(FetchDescriptor<Note>())
        XCTAssertTrue(fetched.isEmpty, "同步层不应再为冲突创建副本笔记")
    }

    func testAcknowledgementLossRetryReusesMutationAndBecomesClean() throws {
        let userId = "u1"
        let note = Note(content: "server baseline", userId: userId)
        note.version = 3
        note.serverMutationId = "mutation-server-0"
        context.insert(note)
        note.acknowledgedFingerprint = SyncEntityFingerprint.note(note)
        try context.save()

        note.updateContent("A1 local")
        try context.save()
        let first = try engine.makePayload(
            context: context,
            since: nil,
            userId: userId,
            cursor: nil,
            deviceId: "device-a",
            hardDeletedNoteIds: [],
            hardDeletedTagIds: []
        )
        let firstDTO = try XCTUnwrap(first.notes.first)

        // Simulate a committed request whose HTTP ACK never reached the app.
        let retry = try engine.makePayload(
            context: context,
            since: nil,
            userId: userId,
            cursor: nil,
            deviceId: "device-a",
            hardDeletedNoteIds: [],
            hardDeletedTagIds: []
        )
        let retryDTO = try XCTUnwrap(retry.notes.first)
        XCTAssertEqual(retryDTO.mutationId, firstDTO.mutationId)
        XCTAssertEqual(retryDTO.previousMutationId, "mutation-server-0")

        let response = SyncResponse(
            cursor: "4",
            changes: SyncChanges(
                notes: [
                    NoteDTO(
                        id: note.id.uuidString,
                        content: "A1 local",
                        createdAt: iso(note.createdAt),
                        updatedAt: iso(Date()),
                        deletedAt: nil,
                        pinnedAt: nil,
                        tagIds: [],
                        version: 4,
                        baseVersion: nil,
                        clientUpdatedAt: nil,
                        lastModifiedByDeviceId: "device-a",
                        mutationId: firstDTO.mutationId
                    )
                ],
                tags: nil,
                hardDeletedNoteIds: nil,
                hardDeletedTagIds: nil,
                preferences: nil
            ),
            conflicts: [],
            forcedNoteIds: [note.id.uuidString],
            serverTime: iso(Date())
        )
        try engine.apply(remote: response, context: context, userId: userId)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Note>()), 1)
        XCTAssertEqual(note.version, 4)
        XCTAssertEqual(note.serverMutationId, firstDTO.mutationId)
        let clean = try engine.makePayload(
            context: context,
            since: nil,
            userId: userId,
            cursor: "4",
            deviceId: "device-a",
            hardDeletedNoteIds: [],
            hardDeletedTagIds: []
        )
        XCTAssertTrue(clean.notes.isEmpty)
    }

    func testA1AcknowledgementLossThenForeignBAndA2PreservesBothNotes() throws {
        let userId = "u1"
        let note = Note(content: "baseline", userId: userId)
        note.version = 3
        note.serverMutationId = "mutation-server-0"
        context.insert(note)
        note.acknowledgedFingerprint = SyncEntityFingerprint.note(note)
        try context.save()

        note.updateContent("A1 local")
        try context.save()
        let a1 = try engine.makePayload(
            context: context,
            since: nil,
            userId: userId,
            cursor: nil,
            deviceId: "device-a",
            hardDeletedNoteIds: [],
            hardDeletedTagIds: []
        )
        let a1Mutation = try XCTUnwrap(a1.notes.first?.mutationId)

        note.updateContent("A2 newest local")
        note.section = .published
        try context.save()
        let a2 = try engine.makePayload(
            context: context,
            since: nil,
            userId: userId,
            cursor: nil,
            deviceId: "device-a",
            hardDeletedNoteIds: [],
            hardDeletedTagIds: []
        )
        let a2DTO = try XCTUnwrap(a2.notes.first)
        XCTAssertEqual(a2DTO.previousMutationId, a1Mutation)

        // Another device B wrote after A1. A2 is therefore a real conflict,
        // not the +1 ACK-loss recovery case.
        let response = SyncResponse(
            cursor: "6",
            changes: SyncChanges(
                notes: [
                    NoteDTO(
                        id: note.id.uuidString,
                        content: "device B",
                        createdAt: iso(note.createdAt),
                        updatedAt: iso(Date()),
                        deletedAt: nil,
                        pinnedAt: nil,
                        tagIds: [],
                        version: 5,
                        baseVersion: nil,
                        clientUpdatedAt: nil,
                        lastModifiedByDeviceId: "device-b",
                        mutationId: "mutation-device-b"
                    )
                ],
                tags: nil,
                hardDeletedNoteIds: nil,
                hardDeletedTagIds: nil,
                preferences: nil
            ),
            conflicts: [
                ConflictDTO(
                    entityType: "note",
                    id: note.id.uuidString,
                    serverVersion: 5,
                    serverContent: "device B",
                    clientContent: "A2 newest local",
                    message: "sync.conflict.version"
                )
            ],
            forcedNoteIds: [note.id.uuidString],
            serverTime: iso(Date())
        )
        try engine.apply(remote: response, context: context, userId: userId)
        try context.save()

        let notes = try context.fetch(FetchDescriptor<Note>())
        XCTAssertEqual(notes.count, 2)
        let authoritative = try XCTUnwrap(notes.first(where: { $0.id == note.id }))
        let preserved = try XCTUnwrap(notes.first(where: { $0.id != note.id }))
        XCTAssertEqual(authoritative.content, "device B")
        XCTAssertEqual(authoritative.serverMutationId, "mutation-device-b")
        XCTAssertEqual(preserved.content, "A2 newest local")
        XCTAssertEqual(preserved.section, .drafts)
        XCTAssertEqual(preserved.version, 0)
        XCTAssertNil(preserved.acknowledgedFingerprint)
    }

    func testFinishedImportForcedResponseDoesNotCreateConflictCopy() throws {
        let userId = "u1"
        let jobId = "job-1"
        let note = Note(content: "placeholder", userId: userId)
        note.version = 1
        note.serverMutationId = "mutation-server-1"
        context.insert(note)
        note.acknowledgedFingerprint = SyncEntityFingerprint.note(note)
        try context.save()

        note.importStatus = .queued
        note.importJobId = jobId
        try context.save()
        _ = try engine.makePayload(
            context: context,
            since: nil,
            userId: userId,
            cursor: nil,
            deviceId: "device-a",
            hardDeletedNoteIds: [],
            hardDeletedTagIds: []
        )

        let response = SyncResponse(
            cursor: "7",
            changes: SyncChanges(
                notes: [
                    NoteDTO(
                        id: note.id.uuidString,
                        content: "completed transcription",
                        createdAt: iso(note.createdAt),
                        updatedAt: iso(Date()),
                        deletedAt: nil,
                        pinnedAt: nil,
                        tagIds: [],
                        version: 2,
                        baseVersion: nil,
                        clientUpdatedAt: nil,
                        lastModifiedByDeviceId: "server-import",
                        mutationId: "mutation-import-finished",
                        importStatus: NoteImportStatus.completed.rawValue,
                        importJobId: jobId,
                        importCompletedAt: iso(Date())
                    )
                ],
                tags: nil,
                hardDeletedNoteIds: nil,
                hardDeletedTagIds: nil,
                preferences: nil
            ),
            conflicts: [],
            forcedNoteIds: [note.id.uuidString],
            serverTime: iso(Date())
        )
        try engine.apply(remote: response, context: context, userId: userId)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Note>()), 1)
        XCTAssertEqual(note.content, "completed transcription")
        XCTAssertEqual(note.importStatus, .completed)
        let next = try engine.makePayload(
            context: context,
            since: nil,
            userId: userId,
            cursor: "7",
            deviceId: "device-a",
            hardDeletedNoteIds: [],
            hardDeletedTagIds: []
        )
        XCTAssertTrue(next.notes.isEmpty)
    }

    func testForcedTagWithoutConflictRebasesDirtyEditWithoutCopy() throws {
        let userId = "u1"
        let tag = Tag(name: "baseline", userId: userId)
        tag.version = 2
        tag.serverMutationId = "mutation-server-2"
        context.insert(tag)
        tag.acknowledgedFingerprint = SyncEntityFingerprint.tag(tag)
        try context.save()

        // The request snapshot was clean. A server-side hierarchy repair and a
        // local rename then race while that request is in flight.
        tag.name = "local rename during request"
        try context.save()
        let response = SyncResponse(
            cursor: "8",
            changes: SyncChanges(
                notes: [],
                tags: [
                    TagDTO(
                        id: tag.id.uuidString,
                        name: "server hierarchy state",
                        colorHex: tag.colorHex,
                        createdAt: iso(tag.createdAt),
                        updatedAt: iso(Date()),
                        lastUsedAt: iso(tag.lastUsedAt),
                        sortOrder: tag.sortOrder,
                        parentId: nil,
                        deletedAt: nil,
                        version: 3,
                        baseVersion: nil,
                        clientUpdatedAt: nil,
                        lastModifiedByDeviceId: "server",
                        mutationId: "mutation-server-3"
                    )
                ],
                hardDeletedNoteIds: nil,
                hardDeletedTagIds: nil,
                preferences: nil
            ),
            conflicts: [],
            forcedTagIds: [tag.id.uuidString],
            serverTime: iso(Date())
        )
        try engine.apply(remote: response, context: context, userId: userId)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Tag>()), 1)
        XCTAssertEqual(tag.name, "local rename during request")
        XCTAssertEqual(tag.version, 3)
        XCTAssertEqual(tag.serverMutationId, "mutation-server-3")

        let retry = try engine.makePayload(
            context: context,
            since: nil,
            userId: userId,
            cursor: "8",
            deviceId: "device-a",
            hardDeletedNoteIds: [],
            hardDeletedTagIds: []
        )
        let retryTag = try XCTUnwrap(retry.tags?.first)
        XCTAssertEqual(retryTag.previousMutationId, "mutation-server-3")
        XCTAssertEqual(retryTag.baseVersion, 3)
    }

    func testSubmittedTagHierarchyCorrectionIsAppliedAndAcknowledged() throws {
        let userId = "u1"
        let parent = Tag(name: "parent", userId: userId)
        let tag = Tag(name: "submitted child", userId: userId)
        parent.version = 2
        tag.version = 2
        parent.serverMutationId = "parent-server-2"
        tag.serverMutationId = "tag-server-2"
        context.insert(parent)
        context.insert(tag)
        parent.acknowledgedFingerprint = SyncEntityFingerprint.tag(parent)
        tag.acknowledgedFingerprint = SyncEntityFingerprint.tag(tag)
        try context.save()

        tag.parent = parent
        try context.save()
        let payload = try engine.makePayload(
            context: context,
            since: nil,
            userId: userId,
            cursor: "2",
            deviceId: "device-a",
            hardDeletedNoteIds: [],
            hardDeletedTagIds: []
        )
        let submitted = try XCTUnwrap(payload.tags?.first(where: { $0.id == tag.id.uuidString }))

        let response = SyncResponse(
            cursor: "3",
            changes: SyncChanges(
                notes: [],
                tags: [
                    TagDTO(
                        id: tag.id.uuidString,
                        name: tag.name,
                        colorHex: tag.colorHex,
                        createdAt: iso(tag.createdAt),
                        updatedAt: iso(Date()),
                        lastUsedAt: iso(tag.lastUsedAt),
                        sortOrder: tag.sortOrder,
                        parentId: nil,
                        deletedAt: nil,
                        version: 3,
                        baseVersion: nil,
                        clientUpdatedAt: nil,
                        lastModifiedByDeviceId: "device-a",
                        mutationId: submitted.mutationId
                    )
                ],
                hardDeletedNoteIds: nil,
                hardDeletedTagIds: nil,
                preferences: nil
            ),
            conflicts: [],
            forcedTagIds: [tag.id.uuidString],
            serverTime: iso(Date())
        )
        try engine.apply(remote: response, context: context, userId: userId)
        try context.save()

        XCTAssertNil(tag.parent)
        XCTAssertEqual(tag.version, 3)
        let next = try engine.makePayload(
            context: context,
            since: nil,
            userId: userId,
            cursor: "3",
            deviceId: "device-a",
            hardDeletedNoteIds: [],
            hardDeletedTagIds: []
        )
        XCTAssertFalse(next.tags?.contains(where: { $0.id == tag.id.uuidString }) ?? false)
    }

    func testVersionConflictPreservesTagAttributesAndRelationships() throws {
        let userId = "u1"
        let localParent = Tag(name: "local parent", userId: userId)
        let remoteParent = Tag(name: "remote parent", userId: userId)
        let child = Tag(name: "child", userId: userId)
        let tag = Tag(name: "baseline", userId: userId, colorHex: "#111111")
        let note = Note(content: "related note", userId: userId)
        tag.version = 2
        tag.serverMutationId = "tag-server-2"
        tag.parent = localParent
        child.parent = tag
        note.tags = [tag]
        for model in [localParent, remoteParent, child, tag] {
            context.insert(model)
        }
        context.insert(note)
        tag.acknowledgedFingerprint = SyncEntityFingerprint.tag(tag)
        try context.save()

        tag.name = "newest local tag"
        tag.colorHex = "#ABCDEF"
        tag.sortOrder = 42
        try context.save()
        _ = try engine.makePayload(
            context: context,
            since: nil,
            userId: userId,
            cursor: nil,
            deviceId: "device-a",
            hardDeletedNoteIds: [],
            hardDeletedTagIds: []
        )

        let response = SyncResponse(
            cursor: "9",
            changes: SyncChanges(
                notes: [],
                tags: [
                    TagDTO(
                        id: tag.id.uuidString,
                        name: "foreign server tag",
                        colorHex: "#222222",
                        createdAt: iso(tag.createdAt),
                        updatedAt: iso(Date()),
                        lastUsedAt: iso(tag.lastUsedAt),
                        sortOrder: 7,
                        parentId: remoteParent.id.uuidString,
                        deletedAt: nil,
                        version: 3,
                        baseVersion: nil,
                        clientUpdatedAt: nil,
                        lastModifiedByDeviceId: "device-b",
                        mutationId: "tag-device-b"
                    )
                ],
                hardDeletedNoteIds: nil,
                hardDeletedTagIds: nil,
                preferences: nil
            ),
            conflicts: [
                ConflictDTO(
                    entityType: "tag",
                    id: tag.id.uuidString,
                    serverVersion: 3,
                    serverContent: "foreign server tag",
                    clientContent: "newest local tag",
                    message: "sync.conflict.version"
                )
            ],
            forcedTagIds: [tag.id.uuidString],
            serverTime: iso(Date())
        )
        try engine.apply(remote: response, context: context, userId: userId)
        try context.save()

        let allTags = try context.fetch(FetchDescriptor<Tag>())
        let preserved = try XCTUnwrap(allTags.first(where: { $0.name == "newest local tag" && $0.id != tag.id }))
        XCTAssertEqual(tag.name, "foreign server tag")
        XCTAssertEqual(tag.parent?.id, remoteParent.id)
        XCTAssertEqual(preserved.colorHex, "#ABCDEF")
        XCTAssertEqual(preserved.sortOrder, 42)
        XCTAssertEqual(preserved.parent?.id, localParent.id)
        XCTAssertEqual(child.parent?.id, preserved.id)
        XCTAssertTrue(note.tags.contains(where: { $0.id == preserved.id }))
        XCTAssertEqual(preserved.version, 0)
    }

    func testHardDeletedConflictPreservesDirtyNoteAndTagBeforeDeletingOriginals() throws {
        let userId = "u1"
        let note = Note(content: "server baseline", userId: userId)
        let tag = Tag(name: "server tag", userId: userId)
        note.tags = [tag]
        note.version = 2
        tag.version = 2
        note.serverMutationId = "note-server"
        tag.serverMutationId = "tag-server"
        context.insert(tag)
        context.insert(note)
        note.acknowledgedFingerprint = SyncEntityFingerprint.note(note)
        tag.acknowledgedFingerprint = SyncEntityFingerprint.tag(tag)
        try context.save()

        note.updateContent("offline note edit")
        tag.name = "offline tag edit"
        try context.save()
        let originalNoteId = note.id
        let originalTagId = tag.id

        let response = SyncResponse(
            cursor: "9",
            changes: SyncChanges(
                notes: [],
                tags: [],
                hardDeletedNoteIds: [note.id.uuidString],
                hardDeletedTagIds: [tag.id.uuidString],
                preferences: nil
            ),
            conflicts: [
                ConflictDTO(
                    entityType: "note",
                    id: note.id.uuidString,
                    serverVersion: 0,
                    serverContent: nil,
                    clientContent: note.content,
                    message: "sync.conflict.hard_deleted"
                ),
                ConflictDTO(
                    entityType: "tag",
                    id: tag.id.uuidString,
                    serverVersion: 0,
                    serverContent: nil,
                    clientContent: tag.name,
                    message: "sync.conflict.hard_deleted"
                )
            ],
            serverTime: iso(Date())
        )
        try engine.apply(remote: response, context: context, userId: userId)
        try context.save()

        let preservedNotes = try context.fetch(FetchDescriptor<Note>())
        let preservedTags = try context.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(preservedNotes.count, 1)
        XCTAssertEqual(preservedTags.count, 1)
        XCTAssertNotEqual(preservedNotes[0].id, originalNoteId)
        XCTAssertNotEqual(preservedTags[0].id, originalTagId)
        XCTAssertEqual(preservedNotes[0].content, "offline note edit")
        XCTAssertEqual(preservedNotes[0].section, .drafts)
        XCTAssertEqual(preservedTags[0].name, "offline tag edit")
        XCTAssertTrue(preservedNotes[0].tags.contains(where: { $0.id == preservedTags[0].id }))
        XCTAssertEqual(preservedNotes[0].version, 0)
        XCTAssertEqual(preservedTags[0].version, 0)
    }

    func testHardDeleteWithoutDirtyConflictDoesNotCreateBackup() throws {
        let userId = "u1"
        let note = Note(content: "already acknowledged", userId: userId)
        context.insert(note)
        note.acknowledgedFingerprint = SyncEntityFingerprint.note(note)
        try context.save()

        let response = SyncResponse(
            cursor: "10",
            changes: SyncChanges(
                notes: [],
                tags: nil,
                hardDeletedNoteIds: [note.id.uuidString],
                hardDeletedTagIds: nil,
                preferences: nil
            ),
            conflicts: [
                ConflictDTO(
                    entityType: "note",
                    id: note.id.uuidString,
                    serverVersion: 0,
                    serverContent: nil,
                    clientContent: nil,
                    message: "sync.conflict.hard_deleted"
                )
            ],
            serverTime: iso(Date())
        )
        try engine.apply(remote: response, context: context, userId: userId)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Note>()), 0)
    }

    func testOrdinaryTombstonePreservesEditsMadeAfterPayloadSnapshot() throws {
        let userId = "u1"
        let note = Note(content: "clean note", userId: userId)
        let tag = Tag(name: "clean tag", userId: userId)
        note.tags = [tag]
        note.version = 2
        tag.version = 2
        note.serverMutationId = "note-server-2"
        tag.serverMutationId = "tag-server-2"
        context.insert(tag)
        context.insert(note)
        note.acknowledgedFingerprint = SyncEntityFingerprint.note(note)
        tag.acknowledgedFingerprint = SyncEntityFingerprint.tag(tag)
        try context.save()

        let originalNoteID = note.id
        let originalTagID = tag.id
        let payloadContext = ModelContext(container)
        let payload = try engine.makePayload(
            context: payloadContext,
            since: nil,
            userId: userId,
            cursor: "2",
            deviceId: "device-a",
            hardDeletedNoteIds: [],
            hardDeletedTagIds: []
        )
        XCTAssertTrue(payload.notes.isEmpty)
        XCTAssertTrue(payload.tags?.isEmpty ?? true)

        note.updateContent("note edit during request")
        tag.name = "tag edit during request"
        try context.save()

        let response = SyncResponse(
            cursor: "3",
            changes: SyncChanges(
                notes: [],
                tags: [],
                hardDeletedNoteIds: [originalNoteID.uuidString],
                hardDeletedTagIds: [originalTagID.uuidString],
                preferences: nil
            ),
            conflicts: [],
            serverTime: iso(Date())
        )
        try RemoteSyncService.applyRemoteResponseUsingFreshContext(
            sourceContext: payloadContext,
            response: response,
            userId: userId,
            localSyncAnchor: Date()
        )

        let verificationContext = ModelContext(container)
        let preservedNotes = try verificationContext.fetch(FetchDescriptor<Note>())
        let preservedTags = try verificationContext.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(preservedNotes.count, 1)
        XCTAssertEqual(preservedTags.count, 1)
        XCTAssertNotEqual(preservedNotes[0].id, originalNoteID)
        XCTAssertNotEqual(preservedTags[0].id, originalTagID)
        XCTAssertEqual(preservedNotes[0].content, "note edit during request")
        XCTAssertEqual(preservedTags[0].name, "tag edit during request")
        XCTAssertTrue(preservedNotes[0].tags.contains(where: { $0.id == preservedTags[0].id }))
        XCTAssertEqual(preservedNotes[0].version, 0)
        XCTAssertEqual(preservedTags[0].version, 0)
    }

    func testAuthSnapshotRejectsCredentialsFetchedAcrossAccountSwitch() {
        let initial = AuthSessionIdentity(userId: "account-a", generation: 10)
        let switched = AuthSessionIdentity(userId: "account-b", generation: 11)

        let snapshot = AuthSessionSnapshotResolver.resolve(
            initial: initial,
            fetchedUserId: "account-b",
            token: "token-b",
            current: switched
        )

        XCTAssertNil(snapshot, "切号期间拿到 B token 时绝不能生成 A 的同步快照")
    }

    func testChangedAuthSessionStopsBeforePayloadWriteOrRequest() async throws {
        let note = Note(content: "account A", userId: "account-a")
        context.insert(note)
        try context.save()
        let config = SyncConfig(
            baseURL: URL(string: "https://invalid.example")!,
            authToken: "token-b",
            since: nil,
            cursor: nil,
            localSyncAnchor: Date(),
            userId: "account-a",
            deviceId: "device-a",
            hardDeletedNoteIds: [],
            hardDeletedTagIds: [],
            isSessionCurrent: { false }
        )

        do {
            _ = try await RemoteSyncService(config: config).syncAll(context: context)
            XCTFail("账号已切换时不应进入同步请求")
        } catch SyncError.authSessionChanged {
            // Expected: this happens before makePayload and URLSession.
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        XCTAssertNil(note.lastSubmittedMutationId)
        XCTAssertNil(note.lastSubmittedFingerprint)
        XCTAssertNil(note.acknowledgedFingerprint)
    }

    func testAcknowledgementValidationAcceptsCaseInsensitiveEntitiesAndTombstones() {
        let noteID = UUID()
        let tagID = UUID()
        let hardDeletedNoteID = UUID()
        let hardDeletedTagID = UUID()
        let payload = makePayload(
            noteIDs: [noteID.uuidString.lowercased()],
            tagIDs: [tagID.uuidString.uppercased()],
            hardDeletedNoteIDs: [hardDeletedNoteID.uuidString.lowercased()],
            hardDeletedTagIDs: [hardDeletedTagID.uuidString.uppercased()]
        )
        let response = makeResponse(
            noteIDs: [noteID.uuidString.uppercased()],
            tagIDs: [tagID.uuidString.lowercased()],
            hardDeletedNoteIDs: [hardDeletedNoteID.uuidString.uppercased()],
            hardDeletedTagIDs: [hardDeletedTagID.uuidString.lowercased()]
        )

        XCTAssertTrue(
            SyncAcknowledgementValidator.hasCompleteAuthoritativeAcknowledgements(
                payload: payload,
                response: response
            )
        )
    }

    func testAcknowledgementValidationRequiresAuthoritativeStateForConflict() {
        let noteID = UUID()
        let payload = makePayload(noteIDs: [noteID.uuidString])
        let conflict = ConflictDTO(
            entityType: "note",
            id: noteID.uuidString,
            serverVersion: 2,
            serverContent: "server",
            clientContent: "client",
            message: "conflict"
        )
        let conflictOnlyResponse = SyncResponse(
            cursor: "2",
            changes: SyncChanges(
                notes: [],
                tags: nil,
                hardDeletedNoteIds: nil,
                hardDeletedTagIds: nil,
                preferences: nil
            ),
            conflicts: [conflict],
            serverTime: iso(Date(timeIntervalSince1970: 1_700_000_000))
        )

        XCTAssertFalse(
            SyncAcknowledgementValidator.hasCompleteAuthoritativeAcknowledgements(
                payload: payload,
                response: conflictOnlyResponse
            )
        )

        let authoritativeResponse = SyncResponse(
            cursor: "2",
            changes: SyncChanges(
                notes: [makeNoteDTO(id: noteID.uuidString)],
                tags: nil,
                hardDeletedNoteIds: nil,
                hardDeletedTagIds: nil,
                preferences: nil
            ),
            conflicts: [conflict],
            serverTime: iso(Date(timeIntervalSince1970: 1_700_000_000))
        )
        XCTAssertTrue(
            SyncAcknowledgementValidator.hasCompleteAuthoritativeAcknowledgements(
                payload: payload,
                response: authoritativeResponse
            )
        )
    }

    func testAcknowledgementValidationRejectsAnyMissingSubmittedID() {
        let acknowledgedNoteID = UUID()
        let missingNoteID = UUID()
        let payload = makePayload(noteIDs: [acknowledgedNoteID.uuidString, missingNoteID.uuidString])
        let response = makeResponse(noteIDs: [acknowledgedNoteID.uuidString])

        XCTAssertFalse(
            SyncAcknowledgementValidator.hasCompleteAuthoritativeAcknowledgements(
                payload: payload,
                response: response
            )
        )
    }

    func testProtocol4AcknowledgementRejectsForeignMutationWithoutForcedMarker() {
        let noteID = UUID()
        let submitted = makeNoteDTO(id: noteID.uuidString, mutationId: "mutation-a")
        let payload = SyncPayload(
            protocolVersion: 4,
            cursor: nil,
            deviceId: "device-a",
            notes: [submitted],
            tags: nil,
            hardDeletedNoteIds: nil,
            hardDeletedTagIds: nil,
            preferences: nil
        )
        let response = SyncResponse(
            cursor: "2",
            changes: SyncChanges(
                notes: [makeNoteDTO(id: noteID.uuidString, mutationId: "mutation-b")],
                tags: nil,
                hardDeletedNoteIds: nil,
                hardDeletedTagIds: nil,
                preferences: nil
            ),
            conflicts: [],
            serverTime: iso(Date(timeIntervalSince1970: 1_700_000_000))
        )

        XCTAssertFalse(
            SyncAcknowledgementValidator.hasCompleteAuthoritativeAcknowledgements(
                payload: payload,
                response: response
            )
        )
    }

    func testProtocol4AcknowledgementAcceptsForeignMutationOnlyWhenForced() {
        let tagID = UUID()
        let submitted = makeTagDTO(id: tagID.uuidString, mutationId: "mutation-a")
        let payload = SyncPayload(
            protocolVersion: 4,
            cursor: nil,
            deviceId: "device-a",
            notes: [],
            tags: [submitted],
            hardDeletedNoteIds: nil,
            hardDeletedTagIds: nil,
            preferences: nil
        )
        let response = SyncResponse(
            cursor: "2",
            changes: SyncChanges(
                notes: [],
                tags: [makeTagDTO(id: tagID.uuidString, mutationId: "mutation-b")],
                hardDeletedNoteIds: nil,
                hardDeletedTagIds: nil,
                preferences: nil
            ),
            conflicts: [],
            forcedTagIds: [tagID.uuidString],
            serverTime: iso(Date(timeIntervalSince1970: 1_700_000_000))
        )

        XCTAssertTrue(
            SyncAcknowledgementValidator.hasCompleteAuthoritativeAcknowledgements(
                payload: payload,
                response: response
            )
        )
    }

    func testProtocol4AcknowledgementRejectsForcedIDsWithoutEntityChanges() {
        let noteID = UUID()
        let tagID = UUID()
        let payload = SyncPayload(
            protocolVersion: 4,
            cursor: nil,
            deviceId: "device-a",
            notes: [],
            tags: nil,
            hardDeletedNoteIds: nil,
            hardDeletedTagIds: nil,
            preferences: nil
        )
        let response = SyncResponse(
            cursor: "2",
            changes: SyncChanges(
                notes: [],
                tags: nil,
                hardDeletedNoteIds: [noteID.uuidString],
                hardDeletedTagIds: [tagID.uuidString],
                preferences: nil
            ),
            conflicts: [],
            forcedNoteIds: [noteID.uuidString],
            forcedTagIds: [tagID.uuidString],
            serverTime: iso(Date(timeIntervalSince1970: 1_700_000_000))
        )

        XCTAssertFalse(
            SyncAcknowledgementValidator.hasCompleteAuthoritativeAcknowledgements(
                payload: payload,
                response: response
            )
        )
    }

    func testAcknowledgementValidationRejectsNoteEntityAsHardDeleteAcknowledgement() {
        let noteID = UUID()
        let payload = makePayload(hardDeletedNoteIDs: [noteID.uuidString])
        let response = makeResponse(noteIDs: [noteID.uuidString])

        XCTAssertFalse(
            SyncAcknowledgementValidator.hasCompleteAuthoritativeAcknowledgements(
                payload: payload,
                response: response
            )
        )
    }

    func testAcknowledgementValidationRejectsTagEntityAsHardDeleteAcknowledgement() {
        let tagID = UUID()
        let payload = makePayload(hardDeletedTagIDs: [tagID.uuidString])
        let response = makeResponse(tagIDs: [tagID.uuidString])

        XCTAssertFalse(
            SyncAcknowledgementValidator.hasCompleteAuthoritativeAcknowledgements(
                payload: payload,
                response: response
            )
        )
    }

    private func makePayload(
        noteIDs: [String] = [],
        tagIDs: [String] = [],
        hardDeletedNoteIDs: [String] = [],
        hardDeletedTagIDs: [String] = []
    ) -> SyncPayload {
        SyncPayload(
            protocolVersion: 3,
            cursor: nil,
            deviceId: "test-device",
            notes: noteIDs.map { makeNoteDTO(id: $0) },
            tags: tagIDs.map { makeTagDTO(id: $0) },
            hardDeletedNoteIds: hardDeletedNoteIDs,
            hardDeletedTagIds: hardDeletedTagIDs,
            preferences: nil
        )
    }

    private func makeResponse(
        noteIDs: [String] = [],
        tagIDs: [String] = [],
        hardDeletedNoteIDs: [String] = [],
        hardDeletedTagIDs: [String] = []
    ) -> SyncResponse {
        SyncResponse(
            cursor: "2",
            changes: SyncChanges(
                notes: noteIDs.map { makeNoteDTO(id: $0) },
                tags: tagIDs.map { makeTagDTO(id: $0) },
                hardDeletedNoteIds: hardDeletedNoteIDs,
                hardDeletedTagIds: hardDeletedTagIDs,
                preferences: nil
            ),
            conflicts: [],
            serverTime: iso(Date(timeIntervalSince1970: 1_700_000_000))
        )
    }

    private func makeNoteDTO(id: String, mutationId: String? = nil) -> NoteDTO {
        NoteDTO(
            id: id,
            content: "note",
            createdAt: iso(Date(timeIntervalSince1970: 1_700_000_000)),
            updatedAt: nil,
            deletedAt: nil,
            pinnedAt: nil,
            tagIds: nil,
            version: 1,
            baseVersion: nil,
            clientUpdatedAt: nil,
            lastModifiedByDeviceId: nil,
            mutationId: mutationId
        )
    }

    private func makeTagDTO(id: String, mutationId: String? = nil) -> TagDTO {
        TagDTO(
            id: id,
            name: "tag",
            colorHex: "#000000",
            createdAt: iso(Date(timeIntervalSince1970: 1_700_000_000)),
            updatedAt: nil,
            lastUsedAt: nil,
            sortOrder: 0,
            parentId: nil,
            deletedAt: nil,
            version: 1,
            baseVersion: nil,
            clientUpdatedAt: nil,
            lastModifiedByDeviceId: nil,
            mutationId: mutationId
        )
    }

    private func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
