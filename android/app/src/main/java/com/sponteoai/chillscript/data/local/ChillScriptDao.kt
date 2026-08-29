package com.sponteoai.chillscript.data.local

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Transaction
import androidx.room.Upsert
import com.sponteoai.chillscript.data.canonicalSyncIdentity
import com.sponteoai.chillscript.data.compareSyncTimestamps
import com.sponteoai.chillscript.data.isUuidSyncIdentity
import com.sponteoai.chillscript.data.noteMutationFingerprint
import com.sponteoai.chillscript.data.tagMutationFingerprint
import kotlinx.coroutines.flow.Flow
import java.time.Instant
import java.util.UUID

data class SyncUploadSnapshot(
    val id: String,
    val version: Int,
    val updatedAt: String,
)

data class PreparedNoteUpload(
    val note: NoteEntity,
    val tagIds: List<String>,
    val previousMutationId: String?,
)

data class PreparedTagUpload(
    val tag: TagEntity,
    val previousMutationId: String?,
)

data class PreparedSyncUploads(
    val notes: List<PreparedNoteUpload>,
    val tags: List<PreparedTagUpload>,
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
    @Query("SELECT * FROM notes WHERE userId = :userId ORDER BY pinnedAt IS NULL, pinnedAt DESC, createdAt DESC, id DESC")
    fun observeNotes(userId: String): Flow<List<NoteEntity>>

    @Query("SELECT * FROM notes WHERE userId = :userId AND id = :noteId LIMIT 1")
    suspend fun note(userId: String, noteId: String): NoteEntity?

    @Query("SELECT * FROM notes WHERE userId = :userId AND id = :noteId COLLATE NOCASE")
    suspend fun notesMatchingIdIgnoringCase(userId: String, noteId: String): List<NoteEntity>

    @Transaction
    suspend fun notesMatchingSyncIdentity(userId: String, noteId: String): List<NoteEntity> =
        if (isUuidSyncIdentity(noteId)) notesMatchingIdIgnoringCase(userId, noteId)
        else listOfNotNull(note(userId, noteId))

    @Query("SELECT * FROM notes WHERE userId = :userId")
    suspend fun notesForSyncIdentityCleanup(userId: String): List<NoteEntity>

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

    @Query("SELECT * FROM tags WHERE userId = :userId AND id = :tagId COLLATE NOCASE")
    suspend fun tagsMatchingIdIgnoringCase(userId: String, tagId: String): List<TagEntity>

    @Query("SELECT * FROM tags WHERE userId = :userId")
    suspend fun tagsForSyncIdentityCleanup(userId: String): List<TagEntity>

    @Query("SELECT * FROM tags WHERE userId = :userId AND parentId = :parentId")
    suspend fun tagsWithParent(userId: String, parentId: String): List<TagEntity>

    @Transaction
    suspend fun tagsMatchingSyncIdentity(userId: String, tagId: String): List<TagEntity> =
        if (isUuidSyncIdentity(tagId)) tagsMatchingIdIgnoringCase(userId, tagId)
        else listOfNotNull(tag(userId, tagId))

    @Query("SELECT * FROM tags WHERE userId = :userId AND parentId = :parentId AND deletedAt IS NULL ORDER BY sortOrder, name")
    suspend fun childTags(userId: String, parentId: String): List<TagEntity>

    @Query("SELECT tagId FROM note_tags WHERE noteId = :noteId")
    suspend fun tagIdsForNote(noteId: String): List<String>

    @Query("""
        SELECT note_tags.tagId FROM note_tags
        INNER JOIN tags ON tags.id = note_tags.tagId
        WHERE note_tags.noteId = :noteId
          AND tags.userId = :userId
          AND tags.deletedAt IS NULL
    """)
    suspend fun activeTagIdsForNote(userId: String, noteId: String): List<String>

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

    /** Persists durable mutation IDs before the HTTP request leaves the device. */
    @Transaction
    suspend fun preparePendingSyncUploads(userId: String): PreparedSyncUploads {
        val preparedNotes = pendingNotes(userId).map { current ->
            val tagIds = activeTagIdsForNote(userId, current.id)
            val fingerprint = noteMutationFingerprint(current, tagIds)
            val previousMutationId = current.lastSubmittedMutationId
            val mutationId = if (
                current.lastSubmittedFingerprint == fingerprint && previousMutationId != null
            ) {
                previousMutationId
            } else {
                UUID.randomUUID().toString()
            }
            val prepared = current.copy(
                lastSubmittedMutationId = mutationId,
                lastSubmittedFingerprint = fingerprint,
            )
            if (prepared != current) upsertNote(prepared)
            PreparedNoteUpload(prepared, tagIds, previousMutationId)
        }
        val preparedTags = pendingTags(userId).map { current ->
            val fingerprint = tagMutationFingerprint(current)
            val previousMutationId = current.lastSubmittedMutationId
            val mutationId = if (
                current.lastSubmittedFingerprint == fingerprint && previousMutationId != null
            ) {
                previousMutationId
            } else {
                UUID.randomUUID().toString()
            }
            val prepared = current.copy(
                lastSubmittedMutationId = mutationId,
                lastSubmittedFingerprint = fingerprint,
            )
            if (prepared != current) upsertTag(prepared)
            PreparedTagUpload(prepared, previousMutationId)
        }
        return PreparedSyncUploads(preparedNotes, preparedTags)
    }

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
    suspend fun collapseCaseVariantNotes(userId: String) {
        notesForSyncIdentityCleanup(userId)
            .groupBy { canonicalSyncIdentity(it.id) }
            .values
            .filter { it.size > 1 }
            .forEach { aliases ->
                val winner = aliases.maxWithOrNull(
                    compareBy<NoteEntity> { it.needsSync }
                        .thenBy { it.version }
                        .thenComparator { left, right -> compareSyncTimestamps(left.updatedAt, right.updatedAt) },
                ) ?: return@forEach
                hardDeleteNotes(aliases.filter { it.id != winner.id }.map { it.id })
            }
    }

    @Transaction
    suspend fun collapseCaseVariantTags(userId: String) {
        tagsForSyncIdentityCleanup(userId)
            .groupBy { canonicalSyncIdentity(it.id) }
            .values
            .filter { it.size > 1 }
            .forEach { aliases ->
                var winner = aliases.maxWithOrNull(
                    compareBy<TagEntity> { it.needsSync }
                        .thenBy { it.version }
                        .thenComparator { left, right -> compareSyncTimestamps(left.updatedAt, right.updatedAt) },
                ) ?: return@forEach
                val loserIds = aliases.filter { it.id != winner.id }.map { it.id }
                loserIds.forEach { loserId ->
                    val noteIds = noteIdsForTag(loserId)
                    if (noteIds.isNotEmpty()) {
                        upsertNoteTags(noteIds.map { noteId -> NoteTagCrossRef(noteId, winner.id) })
                        deleteNoteTagsForTag(loserId)
                    }
                    tagsWithParent(userId, loserId)
                        .filter { child -> child.id !in loserIds && child.id != winner.id }
                        .forEach { child -> upsertTag(child.copy(parentId = winner.id)) }
                }
                if (winner.parentId != null && canonicalSyncIdentity(winner.parentId) == canonicalSyncIdentity(winner.id)) {
                    winner = winner.copy(parentId = null)
                    upsertTag(winner)
                }
                hardDeleteTags(loserIds)
            }
    }

    suspend fun preserveConflictedTag(userId: String, tagId: String) {
        val local = tagsMatchingSyncIdentity(userId, tagId).maxWithOrNull(
            compareBy<TagEntity> { it.needsSync }
                .thenBy { it.version }
                .thenComparator { left, right -> compareSyncTimestamps(left.updatedAt, right.updatedAt) },
        ) ?: return
        val now = Instant.now().toString()
        val cloneId = UUID.randomUUID().toString()
        val preservedParentId = local.parentId?.takeUnless { parentId ->
            canonicalSyncIdentity(parentId) == canonicalSyncIdentity(local.id)
        }
        upsertTag(
            local.copy(
                id = cloneId,
                parentId = preservedParentId,
                createdAt = now,
                updatedAt = now,
                lastUsedAt = now,
                deletedAt = null,
                version = 1,
                serverVersion = null,
                serverMutationId = null,
                lastSubmittedMutationId = null,
                lastSubmittedFingerprint = null,
                needsSync = true,
            ),
        )
        val noteIds = noteIdsForTag(local.id)
        if (noteIds.isNotEmpty()) {
            upsertNoteTags(noteIds.map { noteId -> NoteTagCrossRef(noteId, cloneId) })
            deleteNoteTagsForTag(local.id)
            markNotesChanged(noteIds, now)
        }
        tagsWithParent(userId, local.id).filter { child -> child.id != local.id }.forEach { child ->
            upsertTag(
                child.copy(
                    parentId = cloneId,
                    updatedAt = now,
                    version = child.version + 1,
                    needsSync = true,
                ),
            )
        }
    }

    suspend fun preserveConflictedNote(userId: String, noteId: String) {
        val local = notesMatchingSyncIdentity(userId, noteId).maxWithOrNull(
            compareBy<NoteEntity> { it.needsSync }
                .thenBy { it.version }
                .thenComparator { left, right -> compareSyncTimestamps(left.updatedAt, right.updatedAt) },
        ) ?: return
        val now = Instant.now().toString()
        val cloneId = UUID.randomUUID().toString()
        upsertNote(
            local.copy(
                id = cloneId,
                createdAt = now,
                updatedAt = now,
                deletedAt = null,
                pinnedAt = null,
                version = 1,
                serverVersion = null,
                serverMutationId = null,
                lastSubmittedMutationId = null,
                lastSubmittedFingerprint = null,
                section = "drafts",
                needsSync = true,
            ),
        )
        val tagIds = activeTagIdsForNote(userId, local.id)
        if (tagIds.isNotEmpty()) {
            upsertNoteTags(tagIds.map { tagId -> NoteTagCrossRef(cloneId, tagId) })
        }
        val clonedChecklist = checklistItems(local.id).map { item ->
            item.copy(
                id = UUID.randomUUID().toString(),
                noteId = cloneId,
                createdAt = now,
                updatedAt = now,
            )
        }
        if (clonedChecklist.isNotEmpty()) upsertChecklistItems(clonedChecklist)
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
        conflictedNoteIds: List<String>,
        conflictedTagIds: List<String>,
        forceServerNoteIds: List<String>,
        forceServerTagIds: List<String>,
        blockPendingHardDeleteEntities: Boolean = false,
        establishMissingServerBaselines: Boolean = false,
        syncState: SyncStateEntity,
    ) {
        val unchangedUploadedNoteIdentities = mutableSetOf<String>()
        val unchangedUploadedTagIdentities = mutableSetOf<String>()
        val notesNeedingRetryAfterTagHardDelete = mutableSetOf<String>()
        hardDeletedTagIds.forEach { tagId ->
            tagsMatchingSyncIdentity(userId, tagId).forEach { localTag ->
                noteIdsForTag(localTag.id).forEach { noteId ->
                    notesNeedingRetryAfterTagHardDelete += canonicalSyncIdentity(noteId)
                }
            }
        }
        uploadedNotes.forEach { snapshot ->
            if (canonicalSyncIdentity(snapshot.id) !in notesNeedingRetryAfterTagHardDelete &&
                markNoteSyncedIfUnchanged(userId, snapshot.id, snapshot.version, snapshot.updatedAt) > 0
            ) {
                unchangedUploadedNoteIdentities += canonicalSyncIdentity(snapshot.id)
            }
        }
        uploadedTags.forEach { snapshot ->
            if (markTagSyncedIfUnchanged(userId, snapshot.id, snapshot.version, snapshot.updatedAt) > 0) {
                unchangedUploadedTagIdentities += canonicalSyncIdentity(snapshot.id)
            }
        }
        val conflictedNoteIdentities = conflictedNoteIds.mapTo(mutableSetOf(), ::canonicalSyncIdentity)
        val conflictedTagIdentities = conflictedTagIds.mapTo(mutableSetOf(), ::canonicalSyncIdentity)
        val forceServerNoteIdentities = forceServerNoteIds.mapTo(mutableSetOf(), ::canonicalSyncIdentity)
        val forceServerTagIdentities = forceServerTagIds.mapTo(mutableSetOf(), ::canonicalSyncIdentity)
        val blockedNoteIdentities = if (blockPendingHardDeleteEntities) {
            pendingHardDeletes(userId, "note").mapTo(mutableSetOf()) { canonicalSyncIdentity(it.entityId) }
        } else {
            emptySet()
        }
        val blockedTagIdentities = if (blockPendingHardDeleteEntities) {
            pendingHardDeletes(userId, "tag").mapTo(mutableSetOf()) { canonicalSyncIdentity(it.entityId) }
        } else {
            emptySet()
        }

        // True optimistic-concurrency conflicts preserve the latest local value
        // as a new dirty entity before the authoritative server row replaces the
        // original identity. Server-forced values (for example finished imports)
        // deliberately do not create conflict copies.
        conflictedTagIds.distinctBy(::canonicalSyncIdentity).forEach { preserveConflictedTag(userId, it) }
        conflictedNoteIds.distinctBy(::canonicalSyncIdentity).forEach { preserveConflictedNote(userId, it) }

        tags.forEach { change ->
            if (canonicalSyncIdentity(change.tag.id) in blockedTagIdentities) return@forEach
            val aliases = tagsMatchingSyncIdentity(userId, change.tag.id)
            val local = aliases.maxWithOrNull(
                compareBy<TagEntity> { it.needsSync }
                    .thenBy { it.version }
                    .thenComparator { left, right -> compareSyncTimestamps(left.updatedAt, right.updatedAt) },
            )
            val resolvedParentId = change.tag.parentId?.let { parentId ->
                tagsMatchingSyncIdentity(userId, parentId).maxByOrNull { it.version }?.id ?: parentId
            }
            val resolvedChange = if (local != null) {
                change.copy(tag = change.tag.copy(
                    id = local.id,
                    parentId = resolvedParentId,
                    version = local.version,
                    lastSubmittedMutationId = local.lastSubmittedMutationId,
                    lastSubmittedFingerprint = local.lastSubmittedFingerprint,
                ))
            } else {
                change.copy(tag = change.tag.copy(parentId = resolvedParentId))
            }
            val identity = canonicalSyncIdentity(change.tag.id)
            val forceServerChange = identity in conflictedTagIdentities ||
                (identity in forceServerTagIdentities && identity in unchangedUploadedTagIdentities)
            if (local == null || forceServerChange || shouldApplyRemoteChange(
                    localServerVersion = local.serverVersion,
                    localUpdatedAt = local.updatedAt,
                    localNeedsSync = local.needsSync,
                    remoteVersion = resolvedChange.remoteVersion,
                    remoteUpdatedAt = resolvedChange.remoteUpdatedAt,
                )
            ) {
                upsertTag(resolvedChange.tag)
            } else if (local.needsSync && resolvedChange.remoteVersion != null) {
                // The user edited again while this request was in flight. Keep those
                // fields dirty, but rebase the next upload on the server revision that
                // this response acknowledged.
                upsertTag(
                    local.copy(
                        serverVersion = resolvedChange.remoteVersion,
                        serverMutationId = resolvedChange.tag.serverMutationId,
                    ),
                )
            }
        }

        notes.forEach { change ->
            if (canonicalSyncIdentity(change.note.id) in blockedNoteIdentities) return@forEach
            val aliases = notesMatchingSyncIdentity(userId, change.note.id)
            val local = aliases.maxWithOrNull(
                compareBy<NoteEntity> { it.needsSync }
                    .thenBy { it.version }
                    .thenComparator { left, right -> compareSyncTimestamps(left.updatedAt, right.updatedAt) },
            )
            val resolvedNoteId = local?.id ?: change.note.id
            val resolvedChange = change.copy(
                note = change.note.copy(
                    id = resolvedNoteId,
                    version = local?.version ?: change.note.version,
                    lastSubmittedMutationId = local?.lastSubmittedMutationId,
                    lastSubmittedFingerprint = local?.lastSubmittedFingerprint,
                ),
                tagIds = change.tagIds.mapNotNull { tagId ->
                    tagsMatchingSyncIdentity(userId, tagId).maxByOrNull { it.version }?.id
                }.distinct(),
                checklistItems = change.checklistItems.map { it.copy(noteId = resolvedNoteId) },
            )
            val identity = canonicalSyncIdentity(change.note.id)
            val forceServerChange = identity in conflictedNoteIdentities ||
                (identity in forceServerNoteIdentities && identity in unchangedUploadedNoteIdentities)
            if (local == null || forceServerChange || shouldApplyRemoteChange(
                    localServerVersion = local.serverVersion,
                    localUpdatedAt = local.updatedAt,
                    localNeedsSync = local.needsSync,
                    remoteVersion = resolvedChange.remoteVersion,
                    remoteUpdatedAt = resolvedChange.remoteUpdatedAt,
                )
            ) {
                upsertNote(resolvedChange.note)
                val existingItems = checklistItems(resolvedNoteId)
                val stableItems = resolvedChange.checklistItems.mapIndexed { index, item ->
                    val existing = existingItems.getOrNull(index)
                    item.copy(
                        id = existing?.id ?: item.id,
                        createdAt = existing?.createdAt?.takeIf(String::isNotEmpty) ?: item.createdAt,
                    )
                }
                replaceChecklistItems(resolvedNoteId, stableItems)
                replaceNoteTags(resolvedNoteId, resolvedChange.tagIds)
            } else if (local.needsSync && resolvedChange.remoteVersion != null) {
                // Preserve a newer in-flight local edit while recording the server
                // base that the next upload must use.
                upsertNote(
                    local.copy(
                        serverVersion = resolvedChange.remoteVersion,
                        serverMutationId = resolvedChange.note.serverMutationId,
                    ),
                )
            }
        }

        hardDeletedNoteIds.forEach { noteId ->
            val aliases = notesMatchingSyncIdentity(userId, noteId)
            val identity = canonicalSyncIdentity(noteId)
            // A conflict/baseline tombstone is the authoritative representation
            // promised by the server. It wins even if the local row became dirty
            // while the request was in flight, otherwise the tombstone can loop
            // forever and resurrect a server-deleted note on the next upload.
            val safeToDelete = if (identity in forceServerNoteIdentities) {
                aliases.map { it.id }
            } else {
                aliases.filterNot { it.needsSync }.map { it.id }
            }
            if (safeToDelete.isNotEmpty()) hardDeleteNotes(safeToDelete)
        }
        hardDeletedTagIds.forEach { tagId ->
            // Capture the original aliases before cloning. If a still-active tag
            // changed locally while the server permanently deleted its identity,
            // preserve that local branch under a fresh UUID and move its note/child
            // relationships before applying the authoritative tombstone.
            val identity = canonicalSyncIdentity(tagId)
            val aliases = tagsMatchingSyncIdentity(userId, tagId)
            if (identity !in forceServerTagIdentities &&
                identity !in blockedTagIdentities &&
                aliases.any { it.needsSync && it.deletedAt == null }
            ) {
                preserveConflictedTag(userId, tagId)
            }
            val originalAliasIds = aliases.map { it.id }
            if (originalAliasIds.isNotEmpty()) hardDeleteTags(originalAliasIds)
        }

        uploadedHardDeletedNotes.forEach { snapshot ->
            dequeueHardDeleteIfUnchanged(userId, "note", snapshot.entityId, snapshot.enqueuedAt)
        }
        uploadedHardDeletedTags.forEach { snapshot ->
            dequeueHardDeleteIfUnchanged(userId, "tag", snapshot.entityId, snapshot.enqueuedAt)
        }
        if (establishMissingServerBaselines) {
            val representedNoteIdentities = notes.mapTo(mutableSetOf()) {
                canonicalSyncIdentity(it.note.id)
            }.apply {
                hardDeletedNoteIds.mapTo(this, ::canonicalSyncIdentity)
            }
            val representedTagIdentities = tags.mapTo(mutableSetOf()) {
                canonicalSyncIdentity(it.tag.id)
            }.apply {
                hardDeletedTagIds.mapTo(this, ::canonicalSyncIdentity)
            }
            pendingNotes(userId)
                .filter { local ->
                    local.serverVersion == null &&
                        canonicalSyncIdentity(local.id) !in representedNoteIdentities
                }
                .forEach { local -> upsertNote(local.copy(serverVersion = 0)) }
            pendingTags(userId)
                .filter { local ->
                    local.serverVersion == null &&
                        canonicalSyncIdentity(local.id) !in representedTagIdentities
                }
                .forEach { local -> upsertTag(local.copy(serverVersion = 0)) }
        }
        upsertSyncState(syncState)
    }
}

private fun shouldApplyRemoteChange(
    localServerVersion: Int?,
    localUpdatedAt: String,
    localNeedsSync: Boolean,
    remoteVersion: Int?,
    remoteUpdatedAt: String,
): Boolean {
    if (localNeedsSync) return false

    if (remoteVersion != null && localServerVersion == null) return true
    val versionComparison = remoteVersion?.let { remote -> localServerVersion?.let(remote::compareTo) }
    if (versionComparison != null && versionComparison != 0) return versionComparison > 0

    val timeComparison = compareTimestamps(remoteUpdatedAt, localUpdatedAt)
    return timeComparison > 0
}

private fun compareTimestamps(left: String, right: String): Int =
    runCatching { Instant.parse(left).compareTo(Instant.parse(right)) }
        .getOrElse { left.compareTo(right) }
