package com.sponteoai.chillscript.data.local

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Transaction
import androidx.room.Upsert
import kotlinx.coroutines.flow.Flow

@Dao
interface ChillScriptDao {
    @Query("SELECT * FROM notes WHERE userId = :userId ORDER BY pinnedAt IS NULL, pinnedAt DESC, updatedAt DESC")
    fun observeNotes(userId: String): Flow<List<NoteEntity>>

    @Query("SELECT * FROM notes WHERE userId = :userId AND id = :noteId LIMIT 1")
    suspend fun note(userId: String, noteId: String): NoteEntity?

    @Query("""
        SELECT * FROM notes
        WHERE userId = :userId AND (
            id IN (SELECT noteId FROM notes_fts WHERE notes_fts MATCH :matchQuery)
            OR content LIKE :likeQuery ESCAPE '\\' COLLATE NOCASE
            OR previewPlainText LIKE :likeQuery ESCAPE '\\' COLLATE NOCASE
            OR id IN (
                SELECT note_tags.noteId FROM note_tags
                INNER JOIN tags ON tags.id = note_tags.tagId
                WHERE tags.deletedAt IS NULL AND tags.name LIKE :likeQuery ESCAPE '\\' COLLATE NOCASE
            )
        )
        ORDER BY pinnedAt IS NULL, pinnedAt DESC, updatedAt DESC
    """)
    fun searchNotes(userId: String, matchQuery: String, likeQuery: String): Flow<List<NoteEntity>>

    @Query("SELECT * FROM tags WHERE userId = :userId AND deletedAt IS NULL ORDER BY parentId, sortOrder, name")
    fun observeTags(userId: String): Flow<List<TagEntity>>

    @Query("SELECT * FROM tags WHERE userId = :userId AND deletedAt IS NULL ORDER BY parentId, sortOrder, name")
    suspend fun activeTags(userId: String): List<TagEntity>

    @Query("SELECT * FROM tags WHERE userId = :userId AND parentId = :parentId AND deletedAt IS NULL ORDER BY sortOrder, name")
    suspend fun childTags(userId: String, parentId: String): List<TagEntity>

    @Query("SELECT tagId FROM note_tags WHERE noteId = :noteId")
    suspend fun tagIdsForNote(noteId: String): List<String>

    @Query("SELECT tags.* FROM tags INNER JOIN note_tags ON tags.id = note_tags.tagId WHERE note_tags.noteId = :noteId")
    suspend fun tagsForNote(noteId: String): List<TagEntity>

    @Query("SELECT * FROM note_tags")
    fun observeNoteTags(): Flow<List<NoteTagCrossRef>>

    @Query("SELECT * FROM checklist_items WHERE noteId = :noteId ORDER BY sortOrder")
    fun observeChecklistItems(noteId: String): Flow<List<ChecklistItemEntity>>

    @Query("SELECT * FROM checklist_items WHERE noteId = :noteId ORDER BY sortOrder")
    suspend fun checklistItems(noteId: String): List<ChecklistItemEntity>

    @Query("DELETE FROM checklist_items WHERE noteId = :noteId")
    suspend fun deleteChecklistItems(noteId: String)

    @Upsert suspend fun upsertChecklistItems(items: List<ChecklistItemEntity>)

    @Transaction
    suspend fun replaceChecklistItems(noteId: String, items: List<ChecklistItemEntity>) {
        deleteChecklistItems(noteId)
        if (items.isNotEmpty()) upsertChecklistItems(items)
    }

    @Query("DELETE FROM note_tags WHERE noteId = :noteId")
    suspend fun deleteNoteTags(noteId: String)

    @Query("SELECT noteId FROM note_tags WHERE tagId = :tagId")
    suspend fun noteIdsForTag(tagId: String): List<String>

    @Query("DELETE FROM note_tags WHERE tagId = :tagId")
    suspend fun deleteNoteTagsForTag(tagId: String)

    @Query("UPDATE notes SET updatedAt = :updatedAt, version = version + 1, needsSync = 1 WHERE id IN (:noteIds)")
    suspend fun markNotesChanged(noteIds: List<String>, updatedAt: String)

    @Transaction
    suspend fun replaceNoteTags(noteId: String, tagIds: List<String>) {
        deleteNoteTags(noteId)
        if (tagIds.isNotEmpty()) upsertNoteTags(tagIds.map { NoteTagCrossRef(noteId, it) })
    }

    @Query("SELECT * FROM notes WHERE userId = :userId AND needsSync = 1")
    suspend fun pendingNotes(userId: String): List<NoteEntity>

    @Query("SELECT id FROM notes WHERE userId = :userId AND deletedAt IS NOT NULL")
    suspend fun deletedNoteIds(userId: String): List<String>

    @Query("SELECT id FROM notes WHERE userId = :userId AND deletedAt IS NOT NULL AND deletedAt < :cutoff")
    suspend fun expiredNoteIds(userId: String, cutoff: String): List<String>

