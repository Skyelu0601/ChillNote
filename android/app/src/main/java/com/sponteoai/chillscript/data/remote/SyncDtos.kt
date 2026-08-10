package com.sponteoai.chillscript.data.remote

import kotlinx.serialization.Serializable

@Serializable
data class NoteDto(
    val id: String,
    val content: String,
    val createdAt: String,
    val updatedAt: String? = null,
    val deletedAt: String? = null,
    val pinnedAt: String? = null,
    val tagIds: List<String>? = null,
    val version: Int? = null,
    val baseVersion: Int? = null,
    val clientUpdatedAt: String? = null,
    val lastModifiedByDeviceId: String? = null,
    val sourceURL: String? = null,
    val sourceTitle: String? = null,
    val sourcePlatformID: String? = null,
    val sourcePlatformName: String? = null,
    val sourceHost: String? = null,
    val sourceCapturedAt: String? = null,
    val section: String? = null,
    val importStatus: String? = null,
    val importJobId: String? = null,
    val importErrorCode: String? = null,
    val importStartedAt: String? = null,
    val importCompletedAt: String? = null,
)

@Serializable
data class TagDto(
    val id: String,
    val name: String,
    val colorHex: String,
    val createdAt: String,
    val updatedAt: String? = null,
    val lastUsedAt: String? = null,
    val sortOrder: Int,
    val parentId: String? = null,
    val deletedAt: String? = null,
    val version: Int? = null,
    val baseVersion: Int? = null,
    val clientUpdatedAt: String? = null,
    val lastModifiedByDeviceId: String? = null,
)

@Serializable
data class SyncPayload(
    val cursor: String? = null,
    val deviceId: String? = null,
    val notes: List<NoteDto>,
    val tags: List<TagDto> = emptyList(),
    val hardDeletedNoteIds: List<String>? = null,
    val hardDeletedTagIds: List<String>? = null,
    val preferences: Map<String, String>? = null,
)

@Serializable
data class SyncChanges(
    val notes: List<NoteDto>,
    val tags: List<TagDto> = emptyList(),
    val hardDeletedNoteIds: List<String> = emptyList(),
    val hardDeletedTagIds: List<String> = emptyList(),
    val preferences: Map<String, String>? = null,
)

@Serializable
data class ConflictDto(
    val entityType: String,
    val id: String,
    val serverVersion: Int,
    val serverContent: String? = null,
    val clientContent: String? = null,
    val message: String,
)

@Serializable
data class SyncResponse(
    val cursor: String,
    val changes: SyncChanges,
    val conflicts: List<ConflictDto>,
    val serverTime: String,
)
