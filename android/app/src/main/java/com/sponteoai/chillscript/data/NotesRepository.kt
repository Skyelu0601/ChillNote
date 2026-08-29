package com.sponteoai.chillscript.data

import com.sponteoai.chillscript.data.local.ChillScriptDao
import com.sponteoai.chillscript.data.local.ChecklistItemEntity
import com.sponteoai.chillscript.data.local.NoteEntity
import com.sponteoai.chillscript.data.local.PreparedNoteUpload
import com.sponteoai.chillscript.data.local.PreparedSyncUploads
import com.sponteoai.chillscript.data.local.PreparedTagUpload
import com.sponteoai.chillscript.data.local.RemoteNoteChange
import com.sponteoai.chillscript.data.local.RemoteTagChange
import com.sponteoai.chillscript.data.local.SyncStateEntity
import com.sponteoai.chillscript.data.local.SyncUploadSnapshot
import com.sponteoai.chillscript.data.local.TagEntity
import com.sponteoai.chillscript.data.remote.NoteDto
import com.sponteoai.chillscript.data.remote.SyncClient
import com.sponteoai.chillscript.data.remote.LinkImportApi
import com.sponteoai.chillscript.data.remote.LinkImportRequest
import com.sponteoai.chillscript.data.remote.MediaLinkSectionsDto
import com.sponteoai.chillscript.data.remote.LinkSourceDto
import com.sponteoai.chillscript.data.remote.sourceForUrl
import com.sponteoai.chillscript.data.remote.SyncPayload
import com.sponteoai.chillscript.data.remote.SyncResponse
import com.sponteoai.chillscript.data.remote.TagDto
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.time.Instant
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import com.sponteoai.chillscript.domain.ChecklistMarkdown
import com.sponteoai.chillscript.domain.TagColors
import com.sponteoai.chillscript.domain.TagHierarchy
import com.sponteoai.chillscript.domain.BatchNoteRules
import com.sponteoai.chillscript.domain.TrashPolicy
import com.sponteoai.chillscript.domain.SearchQueryBuilder
import com.sponteoai.chillscript.domain.normalizeImportedTranscriptMarkdown
import kotlinx.coroutines.flow.map

