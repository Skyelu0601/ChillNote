package com.sponteoai.chillscript.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.sponteoai.chillscript.data.local.ChillScriptDatabase
import com.sponteoai.chillscript.data.local.NoteEntity
import com.sponteoai.chillscript.data.local.NoteTagCrossRef
import com.sponteoai.chillscript.data.local.PendingHardDeleteEntity
import com.sponteoai.chillscript.data.local.SyncStateEntity
import com.sponteoai.chillscript.data.local.TagEntity
import com.sponteoai.chillscript.data.remote.NoteDto
import com.sponteoai.chillscript.data.remote.ConflictDto
import com.sponteoai.chillscript.data.remote.SyncChanges
import com.sponteoai.chillscript.data.remote.SyncClient
import com.sponteoai.chillscript.data.remote.SyncPayload
import com.sponteoai.chillscript.data.remote.SyncResponse
import com.sponteoai.chillscript.data.remote.TagDto
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeoutOrNull
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.IOException
import java.util.Collections
import java.util.concurrent.atomic.AtomicInteger

@RunWith(AndroidJUnit4::class)
class NotesRepositorySyncTest {
    private lateinit var database: ChillScriptDatabase

    @Before
    fun setUp() {
        database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            ChillScriptDatabase::class.java,
        ).allowMainThreadQueries().build()
    }

    @After
    fun tearDown() {
        database.close()
    }

    @Test
    fun syncUploadsLocalChangesAndAppliesCompleteRemoteState() = runBlocking {
        val dao = database.dao()
        val userId = "user-1"
        val timestamp = "2026-07-13T00:00:00Z"
        val localNote = NoteEntity(
            id = "local-note",
            userId = userId,
            content = "Local draft",
            previewPlainText = "Local draft",
            createdAt = timestamp,
            updatedAt = timestamp,
            serverVersion = 1,
        )
        val localTag = TagEntity(
            id = "local-tag",
            userId = userId,
            name = "Ideas",
            colorHex = "#5EAFA5",
            createdAt = timestamp,
            updatedAt = timestamp,
            lastUsedAt = timestamp,
            serverVersion = 1,
        )
        val remotelyDeletedNote = localNote.copy(id = "remote-deleted-note", content = "Remove me")
        dao.upsertNotes(listOf(localNote, remotelyDeletedNote))
        dao.upsertTag(localTag)
        dao.upsertNoteTags(listOf(NoteTagCrossRef(localNote.id, localTag.id)))
        dao.upsertSyncState(
            SyncStateEntity(userId, cursor = "cursor-1", deviceId = "device-1", lastSyncedAt = timestamp),
        )
        dao.enqueueHardDelete(
            PendingHardDeleteEntity("note:gone-note", userId, "note", "gone-note", timestamp),
        )

        var capturedToken: String? = null
        var capturedPayload: SyncPayload? = null
        val remoteNote = NoteDto(
            id = "remote-note",
            content = "Tasks\n- [ ] Draft hook\n- [x] Publish",
            createdAt = timestamp,
            updatedAt = "2026-07-13T01:00:00Z",
            tagIds = listOf("remote-tag"),
            version = 3,
            section = "drafts",
        )
        val remoteTag = TagDto(
            id = "remote-tag",
            name = "Remote",
            colorHex = "#8B5CF6",
            createdAt = timestamp,
            updatedAt = timestamp,
            lastUsedAt = timestamp,
            sortOrder = 0,
            version = 2,
        )
        val client = SyncClient { token, payload ->
            capturedToken = token
            capturedPayload = payload
            SyncResponse(
                cursor = "cursor-2",
                changes = SyncChanges(
                    notes = listOf(
                        NoteDto(
                            id = localNote.id,
                            content = localNote.content,
                            createdAt = localNote.createdAt,
                            updatedAt = localNote.updatedAt,
                            tagIds = listOf(localTag.id),
                            version = 2,
                            mutationId = payload.notes.single { it.id == localNote.id }.mutationId,
                        ),
                        remoteNote,
                    ),
                    tags = listOf(
                        TagDto(
                            id = localTag.id,
                            name = localTag.name,
                            colorHex = localTag.colorHex,
                            createdAt = localTag.createdAt,
                            updatedAt = localTag.updatedAt,
                            lastUsedAt = localTag.lastUsedAt,
                            sortOrder = localTag.sortOrder,
                            version = 2,
                            mutationId = payload.tags.single { it.id == localTag.id }.mutationId,
                        ),
                        remoteTag,
                    ),
                    hardDeletedNoteIds = listOf(remotelyDeletedNote.id, "gone-note"),
                ),
                conflicts = listOf(
                    ConflictDto(
                        entityType = "note",
                        id = remotelyDeletedNote.id,
                        serverVersion = 0,
                        clientContent = remotelyDeletedNote.content,
                        message = "sync.conflict.hard_deleted",
                    ),
                ),
                serverTime = "2026-07-13T02:00:00Z",
            )
        }

        NotesRepository(dao, client).sync(userId, "access-token")

        assertEquals("access-token", capturedToken)
        val upload = requireNotNull(capturedPayload)
        assertTrue(upload.deviceId?.isNotBlank() == true)
        assertEquals(4, upload.protocolVersion)
        assertEquals(setOf("local-note", "remote-deleted-note"), upload.notes.mapTo(mutableSetOf()) { it.id })
        assertEquals(listOf("local-tag"), upload.notes.first { it.id == localNote.id }.tagIds)
        assertEquals(listOf("gone-note"), upload.hardDeletedNoteIds)

        assertFalse(requireNotNull(dao.note(userId, localNote.id)).needsSync)
        assertNull(dao.note(userId, remotelyDeletedNote.id))
        val storedRemoteNote = dao.note(userId, remoteNote.id)
        assertNotNull(storedRemoteNote)
        assertFalse(requireNotNull(storedRemoteNote).needsSync)
        assertEquals("drafts", storedRemoteNote.section)
        assertEquals(listOf("remote-tag"), dao.tagIdsForNote(remoteNote.id))
        assertEquals(listOf("Draft hook", "Publish"), dao.checklistItems(remoteNote.id).map { it.text })
        assertEquals(listOf(false, true), dao.checklistItems(remoteNote.id).map { it.isDone })
        assertTrue(dao.pendingHardDeletes(userId, "note").isEmpty())
        assertEquals("cursor-2", dao.syncState(userId)?.cursor)
        assertEquals("2026-07-13T02:00:00Z", dao.syncState(userId)?.lastSyncedAt)
        assertEquals("Remote", dao.activeTags(userId).first { it.id == remoteTag.id }.name)
    }

    @Test
    fun concurrentSyncCallsAreSerialized() = runBlocking {
        val dao = database.dao()
        val userId = "user-serialized"
        val firstRequestStarted = CompletableDeferred<Unit>()
        val releaseFirstRequest = CompletableDeferred<Unit>()
        val secondRequestStarted = CompletableDeferred<Unit>()
        val callCount = AtomicInteger(0)
        val activeCalls = AtomicInteger(0)
        val maxActiveCalls = AtomicInteger(0)
        val payloads = Collections.synchronizedList(mutableListOf<SyncPayload>())
        val client = SyncClient { _, payload ->
            val callNumber = callCount.incrementAndGet()
            payloads += payload
            val active = activeCalls.incrementAndGet()
            maxActiveCalls.updateAndGet { current -> maxOf(current, active) }
            try {
                if (callNumber == 1) {
                    firstRequestStarted.complete(Unit)
                    releaseFirstRequest.await()
                } else {
                    secondRequestStarted.complete(Unit)
                }
                SyncResponse(
                    cursor = "cursor-$callNumber",
                    changes = SyncChanges(notes = emptyList(), tags = emptyList()),
                    conflicts = emptyList(),
                    serverTime = "2026-07-13T0${callNumber}:00:00Z",
                )
            } finally {
                activeCalls.decrementAndGet()
            }
        }
        val repository = NotesRepository(dao, client)

        val firstSync = async { repository.sync(userId, "token") }
        firstRequestStarted.await()
        val secondSync = async { repository.sync(userId, "token") }
        val overlapped = withTimeoutOrNull(150) {
            secondRequestStarted.await()
            true
        } ?: false
        releaseFirstRequest.complete(Unit)
        firstSync.await()
        secondSync.await()

        assertFalse(overlapped)
        assertEquals(2, callCount.get())
        assertEquals(1, maxActiveCalls.get())
        assertNull(payloads[0].cursor)
        assertEquals("cursor-1", payloads[1].cursor)
        assertEquals("cursor-2", dao.syncState(userId)?.cursor)
    }

    @Test
    fun editDuringSyncStaysDirtyAndIsNotOverwrittenByResponse() = runBlocking {
        val dao = database.dao()
        val userId = "user-edit-during-sync"
        val uploadedAt = "2026-07-13T00:00:00Z"
        val editedAt = "2026-07-13T01:00:00Z"
        val serverAt = "2026-07-13T02:00:00Z"
        val note = NoteEntity(
            id = "note-being-edited",
            userId = userId,
            content = "Uploaded content",
            previewPlainText = "Uploaded content",
            createdAt = uploadedAt,
            updatedAt = uploadedAt,
            version = 1,
            serverVersion = 1,
        )
        val tag = TagEntity(
            id = "tag-being-edited",
            userId = userId,
            name = "Uploaded tag",
            colorHex = "#5EAFA5",
            createdAt = uploadedAt,
            updatedAt = uploadedAt,
            lastUsedAt = uploadedAt,
            version = 1,
            serverVersion = 1,
        )
        dao.upsertNote(note)
        dao.upsertTag(tag)
        dao.upsertNoteTags(listOf(NoteTagCrossRef(note.id, tag.id)))

        val requestStarted = CompletableDeferred<SyncPayload>()
        val releaseResponse = CompletableDeferred<Unit>()
        val client = SyncClient { _, payload ->
            requestStarted.complete(payload)
            releaseResponse.await()
            SyncResponse(
                cursor = "cursor-after-edit",
                changes = SyncChanges(
                    notes = listOf(
                        NoteDto(
                            id = note.id,
                            content = "Server response content",
                            createdAt = uploadedAt,
                            updatedAt = serverAt,
                            tagIds = emptyList(),
                            version = 2,
                            mutationId = payload.notes.single().mutationId,
                        ),
                    ),
                    tags = listOf(
                        TagDto(
                            id = tag.id,
                            name = "Server response tag",
                            colorHex = "#8B5CF6",
                            createdAt = uploadedAt,
                            updatedAt = serverAt,
                            lastUsedAt = serverAt,
                            sortOrder = 0,
                            version = 2,
                            mutationId = payload.tags.single().mutationId,
                        ),
                    ),
                ),
                conflicts = emptyList(),
                serverTime = serverAt,
            )
        }
        val repository = NotesRepository(dao, client)

        val sync = async { repository.sync(userId, "token") }
        val payload = requestStarted.await()
        assertEquals(4, payload.protocolVersion)
        assertNull(payload.notes.single().version)
        assertEquals(1, payload.notes.single().baseVersion)
        assertNotNull(payload.notes.single().mutationId)
        assertNull(payload.tags.single().version)
        assertEquals(1, payload.tags.single().baseVersion)
        assertNotNull(payload.tags.single().mutationId)

        dao.upsertNote(
            note.copy(
                content = "Local edit during request",
                previewPlainText = "Local edit during request",
                updatedAt = editedAt,
                version = 2,
                needsSync = true,
            ),
        )
        dao.upsertTag(
            tag.copy(
                name = "Local tag edit during request",
                updatedAt = editedAt,
                version = 2,
                needsSync = true,
            ),
        )
        releaseResponse.complete(Unit)
        sync.await()

        val storedNote = requireNotNull(dao.note(userId, note.id))
        val storedTag = requireNotNull(dao.tag(userId, tag.id))
        assertEquals("Local edit during request", storedNote.content)
        assertEquals(editedAt, storedNote.updatedAt)
        assertTrue(storedNote.needsSync)
        assertEquals("Local tag edit during request", storedTag.name)
        assertEquals(editedAt, storedTag.updatedAt)
        assertTrue(storedTag.needsSync)
        assertEquals(listOf(tag.id), dao.tagIdsForNote(note.id))
    }

    @Test
    fun olderRemoteVersionOrTimestampCannotReplaceNewerLocalState() = runBlocking {
        val dao = database.dao()
        val userId = "user-newer-local"
        val createdAt = "2026-07-13T00:00:00Z"
        val localUpdatedAt = "2026-07-13T05:00:00Z"
        val note = NoteEntity(
            id = "newer-local-note",
            userId = userId,
            content = "Newer local note",
            previewPlainText = "Newer local note",
            createdAt = createdAt,
            updatedAt = localUpdatedAt,
            version = 5,
            serverVersion = 5,
            needsSync = false,
        )
        val tag = TagEntity(
            id = "newer-local-tag",
            userId = userId,
            name = "Newer local tag",
            colorHex = "#5EAFA5",
            createdAt = createdAt,
            updatedAt = localUpdatedAt,
            lastUsedAt = localUpdatedAt,
            version = 4,
            serverVersion = 4,
            needsSync = false,
        )
        dao.upsertNote(note)
        dao.upsertTag(tag)

        val client = SyncClient { _, _ ->
            SyncResponse(
                cursor = "cursor-old-remote",
                changes = SyncChanges(
                    notes = listOf(
                        NoteDto(
                            id = note.id,
                            content = "Older remote version",
                            createdAt = createdAt,
                            updatedAt = "2026-07-13T06:00:00Z",
                            version = 4,
                        ),
                    ),
                    tags = listOf(
                        TagDto(
                            id = tag.id,
                            name = "Older remote timestamp",
                            colorHex = "#8B5CF6",
                            createdAt = createdAt,
                            updatedAt = "2026-07-13T04:00:00Z",
                            lastUsedAt = createdAt,
                            sortOrder = 0,
                            version = 4,
                        ),
                    ),
                ),
                conflicts = emptyList(),
                serverTime = "2026-07-13T07:00:00Z",
            )
        }

        NotesRepository(dao, client).sync(userId, "token")

        val storedNote = requireNotNull(dao.note(userId, note.id))
        val storedTag = requireNotNull(dao.tag(userId, tag.id))
        assertEquals("Newer local note", storedNote.content)
        assertEquals(5, storedNote.version)
        assertEquals(localUpdatedAt, storedNote.updatedAt)
        assertEquals("Newer local tag", storedTag.name)
        assertEquals(4, storedTag.version)
        assertEquals(localUpdatedAt, storedTag.updatedAt)
    }

    @Test
    fun migratedCleanRowWithoutServerVersionAcceptsBootstrapAuthority() = runBlocking {
        val dao = database.dao()
        val userId = "user-clean-bootstrap"
        val createdAt = "2026-07-13T00:00:00Z"
        val cleanLegacyNote = NoteEntity(
            id = "clean-legacy-note",
            userId = userId,
            content = "Locally inflated legacy value",
            previewPlainText = "Locally inflated legacy value",
            createdAt = createdAt,
            updatedAt = "2026-07-13T09:00:00Z",
            version = 12,
            serverVersion = null,
            needsSync = false,
        )
        dao.upsertNote(cleanLegacyNote)
        val client = SyncClient { _, payload ->
            assertNull(payload.cursor)
            assertEquals(4, payload.protocolVersion)
            assertTrue(payload.notes.isEmpty())
            SyncResponse(
                cursor = "bootstrap-cursor",
                changes = SyncChanges(
                    notes = listOf(
                        NoteDto(
                            id = cleanLegacyNote.id,
                            content = "Authoritative iOS content",
                            createdAt = createdAt,
                            updatedAt = "2026-07-13T01:00:00Z",
                            version = 2,
                        ),
                    ),
                ),
                conflicts = emptyList(),
                serverTime = "2026-07-13T10:00:00Z",
            )
        }

        NotesRepository(dao, client).sync(userId, "token")

        val stored = requireNotNull(dao.note(userId, cleanLegacyNote.id))
        assertEquals("Authoritative iOS content", stored.content)
        assertEquals(12, stored.version)
        assertEquals(2, stored.serverVersion)
        assertFalse(stored.needsSync)
        assertEquals("bootstrap-cursor", dao.syncState(userId)?.cursor)
    }

    @Test
    fun syncCollapsesUuidCaseVariantsAndKeepsNewestNote() = runBlocking {
        val dao = database.dao()
        val userId = "user-case-variants"
        val lowerId = "123e4567-e89b-42d3-a456-426614174000"
        val upperId = lowerId.uppercase()
        val old = NoteEntity(
            id = lowerId,
            userId = userId,
            content = "Before iOS edit",
            previewPlainText = "Before iOS edit",
            createdAt = "2026-07-13T00:00:00Z",
            updatedAt = "2026-07-13T00:00:00Z",
            version = 1,
            needsSync = false,
        )
        val edited = old.copy(
            id = upperId,
            content = "After iOS edit",
            previewPlainText = "After iOS edit",
            updatedAt = "2026-07-13T01:00:00Z",
            version = 2,
        )
        dao.upsertNotes(listOf(old, edited))
        val client = SyncClient { _, _ ->
            SyncResponse(
                cursor = "case-cursor",
                changes = SyncChanges(notes = emptyList()),
                conflicts = emptyList(),
                serverTime = "2026-07-13T02:00:00Z",
            )
        }

        NotesRepository(dao, client).sync(userId, "token")

        assertNull(dao.note(userId, lowerId))
        assertEquals("After iOS edit", dao.note(userId, upperId)?.content)
    }

    @Test
    fun remoteUuidCaseVariantUpdatesExistingRowInsteadOfInsertingDuplicate() = runBlocking {
        val dao = database.dao()
        val userId = "user-remote-case-variant"
        val lowerId = "123e4567-e89b-42d3-a456-426614174000"
        val upperId = lowerId.uppercase()
        val local = NoteEntity(
            id = lowerId,
            userId = userId,
            content = "Before",
            previewPlainText = "Before",
            createdAt = "2026-07-13T00:00:00Z",
            updatedAt = "2026-07-13T00:00:00Z",
            version = 1,
            needsSync = false,
        )
        dao.upsertNote(local)
        val client = SyncClient { _, _ ->
            SyncResponse(
                cursor = "case-cursor",
                changes = SyncChanges(
                    notes = listOf(
                        NoteDto(
                            id = upperId,
                            content = "After iOS edit",
                            createdAt = local.createdAt,
                            updatedAt = "2026-07-13T01:00:00Z",
                            version = 2,
                        ),
                    ),
                ),
                conflicts = emptyList(),
                serverTime = "2026-07-13T02:00:00Z",
            )
        }

        NotesRepository(dao, client).sync(userId, "token")

        assertEquals("After iOS edit", dao.note(userId, lowerId)?.content)
        assertNull(dao.note(userId, upperId))
    }

    @Test
    fun conflictWithoutAuthoritativeChangeDoesNotAcknowledgeUploadOrAdvanceCursor() = runBlocking {
        val dao = database.dao()
        val userId = "user-missing-conflict-authority"
        val timestamp = "2026-07-13T00:00:00Z"
        val note = NoteEntity(
            id = "conflicted-note",
            userId = userId,
            content = "Local edit",
            previewPlainText = "Local edit",
            createdAt = timestamp,
            updatedAt = timestamp,
            version = 2,
            serverVersion = 1,
            needsSync = true,
        )
        dao.upsertNote(note)
        val client = SyncClient { _, _ ->
            SyncResponse(
                cursor = "must-not-advance",
                changes = SyncChanges(notes = emptyList()),
                conflicts = listOf(
                    ConflictDto(
                        entityType = "note",
                        id = note.id,
                        serverVersion = 2,
                        serverContent = "Server edit",
                        clientContent = note.content,
                        message = "conflict",
                    ),
                ),
                serverTime = "2026-07-13T01:00:00Z",
            )
        }

        val error = runCatching { NotesRepository(dao, client).sync(userId, "token") }.exceptionOrNull()

        assertTrue(error is SyncProtocolException)
        assertTrue(requireNotNull(dao.note(userId, note.id)).needsSync)
        assertNull(dao.syncState(userId))
    }

    @Test
    fun acceptedUploadWithoutAuthoritativeChangeDoesNotAcknowledgeOrAdvanceCursor() = runBlocking {
        val dao = database.dao()
        val userId = "user-missing-accepted-authority"
        val timestamp = "2026-07-13T00:00:00Z"
        val note = NoteEntity(
            id = "accepted-but-not-echoed-note",
            userId = userId,
            content = "Local edit",
            previewPlainText = "Local edit",
            createdAt = timestamp,
            updatedAt = timestamp,
            version = 2,
            serverVersion = 1,
            needsSync = true,
        )
        dao.upsertNote(note)
        val client = SyncClient { _, payload ->
            assertEquals(4, payload.protocolVersion)
            SyncResponse(
                cursor = "must-not-advance",
                changes = SyncChanges(notes = emptyList()),
                conflicts = emptyList(),
                serverTime = "2026-07-13T01:00:00Z",
            )
        }

        val error = runCatching { NotesRepository(dao, client).sync(userId, "token") }.exceptionOrNull()

        assertTrue(error is SyncProtocolException)
        assertTrue(requireNotNull(dao.note(userId, note.id)).needsSync)
        assertNull(dao.syncState(userId))
    }

    @Test
    fun acceptedUploadWithDifferentMutationDoesNotAcknowledgeOrAdvanceCursor() = runBlocking {
        val dao = database.dao()
        val userId = "user-wrong-mutation-authority"
        val timestamp = "2026-07-13T00:00:00Z"
        val note = NoteEntity(
            id = "wrong-mutation-note",
            userId = userId,
            content = "Local edit",
            previewPlainText = "Local edit",
            createdAt = timestamp,
            updatedAt = timestamp,
            version = 2,
            serverVersion = 1,
            needsSync = true,
        )
        dao.upsertNote(note)
        val client = SyncClient { _, payload ->
            assertNotNull(payload.notes.single().mutationId)
            SyncResponse(
                cursor = "must-not-advance",
                changes = SyncChanges(
                    notes = listOf(
                        NoteDto(
                            id = note.id,
                            content = "Foreign state",
                            createdAt = timestamp,
                            updatedAt = timestamp,
                            version = 2,
                            mutationId = "different-device-mutation",
                        ),
                    ),
                ),
                conflicts = emptyList(),
                serverTime = timestamp,
            )
        }

        val error = runCatching { NotesRepository(dao, client).sync(userId, "token") }.exceptionOrNull()

        assertTrue(error is SyncProtocolException)
        assertEquals("Local edit", dao.note(userId, note.id)?.content)
        assertTrue(requireNotNull(dao.note(userId, note.id)).needsSync)
        assertNull(dao.syncState(userId))
    }

    @Test
    fun hardDeletedNoteUploadRequiresExplicitServerTombstone() = runBlocking {
        val dao = database.dao()
        val userId = "user-missing-note-tombstone"
        val noteId = "permanently-deleted-note"
        val timestamp = "2026-07-13T00:00:00Z"
        dao.enqueueHardDelete(
            PendingHardDeleteEntity("note:$noteId", userId, "note", noteId, timestamp),
        )
        dao.upsertSyncState(
            SyncStateEntity(userId, cursor = "cursor-before", deviceId = "device-1", lastSyncedAt = timestamp),
        )
        val client = SyncClient { _, payload ->
            assertEquals(listOf(noteId), payload.hardDeletedNoteIds)
            SyncResponse(
                cursor = "cursor-after",
                changes = SyncChanges(
                    // An entity echo must not acknowledge a permanent-delete request.
                    notes = listOf(
                        NoteDto(
                            id = noteId,
                            content = "Must not be restored",
                            createdAt = timestamp,
                            updatedAt = timestamp,
                            version = 2,
                        ),
                    ),
                ),
                conflicts = emptyList(),
                serverTime = timestamp,
            )
        }

        val error = runCatching { NotesRepository(dao, client).sync(userId, "token") }.exceptionOrNull()

        assertTrue(error is SyncProtocolException)
        assertEquals(listOf(noteId), dao.pendingHardDeletes(userId, "note").map { it.entityId })
        assertEquals("cursor-before", dao.syncState(userId)?.cursor)
        assertNull(dao.note(userId, noteId))
    }

    @Test
    fun hardDeletedTagUploadRequiresExplicitServerTombstone() = runBlocking {
        val dao = database.dao()
        val userId = "user-missing-tag-tombstone"
        val tagId = "permanently-deleted-tag"
        val timestamp = "2026-07-13T00:00:00Z"
        dao.enqueueHardDelete(
            PendingHardDeleteEntity("tag:$tagId", userId, "tag", tagId, timestamp),
        )
        dao.upsertSyncState(
            SyncStateEntity(userId, cursor = "cursor-before", deviceId = "device-1", lastSyncedAt = timestamp),
        )
        val client = SyncClient { _, payload ->
            assertEquals(listOf(tagId), payload.hardDeletedTagIds)
            SyncResponse(
                cursor = "cursor-after",
                changes = SyncChanges(
                    notes = emptyList(),
                    // An entity echo must not acknowledge a permanent-delete request.
                    tags = listOf(
                        TagDto(
                            id = tagId,
                            name = "Must not be restored",
                            colorHex = "#5EAFA5",
                            createdAt = timestamp,
                            updatedAt = timestamp,
                            lastUsedAt = timestamp,
                            sortOrder = 0,
                            version = 2,
                        ),
                    ),
                ),
                conflicts = emptyList(),
                serverTime = timestamp,
            )
        }

        val error = runCatching { NotesRepository(dao, client).sync(userId, "token") }.exceptionOrNull()

        assertTrue(error is SyncProtocolException)
        assertEquals(listOf(tagId), dao.pendingHardDeletes(userId, "tag").map { it.entityId })
        assertEquals("cursor-before", dao.syncState(userId)?.cursor)
        assertNull(dao.tag(userId, tagId))
    }

    @Test
    fun initialBootstrapRebasesLegacyDirtyRowsAndSurvivesProcessDeathBeforeUploadAck() = runBlocking {
        val dao = database.dao()
        val userId = "user-legacy-baseline"
        val timestamp = "2026-07-13T00:00:00Z"
        val note = NoteEntity(
            id = "legacy-dirty-note",
            userId = userId,
            content = "Legacy local note",
            previewPlainText = "Legacy local note",
            createdAt = timestamp,
            updatedAt = "2026-07-13T02:00:00Z",
            version = 11,
            serverVersion = null,
            needsSync = true,
        )
        val tag = TagEntity(
            id = "legacy-dirty-tag",
            userId = userId,
            name = "Legacy local tag",
            colorHex = "#5EAFA5",
            createdAt = timestamp,
            updatedAt = "2026-07-13T02:00:00Z",
            lastUsedAt = "2026-07-13T02:00:00Z",
            version = 9,
            serverVersion = null,
            needsSync = true,
        )
        dao.upsertNote(note)
        dao.upsertTag(tag)
        dao.upsertNoteTags(listOf(NoteTagCrossRef(note.id, tag.id)))
        val firstProcessCallCount = AtomicInteger(0)
        val firstProcessClient = SyncClient { _, payload ->
            when (firstProcessCallCount.incrementAndGet()) {
                1 -> {
                    assertEquals(4, payload.protocolVersion)
                    assertNull(payload.cursor)
                    assertTrue(payload.notes.isEmpty())
                    assertTrue(payload.tags.isEmpty())
                    assertTrue(payload.hardDeletedNoteIds.orEmpty().isEmpty())
                    assertTrue(payload.hardDeletedTagIds.orEmpty().isEmpty())
                    SyncResponse(
                        cursor = "legacy-baseline-cursor",
                        changes = SyncChanges(
                            notes = listOf(
                                NoteDto(
                                    id = note.id,
                                    content = "Remote edit made before bootstrap",
                                    createdAt = timestamp,
                                    updatedAt = "2026-07-13T03:00:00Z",
                                    version = 2,
                                    mutationId = "ios-baseline-mutation",
                                    tagIds = listOf(tag.id),
                                ),
                            ),
                            // The missing tag is an authoritative "known absent" baseline.
                            tags = emptyList(),
                        ),
                        conflicts = emptyList(),
                        serverTime = "2026-07-13T03:00:00Z",
                    )
                }

                2 -> {
                    assertEquals(4, payload.protocolVersion)
                    assertEquals("legacy-baseline-cursor", payload.cursor)
                    assertEquals(2, payload.notes.single().baseVersion)
                    assertEquals("Legacy local note", payload.notes.single().content)
                    assertEquals(0, payload.tags.single().baseVersion)
                    assertEquals("Legacy local tag", payload.tags.single().name)
                    assertNotNull(payload.notes.single().mutationId)
                    assertNotNull(payload.tags.single().mutationId)
                    throw IOException("response lost after request left process")
                }

                else -> error("unexpected sync call")
            }
        }

        val firstError = runCatching {
            NotesRepository(dao, firstProcessClient).sync(userId, "token")
        }.exceptionOrNull()

        assertTrue(firstError is IOException)
        val rebasedNote = requireNotNull(dao.note(userId, note.id))
        val rebasedTag = requireNotNull(dao.tag(userId, tag.id))
        assertEquals("Legacy local note", rebasedNote.content)
        assertEquals(11, rebasedNote.version)
        assertEquals(2, rebasedNote.serverVersion)
        assertEquals("ios-baseline-mutation", rebasedNote.serverMutationId)
        assertTrue(rebasedNote.needsSync)
        assertNotNull(rebasedNote.lastSubmittedMutationId)
        assertEquals("Legacy local tag", rebasedTag.name)
        assertEquals(9, rebasedTag.version)
        assertEquals(0, rebasedTag.serverVersion)
        assertTrue(rebasedTag.needsSync)
        assertNotNull(rebasedTag.lastSubmittedMutationId)
        assertEquals("legacy-baseline-cursor", dao.syncState(userId)?.cursor)

        val noteMutationId = rebasedNote.lastSubmittedMutationId
        val tagMutationId = rebasedTag.lastSubmittedMutationId
        val restartedClient = SyncClient { _, payload ->
            assertEquals(4, payload.protocolVersion)
            assertEquals("legacy-baseline-cursor", payload.cursor)
            assertEquals(2, payload.notes.single().baseVersion)
            assertEquals(noteMutationId, payload.notes.single().mutationId)
            assertEquals(0, payload.tags.single().baseVersion)
            assertEquals(tagMutationId, payload.tags.single().mutationId)
            SyncResponse(
                cursor = "legacy-uploaded-cursor",
                changes = SyncChanges(
                    notes = listOf(
                        NoteDto(
                            id = note.id,
                            content = note.content,
                            createdAt = note.createdAt,
                            updatedAt = note.updatedAt,
                            version = 3,
                            mutationId = noteMutationId,
                            tagIds = listOf(tag.id),
                        ),
                    ),
                    tags = listOf(
                        TagDto(
                            id = tag.id,
                            name = tag.name,
                            colorHex = tag.colorHex,
                            createdAt = tag.createdAt,
                            updatedAt = tag.updatedAt,
                            lastUsedAt = tag.lastUsedAt,
                            sortOrder = tag.sortOrder,
                            version = 1,
                            mutationId = tagMutationId,
                        ),
                    ),
                ),
                conflicts = emptyList(),
                serverTime = "2026-07-13T04:00:00Z",
            )
        }

        NotesRepository(dao, restartedClient).sync(userId, "token")

        assertFalse(requireNotNull(dao.note(userId, note.id)).needsSync)
        assertFalse(requireNotNull(dao.tag(userId, tag.id)).needsSync)
        assertEquals("legacy-uploaded-cursor", dao.syncState(userId)?.cursor)
    }

    @Test
    fun initialBootstrapHardDeletedDirtyTagPreservesLocalBranchAndRelationships() = runBlocking {
        val dao = database.dao()
        val userId = "user-bootstrap-dirty-tag-tombstone"
        val timestamp = "2026-07-13T00:00:00Z"
        val deletedTag = TagEntity(
            id = "123e4567-e89b-42d3-a456-426614174010",
            userId = userId,
            name = "Offline Android rename",
            colorHex = "#5EAFA5",
            createdAt = timestamp,
            updatedAt = "2026-07-13T02:00:00Z",
            lastUsedAt = "2026-07-13T02:00:00Z",
            version = 4,
            serverVersion = null,
            needsSync = true,
        )
        val child = TagEntity(
            id = "123e4567-e89b-42d3-a456-426614174011",
            userId = userId,
            name = "Child",
            colorHex = "#8B5CF6",
            createdAt = timestamp,
            updatedAt = timestamp,
            lastUsedAt = timestamp,
            parentId = deletedTag.id,
            serverVersion = 1,
            needsSync = false,
        )
        val note = NoteEntity(
            id = "123e4567-e89b-42d3-a456-426614174012",
            userId = userId,
            content = "Related note",
            previewPlainText = "Related note",
            createdAt = timestamp,
            updatedAt = timestamp,
            serverVersion = 1,
            needsSync = false,
        )
        dao.upsertTag(deletedTag)
        dao.upsertTag(child)
        dao.upsertNote(note)
        dao.upsertNoteTags(listOf(NoteTagCrossRef(note.id, deletedTag.id)))

        val callCount = AtomicInteger(0)
        var preservedTagId: String? = null
        val client = SyncClient { _, payload ->
            when (callCount.incrementAndGet()) {
                1 -> {
                    assertTrue(payload.notes.isEmpty())
                    assertTrue(payload.tags.isEmpty())
                    SyncResponse(
                        cursor = "bootstrap-tombstone-cursor",
                        changes = SyncChanges(
                            notes = emptyList(),
                            tags = emptyList(),
                            hardDeletedTagIds = listOf(deletedTag.id.uppercase()),
                        ),
                        conflicts = emptyList(),
                        serverTime = timestamp,
                    )
                }

                2 -> {
                    assertEquals("bootstrap-tombstone-cursor", payload.cursor)
                    assertTrue(payload.tags.none { it.id.equals(deletedTag.id, ignoreCase = true) })
                    preservedTagId = payload.tags.single { it.name == deletedTag.name }.id
                    assertEquals(0, payload.tags.single { it.id == preservedTagId }.baseVersion)
                    assertEquals(preservedTagId, payload.tags.single { it.name == child.name }.parentId)
                    assertEquals(listOf(preservedTagId), payload.notes.single { it.id == note.id }.tagIds)
                    SyncResponse(
                        cursor = "preserved-tag-uploaded-cursor",
                        changes = SyncChanges(
                            notes = payload.notes.map { it.copy(version = (it.baseVersion ?: 0) + 1) },
                            tags = payload.tags.map { it.copy(version = (it.baseVersion ?: 0) + 1) },
                        ),
                        conflicts = emptyList(),
                        serverTime = "2026-07-13T03:00:00Z",
                    )
                }

                else -> error("unexpected sync call")
            }
        }

        NotesRepository(dao, client).sync(userId, "token")

        val cloneId = requireNotNull(preservedTagId)
        assertNull(dao.tag(userId, deletedTag.id))
        assertEquals(deletedTag.name, dao.tag(userId, cloneId)?.name)
        assertFalse(requireNotNull(dao.tag(userId, cloneId)).needsSync)
        assertEquals(cloneId, dao.tag(userId, child.id)?.parentId)
        assertEquals(listOf(cloneId), dao.tagIdsForNote(note.id))
        assertEquals("preserved-tag-uploaded-cursor", dao.syncState(userId)?.cursor)
    }

    @Test
    fun newEntityAfterBootstrapUsesProtocol4EvenWithoutServerVersion() = runBlocking {
        val dao = database.dao()
        val userId = "user-post-bootstrap-create"
        val timestamp = "2026-07-13T00:00:00Z"
        val note = NoteEntity(
            id = "new-after-bootstrap",
            userId = userId,
            content = "New local note",
            previewPlainText = "New local note",
            createdAt = timestamp,
            updatedAt = timestamp,
            serverVersion = null,
            needsSync = true,
        )
        dao.upsertNote(note)
        dao.upsertSyncState(
            SyncStateEntity(
                userId = userId,
                cursor = "existing-cursor",
                deviceId = "device-1",
                lastSyncedAt = timestamp,
            ),
        )
        val client = SyncClient { _, payload ->
            assertEquals(4, payload.protocolVersion)
            assertEquals("existing-cursor", payload.cursor)
            assertEquals(0, payload.notes.single().baseVersion)
            SyncResponse(
                cursor = "next-cursor",
                changes = SyncChanges(
                    notes = listOf(
                        NoteDto(
                            id = note.id,
                            content = note.content,
                            createdAt = timestamp,
                            updatedAt = timestamp,
                            version = 1,
                            mutationId = payload.notes.single().mutationId,
                        ),
                    ),
                ),
                conflicts = emptyList(),
                serverTime = timestamp,
            )
        }

        NotesRepository(dao, client).sync(userId, "token")

        val stored = requireNotNull(dao.note(userId, note.id))
        assertEquals(1, stored.serverVersion)
        assertFalse(stored.needsSync)
        assertEquals("next-cursor", dao.syncState(userId)?.cursor)
    }

    @Test
    fun newNoteAndTagRecoverAckLossAfterASecondLocalEdit() = runBlocking {
        val dao = database.dao()
        val userId = "user-new-ack-loss"
        val createdAt = "2026-07-13T00:00:00Z"
        val note = NoteEntity(
            id = "new-note-ack-loss",
            userId = userId,
            content = "A1 note",
            previewPlainText = "A1 note",
            createdAt = createdAt,
            updatedAt = "2026-07-13T01:00:00Z",
            needsSync = true,
        )
        val tag = TagEntity(
            id = "new-tag-ack-loss",
            userId = userId,
            name = "A1 tag",
            colorHex = "#5EAFA5",
            createdAt = createdAt,
            updatedAt = "2026-07-13T01:00:00Z",
            lastUsedAt = "2026-07-13T01:00:00Z",
            needsSync = true,
        )
        dao.upsertNote(note)
        dao.upsertTag(tag)
        dao.upsertNoteTags(listOf(NoteTagCrossRef(note.id, tag.id)))
        dao.upsertSyncState(
            SyncStateEntity(userId, cursor = "existing-cursor", deviceId = "device-1", lastSyncedAt = createdAt),
        )

        val firstPayload = CompletableDeferred<SyncPayload>()
        val firstClient = SyncClient { _, payload ->
            firstPayload.complete(payload)
            throw IOException("A1 committed, response lost")
        }
        val firstError = runCatching { NotesRepository(dao, firstClient).sync(userId, "token") }.exceptionOrNull()

        assertTrue(firstError is IOException)
        val a1 = firstPayload.await()
        val noteMutation1 = requireNotNull(a1.notes.single().mutationId)
        val tagMutation1 = requireNotNull(a1.tags.single().mutationId)
        assertEquals(0, a1.notes.single().baseVersion)
        assertEquals(0, a1.tags.single().baseVersion)
        assertNull(a1.notes.single().previousMutationId)
        assertNull(a1.tags.single().previousMutationId)

        val persistedNote = requireNotNull(dao.note(userId, note.id))
        val persistedTag = requireNotNull(dao.tag(userId, tag.id))
        dao.upsertNote(
            persistedNote.copy(
                content = "A2 note",
                previewPlainText = "A2 note",
                updatedAt = "2026-07-13T02:00:00Z",
                version = persistedNote.version + 1,
                needsSync = true,
            ),
        )
        dao.upsertTag(
            persistedTag.copy(
                name = "A2 tag",
                updatedAt = "2026-07-13T02:00:00Z",
                lastUsedAt = "2026-07-13T02:00:00Z",
                version = persistedTag.version + 1,
                needsSync = true,
            ),
        )

        val secondClient = SyncClient { _, payload ->
            val uploadedNote = payload.notes.single()
            val uploadedTag = payload.tags.single()
            assertEquals(4, payload.protocolVersion)
            assertEquals(0, uploadedNote.baseVersion)
            assertEquals(0, uploadedTag.baseVersion)
            assertEquals(noteMutation1, uploadedNote.previousMutationId)
            assertEquals(tagMutation1, uploadedTag.previousMutationId)
            assertTrue(uploadedNote.mutationId != noteMutation1)
            assertTrue(uploadedTag.mutationId != tagMutation1)
            SyncResponse(
                cursor = "a2-accepted-cursor",
                changes = SyncChanges(
                    notes = listOf(
                        NoteDto(
                            id = note.id,
                            content = "A2 note",
                            createdAt = createdAt,
                            updatedAt = "2026-07-13T02:00:00Z",
                            version = 2,
                            baseVersion = 0,
                            mutationId = uploadedNote.mutationId,
                            tagIds = listOf(tag.id),
                        ),
                    ),
                    tags = listOf(
                        TagDto(
                            id = tag.id,
                            name = "A2 tag",
                            colorHex = tag.colorHex,
                            createdAt = createdAt,
                            updatedAt = "2026-07-13T02:00:00Z",
                            lastUsedAt = "2026-07-13T02:00:00Z",
                            sortOrder = 0,
                            version = 2,
                            baseVersion = 0,
                            mutationId = uploadedTag.mutationId,
                        ),
                    ),
                ),
                conflicts = emptyList(),
                serverTime = "2026-07-13T02:00:00Z",
            )
        }

        NotesRepository(dao, secondClient).sync(userId, "token")

        val acceptedNote = requireNotNull(dao.note(userId, note.id))
        val acceptedTag = requireNotNull(dao.tag(userId, tag.id))
        assertEquals("A2 note", acceptedNote.content)
        assertEquals(2, acceptedNote.serverVersion)
        assertFalse(acceptedNote.needsSync)
        assertEquals("A2 tag", acceptedTag.name)
        assertEquals(2, acceptedTag.serverVersion)
        assertFalse(acceptedTag.needsSync)
    }

    @Test
    fun ackLossThenRemoteEditCreatesConflictCopyInsteadOfLosingLatestLocalNote() = runBlocking {
        val dao = database.dao()
        val userId = "user-true-conflict"
        val noteId = "true-conflict-note"
        val createdAt = "2026-07-13T00:00:00Z"
        val original = NoteEntity(
            id = noteId,
            userId = userId,
            content = "Original",
            previewPlainText = "Original",
            createdAt = createdAt,
            updatedAt = createdAt,
            version = 1,
            serverVersion = 1,
            serverMutationId = "server-original",
            needsSync = false,
        )
        dao.upsertNote(
            original.copy(
                content = "Android A1",
                previewPlainText = "Android A1",
                updatedAt = "2026-07-13T01:00:00Z",
                version = 2,
                needsSync = true,
            ),
        )
        dao.upsertSyncState(
            SyncStateEntity(userId, cursor = "cursor-before-a1", deviceId = "device-1", lastSyncedAt = createdAt),
        )

        var mutationA1: String? = null
        val firstClient = SyncClient { _, payload ->
            val uploaded = payload.notes.single()
            assertEquals(1, uploaded.baseVersion)
            mutationA1 = uploaded.mutationId
            throw IOException("A1 committed at version 2, ACK lost")
        }
        val firstError = runCatching { NotesRepository(dao, firstClient).sync(userId, "token") }.exceptionOrNull()
        assertTrue(firstError is IOException)
        assertNotNull(mutationA1)

        val afterA1 = requireNotNull(dao.note(userId, noteId))
        dao.upsertNote(
            afterA1.copy(
                content = "Android A2 must survive",
                previewPlainText = "Android A2 must survive",
                updatedAt = "2026-07-13T03:00:00Z",
                version = afterA1.version + 1,
                needsSync = true,
            ),
        )

        val conflictClient = SyncClient { _, payload ->
            val uploaded = payload.notes.single()
            assertEquals(1, uploaded.baseVersion)
            assertEquals(mutationA1, uploaded.previousMutationId)
            assertTrue(uploaded.mutationId != mutationA1)
            SyncResponse(
                cursor = "cursor-after-conflict",
                changes = SyncChanges(
                    notes = listOf(
                        NoteDto(
                            id = noteId,
                            content = "iOS B",
                            createdAt = createdAt,
                            updatedAt = "2026-07-13T02:00:00Z",
                            version = 3,
                            mutationId = "ios-b-mutation",
                            tagIds = emptyList(),
                        ),
                    ),
                ),
                conflicts = listOf(
                    ConflictDto(
                        entityType = "note",
                        id = noteId,
                        serverVersion = 3,
                        serverContent = "iOS B",
                        clientContent = "Android A2 must survive",
                        message = "true concurrent edit",
                    ),
                ),
                serverTime = "2026-07-13T03:00:00Z",
            )
        }

        NotesRepository(dao, conflictClient).sync(userId, "token")

        val serverOriginal = requireNotNull(dao.note(userId, noteId))
        val localCopy = dao.notesForSyncIdentityCleanup(userId).single { it.id != noteId }
        assertEquals("iOS B", serverOriginal.content)
        assertEquals(3, serverOriginal.serverVersion)
        assertEquals("ios-b-mutation", serverOriginal.serverMutationId)
        assertFalse(serverOriginal.needsSync)
        assertEquals("Android A2 must survive", localCopy.content)
        assertEquals("drafts", localCopy.section)
        assertNull(localCopy.serverVersion)
        assertTrue(localCopy.needsSync)
    }

    @Test
    fun finishedImportForceWaitsForInFlightEditThenWinsOnNextRetryWithoutConflictCopy() = runBlocking {
        val dao = database.dao()
        val userId = "user-finished-import-force"
        val noteId = "finished-import-note"
        val createdAt = "2026-07-13T00:00:00Z"
        val queued = NoteEntity(
            id = noteId,
            userId = userId,
            content = "Queued placeholder",
            previewPlainText = "Queued placeholder",
            createdAt = createdAt,
            updatedAt = "2026-07-13T01:00:00Z",
            version = 1,
            serverVersion = 1,
            serverMutationId = "queued-server-mutation",
            importStatus = "queued",
            needsSync = true,
        )
        dao.upsertNote(queued)
        dao.upsertSyncState(
            SyncStateEntity(userId, cursor = "queued-cursor", deviceId = "device-1", lastSyncedAt = createdAt),
        )
        val firstRequest = CompletableDeferred<SyncPayload>()
        val releaseFirst = CompletableDeferred<Unit>()
        val callCount = AtomicInteger(0)
        val client = SyncClient { _, payload ->
            when (callCount.incrementAndGet()) {
                1 -> {
                    firstRequest.complete(payload)
                    releaseFirst.await()
                }

                2 -> {
                    assertEquals(2, payload.notes.single().baseVersion)
                    assertEquals("Local edit while import response was in flight", payload.notes.single().content)
                }

                else -> error("unexpected sync call")
            }
            SyncResponse(
                cursor = "finished-import-cursor-${callCount.get()}",
                changes = SyncChanges(
                    notes = listOf(
                        NoteDto(
                            id = noteId,
                            content = "Server generated transcript",
                            createdAt = createdAt,
                            updatedAt = "2026-07-13T02:00:00Z",
                            version = 2,
                            mutationId = "finished-import-mutation",
                            importStatus = "completed",
                            importCompletedAt = "2026-07-13T02:00:00Z",
                            tagIds = emptyList(),
                        ),
                    ),
                ),
                conflicts = emptyList(),
                forcedNoteIds = listOf(noteId),
                serverTime = "2026-07-13T02:00:00Z",
            )
        }
        val repository = NotesRepository(dao, client)

        val firstSync = async { repository.sync(userId, "token") }
        firstRequest.await()
        val prepared = requireNotNull(dao.note(userId, noteId))
        dao.upsertNote(
            prepared.copy(
                content = "Local edit while import response was in flight",
                previewPlainText = "Local edit while import response was in flight",
                updatedAt = "2026-07-13T03:00:00Z",
                version = prepared.version + 1,
                needsSync = true,
            ),
        )
        releaseFirst.complete(Unit)
        firstSync.await()

        val afterFirst = requireNotNull(dao.note(userId, noteId))
        assertEquals("Local edit while import response was in flight", afterFirst.content)
        assertEquals(2, afterFirst.serverVersion)
        assertEquals("finished-import-mutation", afterFirst.serverMutationId)
        assertTrue(afterFirst.needsSync)
        assertEquals(1, dao.notesForSyncIdentityCleanup(userId).size)

        repository.sync(userId, "token")

        val finished = requireNotNull(dao.note(userId, noteId))
        assertEquals("Server generated transcript", finished.content)
        assertEquals("completed", finished.importStatus)
        assertEquals(2, finished.serverVersion)
        assertFalse(finished.needsSync)
        assertEquals(1, dao.notesForSyncIdentityCleanup(userId).size)
    }

    @Test
    fun tagUuidCaseAliasesMergeRelationshipsAndChildrenIntoDirtyWinner() = runBlocking {
        val dao = database.dao()
        val userId = "user-tag-aliases"
        val lowerId = "123e4567-e89b-42d3-a456-426614174010"
        val upperId = lowerId.uppercase()
        val timestamp = "2026-07-13T00:00:00Z"
        val winner = TagEntity(
            id = lowerId,
            userId = userId,
            name = "Dirty local winner",
            colorHex = "#5EAFA5",
            createdAt = timestamp,
            updatedAt = "2026-07-13T01:00:00Z",
            lastUsedAt = timestamp,
            version = 2,
            needsSync = true,
        )
        val loser = winner.copy(
            id = upperId,
            name = "Clean alias",
            updatedAt = "2026-07-13T02:00:00Z",
            version = 99,
            needsSync = false,
        )
        val child = winner.copy(
            id = "child-tag",
            name = "Child",
            parentId = upperId,
            version = 1,
            needsSync = false,
        )
        val noteOnWinner = NoteEntity(
            id = "note-on-winner",
            userId = userId,
            content = "one",
            createdAt = timestamp,
            updatedAt = timestamp,
        )
        val noteOnLoser = noteOnWinner.copy(id = "note-on-loser", content = "two")
        dao.upsertTags(listOf(winner, loser, child))
        dao.upsertNotes(listOf(noteOnWinner, noteOnLoser))
        dao.upsertNoteTags(
            listOf(
                NoteTagCrossRef(noteOnWinner.id, lowerId),
                NoteTagCrossRef(noteOnLoser.id, upperId),
            ),
        )

        dao.collapseCaseVariantTags(userId)

        val merged = requireNotNull(dao.tag(userId, lowerId))
        assertEquals("Dirty local winner", merged.name)
        assertTrue(merged.needsSync)
        assertNull(dao.tag(userId, upperId))
        assertEquals(listOf(lowerId), dao.tagIdsForNote(noteOnWinner.id))
        assertEquals(listOf(lowerId), dao.tagIdsForNote(noteOnLoser.id))
        assertEquals(lowerId, requireNotNull(dao.tag(userId, child.id)).parentId)
    }

    @Test
    fun trueTagConflictPreservesLocalTagRelationshipsAndChildrenAsNewDirtyTag() = runBlocking {
        val dao = database.dao()
        val userId = "user-tag-conflict-copy"
        val tagId = "tag-conflict-original"
        val timestamp = "2026-07-13T00:00:00Z"
        val localTag = TagEntity(
            id = tagId,
            userId = userId,
            name = "Android local tag",
            colorHex = "#5EAFA5",
            createdAt = timestamp,
            updatedAt = "2026-07-13T01:00:00Z",
            lastUsedAt = "2026-07-13T01:00:00Z",
            version = 2,
            serverVersion = 1,
            serverMutationId = "tag-server-original",
            needsSync = true,
        )
        val child = localTag.copy(
            id = "tag-conflict-child",
            name = "Child",
            parentId = tagId,
            version = 1,
            serverVersion = 1,
            needsSync = false,
        )
        val note = NoteEntity(
            id = "tag-conflict-note",
            userId = userId,
            content = "Keep relationship",
            createdAt = timestamp,
            updatedAt = timestamp,
            serverVersion = 1,
            needsSync = false,
        )
        dao.upsertTags(listOf(localTag, child))
        dao.upsertNote(note)
        dao.upsertNoteTags(listOf(NoteTagCrossRef(note.id, tagId)))
        dao.upsertSyncState(
            SyncStateEntity(userId, cursor = "tag-conflict-cursor", deviceId = "device-1", lastSyncedAt = timestamp),
        )
        val client = SyncClient { _, _ ->
            SyncResponse(
                cursor = "tag-conflict-resolved",
                changes = SyncChanges(
                    notes = emptyList(),
                    tags = listOf(
                        TagDto(
                            id = tagId,
                            name = "iOS tag",
                            colorHex = "#8B5CF6",
                            createdAt = timestamp,
                            updatedAt = "2026-07-13T02:00:00Z",
                            lastUsedAt = "2026-07-13T02:00:00Z",
                            sortOrder = 0,
                            version = 2,
                            mutationId = "ios-tag-mutation",
                        ),
                    ),
                ),
                conflicts = listOf(
                    ConflictDto(
                        entityType = "tag",
                        id = tagId,
                        serverVersion = 2,
                        message = "true concurrent tag edit",
                    ),
                ),
                serverTime = "2026-07-13T02:00:00Z",
            )
        }

        NotesRepository(dao, client).sync(userId, "token")

        val serverTag = requireNotNull(dao.tag(userId, tagId))
        val localCopy = dao.tagsForSyncIdentityCleanup(userId)
            .single { it.id != tagId && it.id != child.id }
        assertEquals("iOS tag", serverTag.name)
        assertFalse(serverTag.needsSync)
        assertEquals("Android local tag", localCopy.name)
        assertTrue(localCopy.needsSync)
        assertNull(localCopy.serverVersion)
        assertEquals(listOf(localCopy.id), dao.tagIdsForNote(note.id))
        assertEquals(localCopy.id, requireNotNull(dao.tag(userId, child.id)).parentId)
        assertTrue(requireNotNull(dao.note(userId, note.id)).needsSync)
    }

    @Test
    fun conflictTombstonesAreAuthoritativeAndDeleteDirtyEntities() = runBlocking {
        val dao = database.dao()
        val userId = "user-conflict-tombstones"
        val noteId = "123e4567-e89b-42d3-a456-426614174002"
        val tagId = "123e4567-e89b-42d3-a456-426614174003"
        val timestamp = "2026-07-13T00:00:00Z"
        val note = NoteEntity(
            id = noteId,
            userId = userId,
            content = "First local note edit",
            previewPlainText = "First local note edit",
            createdAt = timestamp,
            updatedAt = "2026-07-13T01:00:00Z",
            version = 2,
            serverVersion = 1,
            needsSync = true,
        )
        val tag = TagEntity(
            id = tagId,
            userId = userId,
            name = "First local tag edit",
            colorHex = "#5EAFA5",
            createdAt = timestamp,
            updatedAt = "2026-07-13T01:00:00Z",
            lastUsedAt = "2026-07-13T01:00:00Z",
            version = 2,
            serverVersion = 1,
            needsSync = true,
        )
        dao.upsertNote(note)
        dao.upsertTag(tag)
        val requestStarted = CompletableDeferred<Unit>()
        val releaseResponse = CompletableDeferred<Unit>()
        val client = SyncClient { _, _ ->
            requestStarted.complete(Unit)
            releaseResponse.await()
            SyncResponse(
                cursor = "tombstone-cursor",
                changes = SyncChanges(
                    notes = emptyList(),
                    tags = emptyList(),
                    hardDeletedNoteIds = listOf(noteId.uppercase()),
                    hardDeletedTagIds = listOf(tagId.uppercase()),
                ),
                conflicts = listOf(
                    ConflictDto(
                        entityType = "note",
                        id = noteId.uppercase(),
                        serverVersion = 2,
                        serverContent = null,
                        clientContent = note.content,
                        message = "deleted",
                    ),
                    ConflictDto(
                        entityType = "tag",
                        id = tagId.uppercase(),
                        serverVersion = 2,
                        message = "deleted",
                    ),
                ),
                serverTime = "2026-07-13T03:00:00Z",
            )
        }
        val repository = NotesRepository(dao, client)

        val sync = async { repository.sync(userId, "token") }
        requestStarted.await()
        dao.upsertNote(
            note.copy(
                content = "Second edit during request",
                previewPlainText = "Second edit during request",
                updatedAt = "2026-07-13T02:00:00Z",
                version = 3,
            ),
        )
        dao.upsertTag(
            tag.copy(
                name = "Second tag edit during request",
                updatedAt = "2026-07-13T02:00:00Z",
                version = 3,
            ),
        )
        releaseResponse.complete(Unit)
        sync.await()

        assertNull(dao.note(userId, noteId))
        assertNull(dao.tag(userId, tagId))
        assertEquals("tombstone-cursor", dao.syncState(userId)?.cursor)
    }

    @Test
    fun unchangedConflictForcesServerAuthorityAcrossUuidCasingAndRebasesVersion() = runBlocking {
        val dao = database.dao()
        val userId = "user-forced-conflict"
        val lowerId = "123e4567-e89b-42d3-a456-426614174001"
        val upperId = lowerId.uppercase()
        val timestamp = "2026-07-13T00:00:00Z"
        val local = NoteEntity(
            id = lowerId,
            userId = userId,
            content = "Local conflicted edit",
            previewPlainText = "Local conflicted edit",
            createdAt = timestamp,
            updatedAt = "2026-07-13T02:00:00Z",
            version = 9,
            serverVersion = 1,
            needsSync = true,
        )
        dao.upsertNote(local)
        val client = SyncClient { _, payload ->
            assertEquals(1, payload.notes.single().baseVersion)
            assertNull(payload.notes.single().version)
            SyncResponse(
                cursor = "conflict-cursor",
                changes = SyncChanges(
                    notes = listOf(
                        NoteDto(
                            id = upperId,
                            content = "Authoritative server edit",
                            createdAt = timestamp,
                            updatedAt = "2026-07-13T03:00:00Z",
                            version = 3,
                            tagIds = emptyList(),
                        ),
                    ),
                ),
                conflicts = listOf(
                    ConflictDto(
                        entityType = "note",
                        id = upperId,
                        serverVersion = 3,
                        serverContent = "Authoritative server edit",
                        clientContent = local.content,
                        message = "conflict",
                    ),
                ),
                serverTime = "2026-07-13T03:00:00Z",
            )
        }

        NotesRepository(dao, client).sync(userId, "token")

        val stored = requireNotNull(dao.note(userId, lowerId))
        assertEquals("Authoritative server edit", stored.content)
        assertEquals(9, stored.version)
        assertEquals(3, stored.serverVersion)
        assertFalse(stored.needsSync)
        assertNull(dao.note(userId, upperId))
        assertEquals("conflict-cursor", dao.syncState(userId)?.cursor)
    }

    @Test
    fun editDuringTrueConflictMovesLatestLocalEditToDirtyDraftCopy() = runBlocking {
        val dao = database.dao()
        val userId = "user-conflict-in-flight-edit"
        val createdAt = "2026-07-13T00:00:00Z"
        val note = NoteEntity(
            id = "conflict-in-flight-note",
            userId = userId,
            content = "First local edit",
            previewPlainText = "First local edit",
            createdAt = createdAt,
            updatedAt = "2026-07-13T01:00:00Z",
            version = 2,
            serverVersion = 1,
            needsSync = true,
        )
        dao.upsertNote(note)
        val requestStarted = CompletableDeferred<Unit>()
        val releaseResponse = CompletableDeferred<Unit>()
        val client = SyncClient { _, _ ->
            requestStarted.complete(Unit)
            releaseResponse.await()
            SyncResponse(
                cursor = "in-flight-conflict-cursor",
                changes = SyncChanges(
                    notes = listOf(
                        NoteDto(
                            id = note.id,
                            content = "Authoritative server edit",
                            createdAt = createdAt,
                            updatedAt = "2026-07-13T03:00:00Z",
                            version = 3,
                            tagIds = emptyList(),
                        ),
                    ),
                ),
                conflicts = listOf(
                    ConflictDto(
                        entityType = "note",
                        id = note.id,
                        serverVersion = 3,
                        serverContent = "Authoritative server edit",
                        clientContent = note.content,
                        message = "conflict",
                    ),
                ),
                serverTime = "2026-07-13T03:00:00Z",
            )
        }
        val repository = NotesRepository(dao, client)

        val sync = async { repository.sync(userId, "token") }
        requestStarted.await()
        dao.upsertNote(
            note.copy(
                content = "Second edit during request",
                previewPlainText = "Second edit during request",
                updatedAt = "2026-07-13T02:00:00Z",
                version = 3,
                needsSync = true,
            ),
        )
        releaseResponse.complete(Unit)
        sync.await()

        val stored = requireNotNull(dao.note(userId, note.id))
        val preserved = dao.notesForSyncIdentityCleanup(userId).single { it.id != note.id }
        assertEquals("Authoritative server edit", stored.content)
        assertEquals(3, stored.version)
        assertEquals(3, stored.serverVersion)
        assertFalse(stored.needsSync)
        assertEquals("Second edit during request", preserved.content)
        assertEquals("drafts", preserved.section)
        assertNull(preserved.serverVersion)
        assertTrue(preserved.needsSync)
        assertEquals("in-flight-conflict-cursor", dao.syncState(userId)?.cursor)
    }

    @Test
    fun remoteHardDeletedTagRemovesRelationshipButKeepsDirtyNoteForRetry() = runBlocking {
        val dao = database.dao()
        val userId = "user-hard-deleted-tag"
        val timestamp = "2026-07-13T00:00:00Z"
        val note = NoteEntity(
            id = "dirty-note",
            userId = userId,
            content = "Keep this dirty body",
            previewPlainText = "Keep this dirty body",
            createdAt = timestamp,
            updatedAt = "2026-07-13T01:00:00Z",
            version = 2,
            serverVersion = 1,
            needsSync = true,
        )
        val tag = TagEntity(
            id = "deleted-tag",
            userId = userId,
            name = "Deleted elsewhere",
            colorHex = "#5EAFA5",
            createdAt = timestamp,
            updatedAt = timestamp,
            lastUsedAt = timestamp,
            version = 1,
            serverVersion = 1,
            needsSync = false,
        )
        dao.upsertNote(note)
        dao.upsertTag(tag)
        dao.upsertNoteTags(listOf(NoteTagCrossRef(note.id, tag.id)))
        val client = SyncClient { _, payload ->
            assertEquals(listOf(tag.id), payload.notes.single().tagIds)
            SyncResponse(
                cursor = "tag-delete-cursor",
                changes = SyncChanges(
                    notes = listOf(
                        NoteDto(
                            id = note.id,
                            content = note.content,
                            createdAt = note.createdAt,
                            updatedAt = "2026-07-13T02:00:00Z",
                            tagIds = listOf(tag.id),
                            version = 2,
                            mutationId = payload.notes.single().mutationId,
                        ),
                    ),
                    hardDeletedTagIds = listOf(tag.id),
                ),
                conflicts = emptyList(),
                serverTime = "2026-07-13T02:00:00Z",
            )
        }

        NotesRepository(dao, client).sync(userId, "token")

        val storedNote = requireNotNull(dao.note(userId, note.id))
        assertEquals("Keep this dirty body", storedNote.content)
        assertTrue(storedNote.needsSync)
        assertNull(dao.tag(userId, tag.id))
        assertTrue(dao.tagIdsForNote(note.id).isEmpty())
    }

    @Test
    fun uploadExcludesSoftDeletedTagRelationships() = runBlocking {
        val dao = database.dao()
        val userId = "user-active-tag-filter"
        val timestamp = "2026-07-13T00:00:00Z"
        val note = NoteEntity(
            id = "note-with-stale-tag",
            userId = userId,
            content = "Body",
            previewPlainText = "Body",
            createdAt = timestamp,
            updatedAt = timestamp,
            serverVersion = 1,
            needsSync = true,
        )
        val deletedTag = TagEntity(
            id = "soft-deleted-tag",
            userId = userId,
            name = "Deleted",
            colorHex = "#5EAFA5",
            createdAt = timestamp,
            updatedAt = timestamp,
            lastUsedAt = timestamp,
            deletedAt = timestamp,
            needsSync = false,
        )
        dao.upsertNote(note)
        dao.upsertTag(deletedTag)
        dao.upsertNoteTags(listOf(NoteTagCrossRef(note.id, deletedTag.id)))
        val client = SyncClient { _, payload ->
            assertTrue(payload.notes.single().tagIds.orEmpty().isEmpty())
            SyncResponse(
                cursor = "active-tag-filter-cursor",
                changes = SyncChanges(
                    notes = listOf(
                        NoteDto(
                            id = note.id,
                            content = note.content,
                            createdAt = note.createdAt,
                            updatedAt = "2026-07-13T01:00:00Z",
                            tagIds = emptyList(),
                            version = 2,
                            mutationId = payload.notes.single().mutationId,
                        ),
                    ),
                ),
                conflicts = emptyList(),
                serverTime = "2026-07-13T01:00:00Z",
            )
        }

        NotesRepository(dao, client).sync(userId, "token")
    }

    @Test
    fun clearLocalUserDataInvalidatesLateSyncResponseForDeletedAccount() = runBlocking {
        val dao = database.dao()
        val userId = "user-delete-sync-race"
        val timestamp = "2026-07-13T00:00:00Z"
        val localNote = NoteEntity(
            id = "delete-race-local-note",
            userId = userId,
            content = "Local before account deletion",
            createdAt = timestamp,
            updatedAt = timestamp,
            serverVersion = 1,
            needsSync = true,
        )
        val localTag = TagEntity(
            id = "delete-race-local-tag",
            userId = userId,
            name = "Local tag",
            colorHex = "#5EAFA5",
            createdAt = timestamp,
            updatedAt = timestamp,
            lastUsedAt = timestamp,
            serverVersion = 1,
            needsSync = true,
        )
        dao.upsertNote(localNote)
        dao.upsertTag(localTag)
        dao.upsertSyncState(
            SyncStateEntity(userId, cursor = "cursor-before-delete", deviceId = "device-1", lastSyncedAt = timestamp),
        )
        val responseReady = CompletableDeferred<Unit>()
        val releaseLateResponse = CompletableDeferred<Unit>()
        val client = SyncClient { _, payload ->
            val response = SyncResponse(
                cursor = "cursor-that-must-not-land",
                changes = SyncChanges(
                    notes = listOf(
                        NoteDto(
                            id = localNote.id,
                            content = localNote.content,
                            createdAt = timestamp,
                            updatedAt = timestamp,
                            version = 2,
                            mutationId = payload.notes.single().mutationId,
                        ),
                        NoteDto(
                            id = "remote-note-that-must-not-return",
                            content = "Remote",
                            createdAt = timestamp,
                            updatedAt = timestamp,
                            version = 1,
                        ),
                    ),
                    tags = listOf(
                        TagDto(
                            id = localTag.id,
                            name = localTag.name,
                            colorHex = localTag.colorHex,
                            createdAt = timestamp,
                            updatedAt = timestamp,
                            lastUsedAt = timestamp,
                            sortOrder = 0,
                            version = 2,
                            mutationId = payload.tags.single().mutationId,
                        ),
                        TagDto(
                            id = "remote-tag-that-must-not-return",
                            name = "Remote",
                            colorHex = "#8B5CF6",
                            createdAt = timestamp,
                            updatedAt = timestamp,
                            lastUsedAt = timestamp,
                            sortOrder = 0,
                            version = 1,
                        ),
                    ),
                ),
                conflicts = emptyList(),
                serverTime = timestamp,
            )
            responseReady.complete(Unit)
            releaseLateResponse.await()
            response
        }
        val repository = NotesRepository(dao, client)

        val inFlightSync = async { repository.sync(userId, "token") }
        responseReady.await()
        repository.clearLocalUserData(userId)
        releaseLateResponse.complete(Unit)
        inFlightSync.await()

        assertTrue(dao.notesForSyncIdentityCleanup(userId).isEmpty())
        assertTrue(dao.tagsForSyncIdentityCleanup(userId).isEmpty())
        assertTrue(dao.pendingHardDeletes(userId, "note").isEmpty())
        assertTrue(dao.pendingHardDeletes(userId, "tag").isEmpty())
        assertNull(dao.syncState(userId))
    }

    @Test
    fun pinningFromStaleUiSnapshotDoesNotRestoreOldRemoteContent() = runBlocking {
        val dao = database.dao()
        val userId = "user-stale-pin"
        val stale = NoteEntity(
            id = "stale-pin-note",
            userId = userId,
            content = "Before iOS edit",
            previewPlainText = "Before iOS edit",
            createdAt = "2026-07-13T00:00:00Z",
            updatedAt = "2026-07-13T00:00:00Z",
            version = 1,
            serverVersion = 1,
            needsSync = false,
        )
        val remoteLatest = stale.copy(
            content = "After iOS edit",
            previewPlainText = "After iOS edit",
            updatedAt = "2026-07-13T01:00:00Z",
            serverVersion = 2,
        )
        dao.upsertNote(remoteLatest)
        val repository = NotesRepository(dao, SyncClient { _, _ -> error("not used") })

        repository.togglePin(stale)

        val stored = requireNotNull(dao.note(userId, stale.id))
        assertEquals("After iOS edit", stored.content)
        assertNotNull(stored.pinnedAt)
        assertEquals(2, stored.serverVersion)
        assertTrue(stored.needsSync)
    }
}
