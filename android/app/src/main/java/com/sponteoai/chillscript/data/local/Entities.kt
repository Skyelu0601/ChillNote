package com.sponteoai.chillscript.data.local

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.Fts4
import androidx.room.FtsOptions

@Entity(tableName = "notes", indices = [Index("userId"), Index("updatedAt"), Index("deletedAt")])
data class NoteEntity(
    @androidx.room.PrimaryKey val id: String,
    val userId: String,
    val content: String,
    val contentFormat: String = "text",
    val checklistNotes: String = "",
    val previewPlainText: String = "",
    val createdAt: String,
    val updatedAt: String,
    val deletedAt: String? = null,
    val pinnedAt: String? = null,
    val version: Int = 1,
    /** Last server revision acknowledged for this row. `version` remains the local revision. */
    val serverVersion: Int? = null,
    /** Authoritative mutation currently stored by the server. */
    val serverMutationId: String? = null,
    /** Durable mutation most recently prepared for upload by this client. */
    val lastSubmittedMutationId: String? = null,
    /** Fingerprint paired with [lastSubmittedMutationId] for idempotent retries. */
    val lastSubmittedFingerprint: String? = null,
    val lastModifiedByDeviceId: String? = null,
    val sourceUrl: String? = null,
    val sourceTitle: String? = null,
    val sourcePlatformId: String? = null,
    val sourcePlatformName: String? = null,
    val sourceHost: String? = null,
    val sourceAuthorName: String? = null,
    val sourceAuthorHandle: String? = null,
    val sourceCapturedAt: String? = null,
    val section: String = "inbox",
    val importStatus: String? = null,
    val importJobId: String? = null,
    val importErrorCode: String? = null,
    val importStartedAt: String? = null,
    val importCompletedAt: String? = null,
    val needsSync: Boolean = true,
)

@Entity(tableName = "tags", indices = [Index("userId"), Index("parentId")])
data class TagEntity(
    @androidx.room.PrimaryKey val id: String,
    val userId: String,
    val name: String,
    val colorHex: String,
    val createdAt: String,
    val updatedAt: String,
    val lastUsedAt: String,
    val parentId: String? = null,
    val sortOrder: Int = 0,
    val deletedAt: String? = null,
    val version: Int = 1,
    /** Last server revision acknowledged for this row. `version` remains the local revision. */
    val serverVersion: Int? = null,
    val serverMutationId: String? = null,
    val lastSubmittedMutationId: String? = null,
    val lastSubmittedFingerprint: String? = null,
    val lastModifiedByDeviceId: String? = null,
    val aiSummary: String? = null,
    val needsSync: Boolean = true,
)

@Entity(
    tableName = "note_tags",
    primaryKeys = ["noteId", "tagId"],
    foreignKeys = [
        ForeignKey(entity = NoteEntity::class, parentColumns = ["id"], childColumns = ["noteId"], onDelete = ForeignKey.CASCADE),
        ForeignKey(entity = TagEntity::class, parentColumns = ["id"], childColumns = ["tagId"], onDelete = ForeignKey.CASCADE),
    ],
    indices = [Index("noteId"), Index("tagId")],
)
data class NoteTagCrossRef(val noteId: String, val tagId: String)

@Entity(
    tableName = "checklist_items",
    foreignKeys = [ForeignKey(entity = NoteEntity::class, parentColumns = ["id"], childColumns = ["noteId"], onDelete = ForeignKey.CASCADE)],
    indices = [Index("noteId")],
)
data class ChecklistItemEntity(
    @androidx.room.PrimaryKey val id: String,
    val noteId: String,
    val text: String,
    val isDone: Boolean,
    val sortOrder: Int,
    val createdAt: String,
    val updatedAt: String,
)

@Entity(tableName = "sync_state")
data class SyncStateEntity(
    @androidx.room.PrimaryKey val userId: String,
    val cursor: String? = null,
    val deviceId: String,
    val lastSyncedAt: String? = null,
)

@Entity(tableName = "pending_hard_deletes", indices = [Index("userId"), Index(value = ["entityType", "entityId"], unique = true)])
data class PendingHardDeleteEntity(
    @androidx.room.PrimaryKey val id: String,
    val userId: String,
    val entityType: String,
    val entityId: String,
    val enqueuedAt: String,
)

@Fts4(tokenizer = FtsOptions.TOKENIZER_UNICODE61)
@Entity(tableName = "notes_fts")
data class NoteSearchEntity(
    val noteId: String,
    val userId: String,
    val content: String,
    val previewPlainText: String,
    val sourceTitle: String,
    val sourcePlatformName: String,
    val sourceHost: String,
    val sourceAuthorName: String,
    val sourceAuthorHandle: String,
)
