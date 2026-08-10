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
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

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
}