class NotesRepository(
    private val dao: ChillScriptDao,
    private val syncApi: SyncClient,
    private val linkImportApi: LinkImportApi = LinkImportApi(),
) {
    fun observeNotes(userId: String): Flow<List<NoteEntity>> =
        dao.observeNotes(userId).map { notes -> notes.map(NoteEntity::withCanonicalImportedTranscriptSpacing) }
    fun searchNotes(userId: String, rawQuery: String): Flow<List<NoteEntity>> {
        val query = SearchQueryBuilder.build(rawQuery)
        return dao.searchNotes(userId, query.match, query.like)
            .map { notes -> notes.map(NoteEntity::withCanonicalImportedTranscriptSpacing) }
    }
    fun observeTags(userId: String): Flow<List<TagEntity>> = dao.observeTags(userId)
    fun observeNoteTags() = dao.observeNoteTags()
    fun observeChecklistItems(noteId: String) = dao.observeChecklistItems(noteId)
    suspend fun note(userId: String, noteId: String): NoteEntity? =
        dao.note(userId, noteId)?.withCanonicalImportedTranscriptSpacing()

    suspend fun hasPendingLinkImport(userId: String, sourceUrl: String): Boolean =
        dao.hasPendingLinkImport(userId, sourceUrl)

    /** Invalidates every response produced by a sync that started before account deletion. */
    suspend fun invalidateInFlightSync(userId: String) {
        val guard = userSyncGuard(userId)
        guard.mutex.withLock { guard.epoch += 1 }
    }

    /**
     * Clearing and the final response/apply check share the same per-user gate.
     * A response can therefore apply entirely before this clear (and then be
     * removed), or observe the new epoch and be discarded, but can never land
     * between the clear and its epoch invalidation.
     */
    suspend fun clearLocalUserData(userId: String) {
        val guard = userSyncGuard(userId)
        guard.mutex.withLock {
            guard.epoch += 1
            dao.clearLocalUserData(userId)
        }
    }

    suspend fun createNote(
        userId: String,
        content: String,
        section: String = "inbox",
        noteId: String = UUID.randomUUID().toString(),
    ): NoteEntity {
        val now = Instant.now().toString()
        val parsed = ChecklistMarkdown.parse(content)
        return NoteEntity(
            id = noteId,
            userId = userId,
            content = content,
            contentFormat = if (parsed == null) "text" else "checklist",
            checklistNotes = parsed?.notes.orEmpty(),
            previewPlainText = content.toPreviewText(),
            createdAt = now,
            updatedAt = now,
            section = section,
        ).also { note ->
            dao.upsertNote(note)
            syncChecklistStructure(note, parsed)
        }
    }

    suspend fun updateNote(note: NoteEntity, content: String, section: String = note.section): NoteEntity {
        val parsed = ChecklistMarkdown.parse(content)
        return note.copy(
                content = content,
                contentFormat = if (parsed == null) "text" else "checklist",
                checklistNotes = parsed?.notes.orEmpty(),
                previewPlainText = content.toPreviewText(),
                section = section,
                updatedAt = Instant.now().toString(),
                version = note.version + 1,
                needsSync = true,
            ).also { updated ->
                dao.upsertNote(updated)
                syncChecklistStructure(updated, parsed)
            }
    }

    /**
     * Updates from the latest local row instead of a UI snapshot.
     *
     * The editor can queue a debounced save immediately before its final back
     * save. Reading the row again here keeps versions monotonic and prevents an
     * older NoteEntity snapshot from restoring stale deletion/section state.
     */
    suspend fun updateLatestNote(
        userId: String,
        noteId: String,
        content: String,
        section: String,
    ): NoteEntity? {
        val latest = dao.note(userId, noteId) ?: return null
        return updateNote(latest, content, section)
    }

    suspend fun updateNoteContent(userId: String, noteId: String, content: String): NoteEntity? {
        val note = dao.note(userId, noteId) ?: return null
        return updateNote(note, content)
    }

    suspend fun moveToTrash(note: NoteEntity) {
        val latest = dao.note(note.userId, note.id) ?: return
        val now = Instant.now().toString()
        dao.upsertNote(latest.copy(deletedAt = now, updatedAt = now, version = latest.version + 1, needsSync = true))
    }

    suspend fun restore(note: NoteEntity) {
        val latest = dao.note(note.userId, note.id) ?: return
        val now = Instant.now().toString()
        dao.tagsForNote(latest.id).filter { it.deletedAt != null }.forEach { tag ->
            dao.upsertTag(tag.copy(deletedAt = null, updatedAt = now, version = tag.version + 1, needsSync = true))
        }
        dao.upsertNote(latest.copy(deletedAt = null, updatedAt = now, version = latest.version + 1, needsSync = true))
    }

    suspend fun togglePin(note: NoteEntity) {
        val latest = dao.note(note.userId, note.id) ?: return
        dao.upsertNote(
            latest.copy(
                pinnedAt = if (latest.pinnedAt == null) Instant.now().toString() else null,
                updatedAt = Instant.now().toString(),
                version = latest.version + 1,
                needsSync = true,
            ),
        )
    }

    suspend fun moveNote(userId: String, noteId: String, section: String): NoteEntity? {
        val latest = dao.note(userId, noteId) ?: return null
        if (latest.deletedAt != null || latest.section == section) return latest
        val updated = latest.copy(
            section = section,
            updatedAt = Instant.now().toString(),
            version = latest.version + 1,
            needsSync = true,
        )
        dao.upsertNote(updated)
        return updated
    }

    suspend fun createTag(userId: String, name: String, colorHex: String, parentId: String? = null): TagEntity {
        val now = Instant.now().toString()
        val existing = dao.activeTags(userId)
        val validParentId = parentId?.takeIf { candidate -> existing.any { it.id == candidate } }
        val siblingCount = existing.count { it.parentId == validParentId }
        return TagEntity(
            id = UUID.randomUUID().toString(), userId = userId, name = name.trim(), colorHex = TagColors.normalize(colorHex),
            createdAt = now, updatedAt = now, lastUsedAt = now, parentId = validParentId, sortOrder = siblingCount,
        ).also { dao.upsertTag(it) }
    }

    suspend fun findOrCreateTag(
        userId: String,
        name: String,
        colorHex: String,
        parentId: String? = null,
    ): TagEntity {
        val normalizedName = name.trim()
        val existing = dao.activeTags(userId).firstOrNull {
            it.name.equals(normalizedName, ignoreCase = true)
        }
        if (existing != null) return existing
        return createTag(userId, normalizedName, colorHex, parentId)
    }

    suspend fun updateTag(tag: TagEntity, name: String, colorHex: String, parentId: String?) {
        val latest = dao.tag(tag.userId, tag.id) ?: return
        val activeTags = dao.activeTags(latest.userId)
        val validParentIds = TagHierarchy.validParents(latest.id, activeTags).mapTo(mutableSetOf()) { it.id }
        val validParentId = parentId?.takeIf(validParentIds::contains)
        val siblingCount = activeTags.count { it.id != latest.id && it.parentId == validParentId }
        dao.upsertTag(latest.copy(
            name = name.trim(),
            colorHex = TagColors.normalize(colorHex),
            parentId = validParentId,
            sortOrder = if (latest.parentId == validParentId) latest.sortOrder else siblingCount,
            updatedAt = Instant.now().toString(),
            version = latest.version + 1,
            needsSync = true,
        ))
    }

    suspend fun deleteTag(tag: TagEntity) {
        val latest = dao.tag(tag.userId, tag.id) ?: return
        val now = Instant.now().toString()
        val affectedNoteIds = dao.noteIdsForTag(latest.id)
        dao.deleteNoteTagsForTag(latest.id)
        if (affectedNoteIds.isNotEmpty()) dao.markNotesChanged(affectedNoteIds, now)
        dao.childTags(latest.userId, latest.id).forEach { child ->
            dao.upsertTag(child.copy(
                parentId = null,
                updatedAt = now,
                version = child.version + 1,
                needsSync = true,
            ))
        }
        dao.upsertTag(latest.copy(
            parentId = null,
            deletedAt = now,
            updatedAt = now,
            version = latest.version + 1,
            needsSync = true,
        ))
    }

    suspend fun createWelcomeContent(userId: String, content: String, tagName: String) {
        val now = Instant.now().toString()
        val note = NoteEntity(
            id = UUID.randomUUID().toString(), userId = userId, content = content,
            previewPlainText = content.toPreviewText(), createdAt = now, updatedAt = now,
        )
        val tag = TagEntity(
            id = UUID.randomUUID().toString(), userId = userId, name = tagName,
            colorHex = TagColors.Default, createdAt = now, updatedAt = now, lastUsedAt = now,
        )
        dao.insertWelcomeContent(note, tag)
    }

    suspend fun setNoteTags(note: NoteEntity, tagIds: List<String>): NoteEntity {
        val latest = dao.note(note.userId, note.id) ?: return note
        dao.replaceNoteTags(latest.id, tagIds.distinct())
        val updated = latest.copy(
            updatedAt = Instant.now().toString(),
            version = latest.version + 1,
            needsSync = true,
        )
        dao.upsertNote(updated)
        return updated
    }

    suspend fun addTagToNote(userId: String, noteId: String, tag: TagEntity): Boolean {
        val latest = dao.note(userId, noteId) ?: return false
        addTagToNotes(listOf(latest), tag)
        return true
    }

    suspend fun removeTagFromNote(userId: String, noteId: String, tagId: String): Boolean {
        val latest = dao.note(userId, noteId) ?: return false
        val tagIds = dao.tagIdsForNote(noteId)
        if (tagId !in tagIds) return true
        val now = Instant.now().toString()
        dao.replaceNoteTags(noteId, tagIds - tagId)
        dao.upsertNote(
            latest.copy(
                updatedAt = now,
                version = latest.version + 1,
                needsSync = true,
            ),
        )
        return true
    }

    suspend fun addTagToNotes(notes: List<NoteEntity>, tag: TagEntity) {
        if (notes.isEmpty()) return
        val latestTag = dao.tag(tag.userId, tag.id)?.takeIf { it.deletedAt == null } ?: return
        val now = Instant.now().toString()
        var attachedAny = false
        notes.forEach { snapshot ->
            val note = dao.note(snapshot.userId, snapshot.id) ?: return@forEach
            if (note.deletedAt != null) return@forEach
            val tagIds = dao.tagIdsForNote(note.id)
            if (latestTag.id !in tagIds) {
                dao.replaceNoteTags(note.id, tagIds + latestTag.id)
                dao.upsertNote(note.copy(updatedAt = now, version = note.version + 1, needsSync = true))
                attachedAny = true
            }
        }
        if (attachedAny) {
            dao.upsertTag(latestTag.copy(
                lastUsedAt = now,
                updatedAt = now,
                version = latestTag.version + 1,
                needsSync = true,
            ))
        }
    }

    suspend fun deleteNotes(userId: String, notes: List<NoteEntity>) {
        val latestNotes = notes.mapNotNull { snapshot -> dao.note(userId, snapshot.id) }
        val plan = BatchNoteRules.deletionPlan(latestNotes)
        if (plan.softDelete.isEmpty() && plan.hardDeleteIds.isEmpty()) return
        val now = Instant.now().toString()
        plan.softDelete.forEach { note ->
            dao.upsertNote(note.copy(deletedAt = now, updatedAt = now, version = note.version + 1, needsSync = true))
        }
        if (plan.hardDeleteIds.isNotEmpty()) dao.permanentlyDeleteNotes(userId, plan.hardDeleteIds, now)
    }

    suspend fun permanentlyDelete(userId: String, note: NoteEntity) {
        dao.permanentlyDeleteNote(userId, note.id, Instant.now().toString())
    }

    suspend fun emptyTrash(userId: String) {
        val deletedIds = dao.deletedNoteIds(userId)
        if (deletedIds.isNotEmpty()) dao.permanentlyDeleteNotes(userId, deletedIds, Instant.now().toString())
    }

    suspend fun purgeExpiredTrash(userId: String) {
        val now = Instant.now()
        val cutoff = TrashPolicy.cutoff(now).toString()
        val expiredNotes = dao.expiredNoteIds(userId, cutoff)
        val expiredTags = dao.expiredTagIds(userId, cutoff)
        if (expiredNotes.isNotEmpty()) dao.permanentlyDeleteNotes(userId, expiredNotes, now.toString())
        if (expiredTags.isNotEmpty()) dao.permanentlyDeleteTags(userId, expiredTags, now.toString())
    }

    suspend fun importLink(
        userId: String, accessToken: String, url: String, section: String, placeholder: String,
        mediaLinkSections: MediaLinkSectionsDto = MediaLinkSectionsDto.TranscriptOnly,
        tagIds: List<String> = emptyList(),
        noteId: String = UUID.randomUUID().toString(),
        source: LinkSourceDto = sourceForUrl(url),
    ): NoteEntity {
        dao.note(userId, noteId)?.let { return it }
        val created = createNote(userId, placeholder, section, noteId)
        val tagged = if (tagIds.isEmpty()) created else setNoteTags(created, tagIds)
        val note = tagged.copy(
            sourceUrl = source.url,
            sourceTitle = source.title,
            sourcePlatformId = source.platformID,
            sourcePlatformName = source.platformName,
            sourceHost = source.host,
            sourceAuthorName = source.authorName,
            sourceAuthorHandle = source.authorHandle,
            sourceCapturedAt = Instant.now().toString(),
            importStatus = "queued",
        )
        dao.upsertNote(note)
        return try {
            // Upload the relationship before the import worker can complete.
            // Once a server import is finished, queued client snapshots are
            // intentionally ignored to protect the generated content.
            if (tagIds.isNotEmpty()) sync(userId, accessToken)
            val job = linkImportApi.enqueue(
                accessToken,
                LinkImportRequest(note.id, url, placeholder, source, section, mediaLinkSections),
            )
            // The import endpoint creates the server-side note, but it does not
            // receive tag relationships. Keep tagged captures dirty for the
            // following sync so the active iOS-style tag context is preserved.
            note.copy(importJobId = job.jobId, importStatus = job.status, needsSync = tagIds.isNotEmpty())
                .also { dao.upsertNote(it) }
        } catch (error: Throwable) {
            note.copy(importStatus = "failed", importErrorCode = error.message, needsSync = true)
                .also { dao.upsertNote(it) }
            throw error
        }
    }

    /**
     * Creates the local placeholder for a job that the lightweight share
     * activity already accepted on the server. The shared UUID makes this
     * operation safe to repeat after process death.
     */
    suspend fun adoptPendingLinkImport(
        userId: String,
        noteId: String,
        placeholder: String,
        source: LinkSourceDto,
        importJobId: String,
        importStatus: String,
        createdAt: String,
    ): NoteEntity {
        dao.note(userId, noteId)?.let { return it }
        return NoteEntity(
            id = noteId,
            userId = userId,
            content = placeholder,
            previewPlainText = placeholder.toPreviewText(),
            createdAt = createdAt,
            updatedAt = createdAt,
            sourceUrl = source.url,
            sourceTitle = source.title,
            sourcePlatformId = source.platformID,
            sourcePlatformName = source.platformName,
            sourceHost = source.host,
            sourceAuthorName = source.authorName,
            sourceAuthorHandle = source.authorHandle,
            sourceCapturedAt = createdAt,
            section = "inbox",
            importStatus = importStatus,
            importJobId = importJobId,
            importStartedAt = createdAt,
            needsSync = false,
        ).also { dao.upsertNote(it) }
    }

    suspend fun sync(userId: String, accessToken: String) = syncMutex.withLock {
        val guard = userSyncGuard(userId)
        val expectedEpoch = guard.mutex.withLock { guard.epoch }
        // Old iOS versions could round-trip an Android UUID using uppercase letters,
        // leaving multiple Room rows for one logical identity. Repair those rows
        // and relationships before preparing durable mutations.
        dao.collapseCaseVariantNotes(userId)
        dao.collapseCaseVariantTags(userId)
        var state = dao.syncState(userId) ?: SyncStateEntity(userId, deviceId = UUID.randomUUID().toString())
        val initialNotes = dao.pendingNotes(userId)
        val initialTags = dao.pendingTags(userId)
        val initialHardDeletedNotes = dao.pendingHardDeletes(userId, "note")
        val initialHardDeletedTags = dao.pendingHardDeletes(userId, "tag")
        val needsInitialBootstrap = state.cursor == null && (
            initialNotes.any { it.serverVersion == null } ||
                initialTags.any { it.serverVersion == null } ||
                initialHardDeletedNotes.isNotEmpty() ||
                initialHardDeletedTags.isNotEmpty()
            )

        if (needsInitialBootstrap) {
            val bootstrap = syncApi.sync(
                accessToken,
                SyncPayload(
                    protocolVersion = DURABLE_SYNC_PROTOCOL_VERSION,
                    cursor = state.cursor,
                    deviceId = state.deviceId,
                    notes = emptyList(),
                    tags = emptyList(),
                ),
            )
            state = applySyncResponse(
                userId = userId,
                expectedEpoch = expectedEpoch,
                state = state,
                response = bootstrap,
                uploaded = PreparedSyncUploads(emptyList(), emptyList()),
                uploadedHardDeletedNotes = emptyList(),
                uploadedHardDeletedTags = emptyList(),
                blockPendingHardDeleteEntities = true,
                establishMissingServerBaselines = true,
            ) ?: return@withLock
        }

        val prepared = dao.preparePendingSyncUploads(userId)
        val hardDeletedNotes = dao.pendingHardDeletes(userId, "note")
        val hardDeletedTags = dao.pendingHardDeletes(userId, "tag")
        if (needsInitialBootstrap && prepared.notes.isEmpty() && prepared.tags.isEmpty() &&
            hardDeletedNotes.isEmpty() && hardDeletedTags.isEmpty()
        ) return@withLock

        val response = syncApi.sync(
            accessToken,
            SyncPayload(
                protocolVersion = DURABLE_SYNC_PROTOCOL_VERSION,
                cursor = state.cursor,
                deviceId = state.deviceId,
                notes = prepared.notes.map(PreparedNoteUpload::toDto),
                tags = prepared.tags.map(PreparedTagUpload::toDto),
                hardDeletedNoteIds = hardDeletedNotes.map { it.entityId }.ifEmpty { null },
                hardDeletedTagIds = hardDeletedTags.map { it.entityId }.ifEmpty { null },
            ),
        )
        applySyncResponse(
            userId = userId,
            expectedEpoch = expectedEpoch,
            state = state,
            response = response,
            uploaded = prepared,
            uploadedHardDeletedNotes = hardDeletedNotes,
            uploadedHardDeletedTags = hardDeletedTags,
        )
    }

    private suspend fun applySyncResponse(
        userId: String,
        expectedEpoch: Long,
        state: SyncStateEntity,
        response: SyncResponse,
        uploaded: PreparedSyncUploads,
        uploadedHardDeletedNotes: List<com.sponteoai.chillscript.data.local.PendingHardDeleteEntity>,
        uploadedHardDeletedTags: List<com.sponteoai.chillscript.data.local.PendingHardDeleteEntity>,
        blockPendingHardDeleteEntities: Boolean = false,
        establishMissingServerBaselines: Boolean = false,
    ): SyncStateEntity? {
        response.conflicts.firstOrNull { it.entityType !in setOf("note", "tag") }?.let { conflict ->
            throw SyncProtocolException("Unknown sync conflict type ${conflict.entityType}")
        }
        val conflictedNoteIds = response.conflicts.filter { it.entityType == "note" }.map { it.id }
        val conflictedTagIds = response.conflicts.filter { it.entityType == "tag" }.map { it.id }
        val forceServerNoteIds = conflictedNoteIds + response.forcedNoteIds
        val forceServerTagIds = conflictedTagIds + response.forcedTagIds
        // Every entity upload must be echoed as an accepted/forced entity or a
        // tombstone, while a permanent-delete upload requires the tombstone itself.
        // Fail before the transaction so dirty state and cursors never advance blindly.
        response.requireAuthoritativeChanges(
            requiredNoteIds = uploaded.notes.map { it.note.id } + conflictedNoteIds + response.forcedNoteIds,
            requiredTagIds = uploaded.tags.map { it.tag.id } + conflictedTagIds + response.forcedTagIds,
            requiredHardDeletedNoteIds = uploadedHardDeletedNotes.map { it.entityId },
            requiredHardDeletedTagIds = uploadedHardDeletedTags.map { it.entityId },
        )
        response.requireDurableMutationAcknowledgements(
            submittedNotes = uploaded.notes.map {
                SubmittedSyncMutation(it.note.id, it.note.lastSubmittedMutationId)
            },
            submittedTags = uploaded.tags.map {
                SubmittedSyncMutation(it.tag.id, it.tag.lastSubmittedMutationId)
            },
            conflictedNoteIds = conflictedNoteIds,
            conflictedTagIds = conflictedTagIds,
        )
        val nextState = state.copy(cursor = response.cursor, lastSyncedAt = response.serverTime)
        val guard = userSyncGuard(userId)
        return guard.mutex.withLock {
            if (guard.epoch != expectedEpoch) return@withLock null
            dao.applySyncResult(
                userId = userId,
                uploadedNotes = uploaded.notes.map { SyncUploadSnapshot(it.note.id, it.note.version, it.note.updatedAt) },
                uploadedTags = uploaded.tags.map { SyncUploadSnapshot(it.tag.id, it.tag.version, it.tag.updatedAt) },
                uploadedHardDeletedNotes = uploadedHardDeletedNotes,
                uploadedHardDeletedTags = uploadedHardDeletedTags,
                notes = response.changes.notes.map { it.toRemoteChange(userId) },
                tags = response.changes.tags.map { it.toRemoteChange(userId) },
                hardDeletedNoteIds = response.changes.hardDeletedNoteIds,
                hardDeletedTagIds = response.changes.hardDeletedTagIds,
                conflictedNoteIds = conflictedNoteIds,
                conflictedTagIds = conflictedTagIds,
                forceServerNoteIds = forceServerNoteIds,
                forceServerTagIds = forceServerTagIds,
                blockPendingHardDeleteEntities = blockPendingHardDeleteEntities,
                establishMissingServerBaselines = establishMissingServerBaselines,
                syncState = nextState,
            )
            nextState
        }
    }

    private suspend fun syncChecklistStructure(
        note: NoteEntity,
        parsed: com.sponteoai.chillscript.domain.ChecklistDraft?,
    ) {
        val existing = dao.checklistItems(note.id)
        val now = Instant.now().toString()
        val items = parsed?.items.orEmpty().mapIndexed { index, item ->
            val old = existing.getOrNull(index)
            ChecklistItemEntity(
                id = old?.id ?: UUID.randomUUID().toString(),
                noteId = note.id,
                text = item.text,
                isDone = item.isDone,
                sortOrder = index,
                createdAt = old?.createdAt?.takeIf(String::isNotEmpty) ?: now,
                updatedAt = now,
            )
        }
        dao.replaceChecklistItems(note.id, items)
    }

    private companion object {
        val syncMutex = Mutex()
        val userSyncGuards = ConcurrentHashMap<String, UserSyncEpochGuard>()
        const val DURABLE_SYNC_PROTOCOL_VERSION = 4

        fun userSyncGuard(userId: String): UserSyncEpochGuard =
            userSyncGuards.computeIfAbsent(userId) { UserSyncEpochGuard() }
    }
}

