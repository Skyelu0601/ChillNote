package com.sponteoai.chillscript.data

import com.sponteoai.chillscript.data.local.ChillScriptDao
import com.sponteoai.chillscript.data.local.NoteEntity
import com.sponteoai.chillscript.data.local.SyncStateEntity
import com.sponteoai.chillscript.data.local.TagEntity
import com.sponteoai.chillscript.data.local.ChecklistItemEntity
import com.sponteoai.chillscript.data.remote.NoteDto
import com.sponteoai.chillscript.data.remote.SyncClient
import com.sponteoai.chillscript.data.remote.LinkImportApi
import com.sponteoai.chillscript.data.remote.LinkImportRequest
import com.sponteoai.chillscript.data.remote.MediaLinkSectionsDto
import com.sponteoai.chillscript.data.remote.sourceForUrl
import com.sponteoai.chillscript.data.remote.SyncPayload
import com.sponteoai.chillscript.data.remote.TagDto
import kotlinx.coroutines.flow.Flow
import java.time.Instant
import java.util.UUID
import com.sponteoai.chillscript.domain.ChecklistMarkdown
import com.sponteoai.chillscript.domain.TagColors
import com.sponteoai.chillscript.domain.TagHierarchy
import com.sponteoai.chillscript.domain.BatchNoteRules
import com.sponteoai.chillscript.domain.TrashPolicy
import com.sponteoai.chillscript.domain.SearchQueryBuilder

