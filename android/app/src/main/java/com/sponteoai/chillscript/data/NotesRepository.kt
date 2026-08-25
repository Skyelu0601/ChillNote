package com.sponteoai.chillscript.data

import com.sponteoai.chillscript.data.local.ChillScriptDao
import com.sponteoai.chillscript.data.local.ChecklistItemEntity
import com.sponteoai.chillscript.data.local.NoteEntity
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
import com.sponteoai.chillscript.data.remote.TagDto
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.time.Instant
import java.util.UUID
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

    suspend fun clearLocalUserData(userId: String) = dao.clearLocalUserData(userId)

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
        dao.upsertNote(
            note.copy(
                pinnedAt = if (note.pinnedAt == null) Instant.now().toString() else null,
                updatedAt = Instant.now().toString(),
                version = note.version + 1,
                needsSync = true,
            ),
        )
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
        val activeTags = dao.activeTags(tag.userId)
        val validParentIds = TagHierarchy.validParents(tag.id, activeTags).mapTo(mutableSetOf()) { it.id }
        val validParentId = parentId?.takeIf(validParentIds::contains)
        val siblingCount = activeTags.count { it.id != tag.id && it.parentId == validParentId }
        dao.upsertTag(tag.copy(
            name = name.trim(),
            colorHex = TagColors.normalize(colorHex),
            parentId = validParentId,
            sortOrder = if (tag.parentId == validParentId) tag.sortOrder else siblingCount,
            updatedAt = Instant.now().toString(),
            version = tag.version + 1,
            needsSync = true,
        ))
    }

    suspend fun deleteTag(tag: TagEntity) {
        val now = Instant.now().toString()
        val affectedNoteIds = dao.noteIdsForTag(tag.id)
        dao.deleteNoteTagsForTag(tag.id)
        if (affectedNoteIds.isNotEmpty()) dao.markNotesChanged(affectedNoteIds, now)
        dao.childTags(tag.userId, tag.id).forEach { child ->
            dao.upsertTag(child.copy(
                parentId = null,
                updatedAt = now,
                version = child.version + 1,
                needsSync = true,
            ))
        }
        dao.upsertTag(tag.copy(
            parentId = null,
            deletedAt = now,
            updatedAt = now,
            version = tag.version + 1,
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
        dao.replaceNoteTags(note.id, tagIds.distinct())
        val updated = note.copy(
            updatedAt = Instant.now().toString(),
            version = note.version + 1,
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
        val now = Instant.now().toString()
        notes.forEach { note ->
            val tagIds = dao.tagIdsForNote(note.id)
            if (tag.id !in tagIds) {
                dao.replaceNoteTags(note.id, tagIds + tag.id)
                dao.upsertNote(note.copy(updatedAt = now, version = note.version + 1, needsSync = true))
            }
        }
        dao.upsertTag(tag.copy(lastUsedAt = now, updatedAt = now, version = tag.version + 1, needsSync = true))
    }

    suspend fun deleteNotes(userId: String, notes: List<NoteEntity>) {
        val plan = BatchNoteRules.deletionPlan(notes)
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
        val state = dao.syncState(userId) ?: SyncStateEntity(userId, deviceId = UUID.randomUUID().toString())
        val localNotes = dao.pendingNotes(userId)
        val localTags = dao.pendingTags(userId)
        val hardDeletedNotes = dao.pendingHardDeletes(userId, "note")
        val hardDeletedTags = dao.pendingHardDeletes(userId, "tag")
        val response = syncApi.sync(
            accessToken,
            SyncPayload(
                cursor = state.cursor,
                deviceId = state.deviceId,
                notes = localNotes.map { it.toDto(dao.tagIdsForNote(it.id)) },
                tags = localTags.map(TagEntity::toDto),
                hardDeletedNoteIds = hardDeletedNotes.map { it.entityId }.ifEmpty { null },
                hardDeletedTagIds = hardDeletedTags.map { it.entityId }.ifEmpty { null },
            ),
        )
        dao.applySyncResult(
            userId = userId,
            uploadedNotes = localNotes.map { SyncUploadSnapshot(it.id, it.version, it.updatedAt) },
            uploadedTags = localTags.map { SyncUploadSnapshot(it.id, it.version, it.updatedAt) },
            uploadedHardDeletedNotes = hardDeletedNotes,
            uploadedHardDeletedTags = hardDeletedTags,
            notes = response.changes.notes.map { it.toRemoteChange(userId) },
            tags = response.changes.tags.map { it.toRemoteChange(userId) },
            hardDeletedNoteIds = response.changes.hardDeletedNoteIds,
            hardDeletedTagIds = response.changes.hardDeletedTagIds,
            syncState = state.copy(cursor = response.cursor, lastSyncedAt = response.serverTime),
        )
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
    }
}

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

private fun NoteEntity.toDto(tagIds: List<String>) = NoteDto(
    id, content, createdAt, updatedAt, deletedAt, pinnedAt, tagIds = tagIds, version = version,
    baseVersion = version, clientUpdatedAt = updatedAt, lastModifiedByDeviceId = lastModifiedByDeviceId,
    sourceURL = sourceUrl, sourceTitle = sourceTitle, sourcePlatformID = sourcePlatformId,
    sourcePlatformName = sourcePlatformName, sourceHost = sourceHost,
    sourceAuthorName = sourceAuthorName, sourceAuthorHandle = sourceAuthorHandle,
    sourceCapturedAt = sourceCapturedAt,
    section = section, importStatus = importStatus, importJobId = importJobId,
    importErrorCode = importErrorCode, importStartedAt = importStartedAt, importCompletedAt = importCompletedAt,
)

private fun TagEntity.toDto() = TagDto(
    id, name, colorHex, createdAt, updatedAt, lastUsedAt, sortOrder, parentId, deletedAt,
    version, version, updatedAt, lastModifiedByDeviceId,
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
        version = version ?: 1, lastModifiedByDeviceId = lastModifiedByDeviceId, sourceUrl = sourceURL,
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
    id, userId, name, colorHex, createdAt, updatedAt ?: createdAt, lastUsedAt ?: createdAt,
    parentId, sortOrder, deletedAt, version ?: 1, lastModifiedByDeviceId, needsSync = false,
)

private fun TagDto.toRemoteChange(userId: String) = RemoteTagChange(
    tag = toEntity(userId),
    remoteVersion = version,
    remoteUpdatedAt = updatedAt ?: createdAt,
)