private class UserSyncEpochGuard(
    val mutex: Mutex = Mutex(),
    var epoch: Long = 0,
)

class SyncProtocolException(message: String) : IllegalStateException(message)

private data class SubmittedSyncMutation(
    val id: String,
    val mutationId: String?,
)

private fun SyncResponse.requireAuthoritativeChanges(
    requiredNoteIds: List<String>,
    requiredTagIds: List<String>,
    requiredHardDeletedNoteIds: List<String>,
    requiredHardDeletedTagIds: List<String>,
) {
    if (requiredNoteIds.isEmpty() && requiredTagIds.isEmpty() &&
        requiredHardDeletedNoteIds.isEmpty() && requiredHardDeletedTagIds.isEmpty()
    ) return
    val hardDeletedNoteIds = changes.hardDeletedNoteIds.mapTo(mutableSetOf(), ::canonicalSyncIdentity)
    val hardDeletedTagIds = changes.hardDeletedTagIds.mapTo(mutableSetOf(), ::canonicalSyncIdentity)
    val authoritativeNoteIds = changes.notes.mapTo(mutableSetOf()) { canonicalSyncIdentity(it.id) }.apply {
        addAll(hardDeletedNoteIds)
    }
    val authoritativeTagIds = changes.tags.mapTo(mutableSetOf()) { canonicalSyncIdentity(it.id) }.apply {
        addAll(hardDeletedTagIds)
    }
    requiredNoteIds.firstOrNull { canonicalSyncIdentity(it) !in authoritativeNoteIds }?.let { noteId ->
        throw SyncProtocolException("Sync note $noteId has no authoritative change")
    }
    requiredTagIds.firstOrNull { canonicalSyncIdentity(it) !in authoritativeTagIds }?.let { tagId ->
        throw SyncProtocolException("Sync tag $tagId has no authoritative change")
    }
    requiredHardDeletedNoteIds.firstOrNull { canonicalSyncIdentity(it) !in hardDeletedNoteIds }?.let { noteId ->
        throw SyncProtocolException("Hard-deleted note $noteId has no server tombstone")
    }
    requiredHardDeletedTagIds.firstOrNull { canonicalSyncIdentity(it) !in hardDeletedTagIds }?.let { tagId ->
        throw SyncProtocolException("Hard-deleted tag $tagId has no server tombstone")
    }
}

