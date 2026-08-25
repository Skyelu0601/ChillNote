package com.sponteoai.chillscript.data.local

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Transaction
import androidx.room.Upsert
import kotlinx.coroutines.flow.Flow
import java.time.Instant

data class SyncUploadSnapshot(
    val id: String,
    val version: Int,
    val updatedAt: String,
)

data class RemoteNoteChange(
    val note: NoteEntity,
    val tagIds: List<String>,
    val checklistItems: List<ChecklistItemEntity>,
    val remoteVersion: Int?,
    val remoteUpdatedAt: String,
)

data class RemoteTagChange(
    val tag: TagEntity,
    val remoteVersion: Int?,
    val remoteUpdatedAt: String,
)

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
            OR content LIKE :likeQuery ESCAPE '\' COLLATE NOCASE
            OR previewPlainText LIKE :likeQuery ESCAPE '\' COLLATE NOCASE
            OR id IN (
                SELECT note_tags.noteId FROM note_tags
                INNER JOIN tags ON tags.id = note_tags.tagId
                WHERE tags.deletedAt IS NULL AND tags.name LIKE :likeQuery ESCAPE '\' COLLATE NOCASE
            )
        )
        ORDER BY pinnedAt IS NULL, pinnedAt DESC, updatedAt DESC
    """)
    fun searchNotes(userId: String, matchQuery: String, likeQuery: String): Flow<List<NoteEntity>>

    @Query("SELECT * FROM tags WHERE userId = :userId AND deletedAt IS NULL ORDER BY parentId, sortOrder, name")
    fun observeTags(userId: String): Flow<List<TagEntity>>

    @Query("SELECT * FROM tags WHERE userId = :userId AND deletedAt IS NULL ORDER BY parentId, sortOrder, name")
    suspend fun activeTags(userId: String): List<TagEntity>

    @Query("SELECT * FROM tags WHERE userId = :userId AND id = :tagId LIMIT 1")
    suspend fun tag(userId: String, tagId: String): TagEntity?

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

    @Query("""
        SELECT EXISTS(
            SELECT 1 FROM notes
            WHERE userId = :userId AND deletedAt IS NULL
              AND importStatus IN ('queued', 'processing')
        )
    """)
    suspend fun hasPendingLinkImports(userId: String): Boolean

    @Query("""
        SELECT EXISTS(
            SELECT 1 FROM notes
            WHERE userId = :userId AND sourceUrl = :sourceUrl AND deletedAt IS NULL
              AND importStatus IN ('queued', 'processing')
        )
    """)
    suspend fun hasPendingLinkImport(userId: String, sourceUrl: String): Boolean

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

    @Query("""
        UPDATE notes SET needsSync = 0
        WHERE userId = :userId AND id = :id AND needsSync = 1
          AND version = :version AND updatedAt = :updatedAt
    """)
    suspend fun markNoteSyncedIfUnchanged(
        userId: String,
        id: String,
        version: Int,
        updatedAt: String,
    ): Int

    @Query("""
        UPDATE tags SET needsSync = 0
        WHERE userId = :userId AND id = :id AND needsSync = 1
          AND version = :version AND updatedAt = :updatedAt
    """)
    suspend fun markTagSyncedIfUnchanged(
        userId: String,
        id: String,
        version: Int,
        updatedAt: String,
    ): Int

    @Query("DELETE FROM notes WHERE id IN (:ids)")
    suspend fun hardDeleteNotes(ids: List<String>)

    @Query("DELETE FROM tags WHERE id IN (:ids)")
    suspend fun hardDeleteTags(ids: List<String>)

    @Query("SELECT * FROM pending_hard_deletes WHERE userId = :userId AND entityType = :entityType")
    suspend fun pendingHardDeletes(userId: String, entityType: String): List<PendingHardDeleteEntity>

    @Upsert suspend fun enqueueHardDelete(item: PendingHardDeleteEntity)

    @Query("DELETE FROM pending_hard_deletes WHERE userId = :userId AND entityType = :entityType AND entityId IN (:entityIds)")
    suspend fun dequeueHardDeletes(userId: String, entityType: String, entityIds: List<String>)

    @Query("""
        DELETE FROM pending_hard_deletes
        WHERE userId = :userId AND entityType = :entityType
          AND entityId = :entityId AND enqueuedAt = :enqueuedAt
    """)
    suspend fun dequeueHardDeleteIfUnchanged(
        userId: String,
        entityType: String,
        entityId: String,
        enqueuedAt: String,
    ): Int

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
    suspend fun applySyncResult(
        userId: String,
        uploadedNotes: List<SyncUploadSnapshot>,
        uploadedTags: List<SyncUploadSnapshot>,
        uploadedHardDeletedNotes: List<PendingHardDeleteEntity>,
        uploadedHardDeletedTags: List<PendingHardDeleteEntity>,
        notes: List<RemoteNoteChange>,
        tags: List<RemoteTagChange>,
        hardDeletedNoteIds: List<String>,
        hardDeletedTagIds: List<String>,
        syncState: SyncStateEntity,
    ) {
        uploadedNotes.forEach { snapshot ->
            markNoteSyncedIfUnchanged(userId, snapshot.id, snapshot.version, snapshot.updatedAt)
        }
        uploadedTags.forEach { snapshot ->
            markTagSyncedIfUnchanged(userId, snapshot.id, snapshot.version, snapshot.updatedAt)
        }

        tags.forEach { change ->
            val local = tag(userId, change.tag.id)
            if (local == null || shouldApplyRemoteChange(
                    localVersion = local.version,
                    localUpdatedAt = local.updatedAt,
                    localNeedsSync = local.needsSync,
                    remoteVersion = change.remoteVersion,
                    remoteUpdatedAt = change.remoteUpdatedAt,
                )
            ) {
                upsertTag(change.tag)
            }
        }

        notes.forEach { change ->
            val local = note(userId, change.note.id)
            if (local == null || shouldApplyRemoteChange(
                    localVersion = local.version,
                    localUpdatedAt = local.updatedAt,
                    localNeedsSync = local.needsSync,
                    remoteVersion = change.remoteVersion,
                    remoteUpdatedAt = change.remoteUpdatedAt,
                )
            ) {
                upsertNote(change.note)
                val existingItems = checklistItems(change.note.id)
                val stableItems = change.checklistItems.mapIndexed { index, item ->
                    val existing = existingItems.getOrNull(index)
                    item.copy(
                        id = existing?.id ?: item.id,
                        createdAt = existing?.createdAt?.takeIf(String::isNotEmpty) ?: item.createdAt,
                    )
                }
                replaceChecklistItems(change.note.id, stableItems)
                val existingTagIds = change.tagIds.distinct().filter { tag(userId, it) != null }
                replaceNoteTags(change.note.id, existingTagIds)
            }
        }

        hardDeletedNoteIds.forEach { noteId ->
            val local = note(userId, noteId)
            if (local == null || !local.needsSync) hardDeleteNotes(listOf(noteId))
        }
        hardDeletedTagIds.forEach { tagId ->
            val local = tag(userId, tagId)
            val hasDirtyNote = noteIdsForTag(tagId).any { noteId -> note(userId, noteId)?.needsSync == true }
            if ((local == null || !local.needsSync) && !hasDirtyNote) hardDeleteTags(listOf(tagId))
        }

        uploadedHardDeletedNotes.forEach { snapshot ->
            dequeueHardDeleteIfUnchanged(userId, "note", snapshot.entityId, snapshot.enqueuedAt)
        }
        uploadedHardDeletedTags.forEach { snapshot ->
            dequeueHardDeleteIfUnchanged(userId, "tag", snapshot.entityId, snapshot.enqueuedAt)
        }
        upsertSyncState(syncState)
    }
}

private fun shouldApplyRemoteChange(
    localVersion: Int,
    localUpdatedAt: String,
    localNeedsSync: Boolean,
    remoteVersion: Int?,
    remoteUpdatedAt: String,
): Boolean {
    if (localNeedsSync) return false

    val versionComparison = remoteVersion?.compareTo(localVersion)
    if (versionComparison != null && versionComparison != 0) return versionComparison > 0

    val timeComparison = compareTimestamps(remoteUpdatedAt, localUpdatedAt)
    return timeComparison > 0
}

private fun compareTimestamps(left: String, right: String): Int =
    runCatching { Instant.parse(left).compareTo(Instant.parse(right)) }
        .getOrElse { left.compareTo(right) }