class NotesRepository(
    private val dao: ChillScriptDao,
    private val syncApi: SyncClient,
    private val linkImportApi: LinkImportApi = LinkImportApi(),
) {
    fun observeNotes(userId: String): Flow<List<NoteEntity>> = dao.observeNotes(userId)
    fun searchNotes(userId: String, rawQuery: String): Flow<List<NoteEntity>> {
        val query = SearchQueryBuilder.build(rawQuery)
        return dao.searchNotes(userId, query.match, query.like)
    }
    fun observeTags(userId: String): Flow<List<TagEntity>> = dao.observeTags(userId)
    fun observeNoteTags() = dao.observeNoteTags()
    fun observeChecklistItems(noteId: String) = dao.observeChecklistItems(noteId)

    suspend fun clearLocalUserData(userId: String) = dao.clearLocalUserData(userId)

    suspend fun createNote(userId: String, content: String, section: String = "inbox"): NoteEntity {
        val now = Instant.now().toString()
        val parsed = ChecklistMarkdown.parse(content)
        return NoteEntity(
            id = UUID.randomUUID().toString(),
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

    suspend fun updateNoteContent(userId: String, noteId: String, content: String): NoteEntity? {
        val note = dao.note(userId, noteId) ?: return null
        return updateNote(note, content)
    }

    suspend fun moveToTrash(note: NoteEntity) {
        val now = Instant.now().toString()
        dao.upsertNote(note.copy(deletedAt = now, updatedAt = now, version = note.version + 1, needsSync = true))
    }

    suspend fun restore(note: NoteEntity) {
        val now = Instant.now().toString()
        dao.tagsForNote(note.id).filter { it.deletedAt != null }.forEach { tag ->
            dao.upsertTag(tag.copy(deletedAt = null, updatedAt = now, version = tag.version + 1, needsSync = true))
        }
        dao.upsertNote(note.copy(deletedAt = null, updatedAt = now, version = note.version + 1, needsSync = true))
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

    suspend fun setNoteTags(note: NoteEntity, tagIds: List<String>) {
        dao.replaceNoteTags(note.id, tagIds.distinct())
        dao.upsertNote(note.copy(updatedAt = Instant.now().toString(), version = note.version + 1, needsSync = true))
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
        mediaLinkSections: MediaLinkSectionsDto = MediaLinkSectionsDto(),
    ): NoteEntity {
        val source = sourceForUrl(url)
        val note = createNote(userId, placeholder, section).copy(
            sourceUrl = source.url,
            sourceTitle = source.title,
            sourcePlatformId = source.platformID,
            sourcePlatformName = source.platformName,
            sourceHost = source.host,
            sourceCapturedAt = Instant.now().toString(),
            importStatus = "queued",
        )
        dao.upsertNote(note)
        return try {
            val job = linkImportApi.enqueue(
                accessToken,
                LinkImportRequest(note.id, url, placeholder, source, section, mediaLinkSections),
            )
            note.copy(importJobId = job.jobId, importStatus = job.status, needsSync = false)
                .also { dao.upsertNote(it) }
        } catch (error: Throwable) {
            note.copy(importStatus = "failed", importErrorCode = error.message, needsSync = true)
                .also { dao.upsertNote(it) }
            throw error
        }
    }

    suspend fun sync(userId: String, accessToken: String) {
        val state = dao.syncState(userId) ?: SyncStateEntity(userId, deviceId = UUID.randomUUID().toString())
        val localNotes = dao.pendingNotes(userId)
        val localTags = dao.pendingTags(userId)
        val hardDeletedNoteIds = dao.pendingHardDeletes(userId, "note").map { it.entityId }
        val hardDeletedTagIds = dao.pendingHardDeletes(userId, "tag").map { it.entityId }
        val response = syncApi.sync(
            accessToken,
            SyncPayload(
                cursor = state.cursor,
                deviceId = state.deviceId,
                notes = localNotes.map { it.toDto(dao.tagIdsForNote(it.id)) },
                tags = localTags.map(TagEntity::toDto),
                hardDeletedNoteIds = hardDeletedNoteIds.ifEmpty { null },
                hardDeletedTagIds = hardDeletedTagIds.ifEmpty { null },
            ),
        )
        dao.applyRemoteChanges(
            notes = response.changes.notes.map { it.toEntity(userId) },
            tags = response.changes.tags.map { it.toEntity(userId) },
            hardDeletedNoteIds = response.changes.hardDeletedNoteIds,
            hardDeletedTagIds = response.changes.hardDeletedTagIds,
            syncState = state.copy(cursor = response.cursor, lastSyncedAt = response.serverTime),
        )
        response.changes.notes.forEach { dto ->
            val note = dto.toEntity(userId)
            syncChecklistStructure(note, ChecklistMarkdown.parse(note.content))
        }
        response.changes.notes.forEach { dao.replaceNoteTags(it.id, it.tagIds.orEmpty()) }
        if (localNotes.isNotEmpty()) dao.markNotesSynced(localNotes.map { it.id })
        if (localTags.isNotEmpty()) dao.markTagsSynced(localTags.map { it.id })
        if (hardDeletedNoteIds.isNotEmpty()) dao.dequeueHardDeletes(userId, "note", hardDeletedNoteIds)
        if (hardDeletedTagIds.isNotEmpty()) dao.dequeueHardDeletes(userId, "tag", hardDeletedTagIds)
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
}

private fun String.toPreviewText(): String =
    replace(Regex("!\\[[^]]*]\\([^)]+\\)"), "")
        .replace(Regex("(?m)^#{1,6}\\s+"), "")
        .replace("**", "")
        .replace("`", "")
        .replace(Regex("(?m)^\\s*[-*]\\s*\\[ ]\\s*"), "○ ")
        .replace(Regex("(?mi)^\\s*[-*]\\s*\\[x]\\s*"), "◉ ")
        .take(360)

private fun NoteEntity.toDto(tagIds: List<String>) = NoteDto(
    id, content, createdAt, updatedAt, deletedAt, pinnedAt, tagIds = tagIds, version = version,
    baseVersion = version, clientUpdatedAt = updatedAt, lastModifiedByDeviceId = lastModifiedByDeviceId,
    sourceURL = sourceUrl, sourceTitle = sourceTitle, sourcePlatformID = sourcePlatformId,
    sourcePlatformName = sourcePlatformName, sourceHost = sourceHost, sourceCapturedAt = sourceCapturedAt,
    section = section, importStatus = importStatus, importJobId = importJobId,
    importErrorCode = importErrorCode, importStartedAt = importStartedAt, importCompletedAt = importCompletedAt,
)

private fun TagEntity.toDto() = TagDto(
    id, name, colorHex, createdAt, updatedAt, lastUsedAt, sortOrder, parentId, deletedAt,
    version, version, updatedAt, lastModifiedByDeviceId,
)

private fun NoteDto.toEntity(userId: String): NoteEntity {
    val parsed = ChecklistMarkdown.parse(content)
    return NoteEntity(
        id = id, userId = userId, content = content,
        contentFormat = if (parsed == null) "text" else "checklist",
        checklistNotes = parsed?.notes.orEmpty(),
        previewPlainText = content.toPreviewText(),
        createdAt = createdAt, updatedAt = updatedAt ?: createdAt, deletedAt = deletedAt, pinnedAt = pinnedAt,
        version = version ?: 1, lastModifiedByDeviceId = lastModifiedByDeviceId, sourceUrl = sourceURL,
        sourceTitle = sourceTitle, sourcePlatformId = sourcePlatformID, sourcePlatformName = sourcePlatformName,
        sourceHost = sourceHost, sourceCapturedAt = sourceCapturedAt, section = section ?: "inbox",
        importStatus = importStatus, importJobId = importJobId, importErrorCode = importErrorCode,
        importStartedAt = importStartedAt, importCompletedAt = importCompletedAt, needsSync = false,
    )
}

private fun TagDto.toEntity(userId: String) = TagEntity(
    id, userId, name, colorHex, createdAt, updatedAt ?: createdAt, lastUsedAt ?: createdAt,
    parentId, sortOrder, deletedAt, version ?: 1, lastModifiedByDeviceId, needsSync = false,
)