private fun SyncResponse.requireDurableMutationAcknowledgements(
    submittedNotes: List<SubmittedSyncMutation>,
    submittedTags: List<SubmittedSyncMutation>,
    conflictedNoteIds: List<String>,
    conflictedTagIds: List<String>,
) {
    val notesById = changes.notes.associateBy { canonicalSyncIdentity(it.id) }
    val tagsById = changes.tags.associateBy { canonicalSyncIdentity(it.id) }
    val hardDeletedNoteIds = changes.hardDeletedNoteIds.mapTo(mutableSetOf(), ::canonicalSyncIdentity)
    val hardDeletedTagIds = changes.hardDeletedTagIds.mapTo(mutableSetOf(), ::canonicalSyncIdentity)
    val declaredForcedNoteIds = forcedNoteIds.mapTo(mutableSetOf(), ::canonicalSyncIdentity)
    val declaredForcedTagIds = forcedTagIds.mapTo(mutableSetOf(), ::canonicalSyncIdentity)
    val authoritativeNoteOverrides = declaredForcedNoteIds.toMutableSet().apply {
        conflictedNoteIds.mapTo(this, ::canonicalSyncIdentity)
    }
    val authoritativeTagOverrides = declaredForcedTagIds.toMutableSet().apply {
        conflictedTagIds.mapTo(this, ::canonicalSyncIdentity)
    }

    // Ordinary forced IDs promise an entity body. Permanent deletions use the
    // dedicated tombstone arrays and must never masquerade as a forced entity.
    declaredForcedNoteIds.firstOrNull { it !in notesById }?.let { noteId ->
        throw SyncProtocolException("Forced sync note $noteId has no entity change")
    }
    declaredForcedTagIds.firstOrNull { it !in tagsById }?.let { tagId ->
        throw SyncProtocolException("Forced sync tag $tagId has no entity change")
    }

    submittedNotes.forEach { submitted ->
        val id = canonicalSyncIdentity(submitted.id)
        if (id in hardDeletedNoteIds) {
            if (id !in authoritativeNoteOverrides) {
                throw SyncProtocolException("Sync note ${submitted.id} was tombstoned without a conflict")
            }
            return@forEach
        }
        val authoritative = notesById[id]
            ?: throw SyncProtocolException("Sync note ${submitted.id} has no entity change")
        if (id !in authoritativeNoteOverrides &&
            !sameSyncMutation(submitted.mutationId, authoritative.mutationId)
        ) {
            throw SyncProtocolException("Sync note ${submitted.id} acknowledged a different mutation")
        }
    }
    submittedTags.forEach { submitted ->
        val id = canonicalSyncIdentity(submitted.id)
        if (id in hardDeletedTagIds) {
            if (id !in authoritativeTagOverrides) {
                throw SyncProtocolException("Sync tag ${submitted.id} was tombstoned without a conflict")
            }
            return@forEach
        }
        val authoritative = tagsById[id]
            ?: throw SyncProtocolException("Sync tag ${submitted.id} has no entity change")
        if (id !in authoritativeTagOverrides &&
            !sameSyncMutation(submitted.mutationId, authoritative.mutationId)
        ) {
            throw SyncProtocolException("Sync tag ${submitted.id} acknowledged a different mutation")
        }
    }
}

