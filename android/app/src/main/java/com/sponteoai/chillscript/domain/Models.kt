package com.sponteoai.chillscript.domain

enum class NoteSection(val wireValue: String) { Inbox("inbox"), Drafts("drafts"), Published("published") }
enum class NoteImportStatus { None, Queued, Processing, Completed, Failed }

data class Note(
    val id: String,
    val content: String,
    val previewPlainText: String,
    val section: NoteSection,
    val updatedAt: String,
    val deletedAt: String?,
    val pinnedAt: String?,
    val tagIds: Set<String>,
    val sourceUrl: String?,
    val sourceTitle: String?,
    val sourcePlatformName: String?,
    val importStatus: NoteImportStatus,
)

data class Tag(
    val id: String,
    val name: String,
    val colorHex: String,
    val parentId: String?,
    val sortOrder: Int,
)
