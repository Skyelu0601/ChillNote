package com.sponteoai.chillscript.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.sponteoai.chillscript.data.local.ChillScriptDatabase
import com.sponteoai.chillscript.data.local.NoteEntity
import com.sponteoai.chillscript.data.local.NoteTagCrossRef
import com.sponteoai.chillscript.data.local.PendingHardDeleteEntity
import com.sponteoai.chillscript.data.local.TagEntity
import com.sponteoai.chillscript.data.remote.NoteDto
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
        )
        val localTag = TagEntity(
            id = "local-tag",
            userId = userId,
            name = "Ideas",
            colorHex = "#5EAFA5",
            createdAt = timestamp,
            updatedAt = timestamp,
            lastUsedAt = timestamp,
        )
        val remotelyDeletedNote = localNote.copy(id = "remote-deleted-note", content = "Remove me")
        dao.upsertNotes(listOf(localNote, remotelyDeletedNote))
        dao.upsertTag(localTag)
        dao.upsertNoteTags(listOf(NoteTagCrossRef(localNote.id, localTag.id)))
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
                    notes = listOf(remoteNote),
                    tags = listOf(remoteTag),
                    hardDeletedNoteIds = listOf(remotelyDeletedNote.id),
                ),
                conflicts = emptyList(),
                serverTime = "2026-07-13T02:00:00Z",
            )
        }

        NotesRepository(dao, client).sync(userId, "access-token")

        assertEquals("access-token", capturedToken)
        val upload = requireNotNull(capturedPayload)
        assertTrue(upload.deviceId?.isNotBlank() == true)
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
        assertEquals(1, payload.notes.single().version)
        assertEquals(1, payload.tags.single().version)

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
}