private fun sameSyncMutation(left: String?, right: String?): Boolean =
    left != null && right != null && left.equals(right, ignoreCase = true)

private fun String.toPreviewText(): String =
    replace(Regex("!\\[[^]]*]\\([^)]+\\)"), "")
        .replace(Regex("(?m)^#{1,6}\\s+"), "")
        .replace("**", "")
        .replace("`", "")
        .replace(Regex("(?m)^\\s*[-*]\\s*\\[ ]\\s*"), "○ ")
        .replace(Regex("(?mi)^\\s*[-*]\\s*\\[x]\\s*"), "◉ ")
        .take(360)

private fun NoteEntity.withCanonicalImportedTranscriptSpacing(): NoteEntity {
    val normalizedContent = normalizeImportedTranscriptMarkdown(content, sourceUrl, sourcePlatformId)
    return if (normalizedContent == content) this else copy(
        content = normalizedContent,
        previewPlainText = normalizedContent.toPreviewText(),
    )
}

private fun PreparedNoteUpload.toDto() = NoteDto(
    id = note.id,
    content = note.content,
    createdAt = note.createdAt,
    updatedAt = note.updatedAt,
    deletedAt = note.deletedAt,
    pinnedAt = note.pinnedAt,
    tagIds = tagIds,
    version = null,
    baseVersion = note.serverVersion ?: 0,
    mutationId = note.lastSubmittedMutationId,
    previousMutationId = this.previousMutationId,
    clientUpdatedAt = note.updatedAt,
    lastModifiedByDeviceId = note.lastModifiedByDeviceId,
    sourceURL = note.sourceUrl,
    sourceTitle = note.sourceTitle,
    sourcePlatformID = note.sourcePlatformId,
    sourcePlatformName = note.sourcePlatformName,
    sourceHost = note.sourceHost,
    sourceAuthorName = note.sourceAuthorName,
    sourceAuthorHandle = note.sourceAuthorHandle,
    sourceCapturedAt = note.sourceCapturedAt,
    section = note.section,
    importStatus = note.importStatus,
    importJobId = note.importJobId,
    importErrorCode = note.importErrorCode,
    importStartedAt = note.importStartedAt,
    importCompletedAt = note.importCompletedAt,
)