    @Query("SELECT id FROM tags WHERE userId = :userId AND deletedAt IS NOT NULL AND deletedAt < :cutoff")
    suspend fun expiredTagIds(userId: String, cutoff: String): List<String>

    @Query("SELECT * FROM tags WHERE userId = :userId AND needsSync = 1")
    suspend fun pendingTags(userId: String): List<TagEntity>

    @Upsert suspend fun upsertNote(note: NoteEntity)
    @Upsert suspend fun upsertNotes(notes: List<NoteEntity>)
    @Upsert suspend fun upsertTag(tag: TagEntity)
    @Upsert suspend fun upsertTags(tags: List<TagEntity>)
    @Upsert suspend fun upsertNoteTags(crossRefs: List<NoteTagCrossRef>)
    @Upsert suspend fun upsertSyncState(state: SyncStateEntity)

    @Transaction
    suspend fun insertWelcomeContent(note: NoteEntity, tag: TagEntity) {
        upsertTag(tag)
        upsertNote(note)
        upsertNoteTags(listOf(NoteTagCrossRef(note.id, tag.id)))
    }

    @Query("SELECT * FROM sync_state WHERE userId = :userId")
    suspend fun syncState(userId: String): SyncStateEntity?

    @Query("UPDATE notes SET needsSync = 0 WHERE id IN (:ids)")
    suspend fun markNotesSynced(ids: List<String>)

    @Query("UPDATE tags SET needsSync = 0 WHERE id IN (:ids)")
    suspend fun markTagsSynced(ids: List<String>)

    @Query("DELETE FROM notes WHERE id IN (:ids)")
    suspend fun hardDeleteNotes(ids: List<String>)

    @Query("DELETE FROM tags WHERE id IN (:ids)")
    suspend fun hardDeleteTags(ids: List<String>)

    @Query("SELECT * FROM pending_hard_deletes WHERE userId = :userId AND entityType = :entityType")
    suspend fun pendingHardDeletes(userId: String, entityType: String): List<PendingHardDeleteEntity>

    @Upsert suspend fun enqueueHardDelete(item: PendingHardDeleteEntity)

    @Query("DELETE FROM pending_hard_deletes WHERE userId = :userId AND entityType = :entityType AND entityId IN (:entityIds)")
    suspend fun dequeueHardDeletes(userId: String, entityType: String, entityIds: List<String>)

    @Query("DELETE FROM notes WHERE userId = :userId")
    suspend fun deleteLocalNotesForUser(userId: String)

    @Query("DELETE FROM tags WHERE userId = :userId")
    suspend fun deleteLocalTagsForUser(userId: String)

    @Query("DELETE FROM pending_hard_deletes WHERE userId = :userId")
    suspend fun deletePendingHardDeletesForUser(userId: String)

    @Query("DELETE FROM sync_state WHERE userId = :userId")
    suspend fun deleteSyncStateForUser(userId: String)

    @Transaction
    suspend fun clearLocalUserData(userId: String) {
        deleteLocalNotesForUser(userId)
        deleteLocalTagsForUser(userId)
        deletePendingHardDeletesForUser(userId)
        deleteSyncStateForUser(userId)
    }

    @Transaction
    suspend fun permanentlyDeleteNote(userId: String, noteId: String, enqueuedAt: String) {
        enqueueHardDelete(PendingHardDeleteEntity("note:$noteId", userId, "note", noteId, enqueuedAt))
        hardDeleteNotes(listOf(noteId))
    }

    @Transaction
    suspend fun permanentlyDeleteNotes(userId: String, noteIds: List<String>, enqueuedAt: String) {
        noteIds.forEach { enqueueHardDelete(PendingHardDeleteEntity("note:$it", userId, "note", it, enqueuedAt)) }
        hardDeleteNotes(noteIds)
    }

    @Transaction
    suspend fun permanentlyDeleteTags(userId: String, tagIds: List<String>, enqueuedAt: String) {
        tagIds.forEach { enqueueHardDelete(PendingHardDeleteEntity("tag:$it", userId, "tag", it, enqueuedAt)) }
        hardDeleteTags(tagIds)
    }

    @Transaction
    suspend fun applyRemoteChanges(
        notes: List<NoteEntity>,
        tags: List<TagEntity>,
        hardDeletedNoteIds: List<String>,
        hardDeletedTagIds: List<String>,
        syncState: SyncStateEntity,
    ) {
        if (notes.isNotEmpty()) upsertNotes(notes)
        if (tags.isNotEmpty()) upsertTags(tags)
        if (hardDeletedNoteIds.isNotEmpty()) hardDeleteNotes(hardDeletedNoteIds)
        if (hardDeletedTagIds.isNotEmpty()) hardDeleteTags(hardDeletedTagIds)
        upsertSyncState(syncState)
    }
}
