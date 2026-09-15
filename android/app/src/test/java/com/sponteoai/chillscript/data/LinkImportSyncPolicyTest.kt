package com.sponteoai.chillscript.data

import com.sponteoai.chillscript.data.local.NoteEntity
import com.sponteoai.chillscript.data.local.isSamePendingImport
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LinkImportSyncPolicyTest {
    private val local = NoteEntity(
        id = "note-1", userId = "user-1", content = "placeholder",
        createdAt = "2026-09-12T00:00:00Z", updatedAt = "2026-09-12T00:00:00Z",
        sourceUrl = "https://www.tiktok.com/@creator/video/123",
        importStatus = "queued", importJobId = "job-1",
    )

    @Test
    fun sameJobProgressAndServerTimestampsAreNotUserEdits() {
        assertTrue(isSamePendingImport(local, local.copy(
            importStatus = "processing", updatedAt = "2026-09-12T01:00:00Z", serverVersion = 3,
        )))
        assertTrue(isSamePendingImport(local.copy(importJobId = null), local))
    }

    @Test
    fun differentJobsAndRealEditsRemainConflicts() {
        listOf(
            local.copy(importJobId = "job-2"), local.copy(content = "My idea"),
            local.copy(section = "drafts"), local.copy(sourceUrl = "https://example.com"),
            local.copy(deletedAt = local.createdAt), local.copy(pinnedAt = local.createdAt),
            local.copy(importStatus = "completed"),
        ).forEach { remote -> assertFalse(isSamePendingImport(local, remote)) }
        assertFalse(isSamePendingImport(local, local.copy(importJobId = null)))
    }
}