private fun PreparedTagUpload.toDto() = TagDto(
    id = tag.id,
    name = tag.name,
    colorHex = tag.colorHex,
    createdAt = tag.createdAt,
    updatedAt = tag.updatedAt,
    lastUsedAt = tag.lastUsedAt,
    sortOrder = tag.sortOrder,
    parentId = tag.parentId,
    deletedAt = tag.deletedAt,
    version = null,
    baseVersion = tag.serverVersion ?: 0,
    mutationId = tag.lastSubmittedMutationId,
    previousMutationId = this.previousMutationId,
    clientUpdatedAt = tag.updatedAt,
    lastModifiedByDeviceId = tag.lastModifiedByDeviceId,
)

private fun NoteDto.toEntity(userId: String): NoteEntity {
    val normalizedContent = normalizeImportedTranscriptMarkdown(content, sourceURL, sourcePlatformID)
    val parsed = ChecklistMarkdown.parse(normalizedContent)
    return NoteEntity(
        id = id, userId = userId, content = normalizedContent,
        contentFormat = if (parsed == null) "text" else "checklist",
        checklistNotes = parsed?.notes.orEmpty(),
        previewPlainText = normalizedContent.toPreviewText(),
        createdAt = createdAt, updatedAt = updatedAt ?: createdAt, deletedAt = deletedAt, pinnedAt = pinnedAt,
        version = 1, serverVersion = version, serverMutationId = mutationId,
        lastModifiedByDeviceId = lastModifiedByDeviceId, sourceUrl = sourceURL,
        sourceTitle = sourceTitle, sourcePlatformId = sourcePlatformID, sourcePlatformName = sourcePlatformName,
        sourceHost = sourceHost, sourceAuthorName = sourceAuthorName, sourceAuthorHandle = sourceAuthorHandle,
        sourceCapturedAt = sourceCapturedAt, section = section ?: "inbox",
        importStatus = importStatus, importJobId = importJobId, importErrorCode = importErrorCode,
        importStartedAt = importStartedAt, importCompletedAt = importCompletedAt, needsSync = false,
    )
}

private fun NoteDto.toRemoteChange(userId: String): RemoteNoteChange {
    val note = toEntity(userId)
    val parsed = ChecklistMarkdown.parse(note.content)
    val items = parsed?.items.orEmpty().mapIndexed { index, item ->
        ChecklistItemEntity(
            id = UUID.randomUUID().toString(),
            noteId = note.id,
            text = item.text,
            isDone = item.isDone,
            sortOrder = index,
            createdAt = note.updatedAt,
            updatedAt = note.updatedAt,
        )
    }
    return RemoteNoteChange(
        note = note,
        tagIds = tagIds.orEmpty(),
        checklistItems = items,
        remoteVersion = version,
        remoteUpdatedAt = updatedAt ?: createdAt,
    )
}

private fun TagDto.toEntity(userId: String) = TagEntity(
    id = id,
    userId = userId,
    name = name,
    colorHex = colorHex,
    createdAt = createdAt,
    updatedAt = updatedAt ?: createdAt,
    lastUsedAt = lastUsedAt ?: createdAt,
    parentId = parentId,
    sortOrder = sortOrder,
    deletedAt = deletedAt,
    version = 1,
    serverVersion = version,
    serverMutationId = mutationId,
    lastModifiedByDeviceId = lastModifiedByDeviceId,
    needsSync = false,
)

private fun TagDto.toRemoteChange(userId: String) = RemoteTagChange(
    tag = toEntity(userId),
    remoteVersion = version,
    remoteUpdatedAt = updatedAt ?: createdAt,
)
