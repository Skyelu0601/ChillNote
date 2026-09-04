package com.sponteoai.chillscript.share

import com.sponteoai.chillscript.data.remote.sourceForUrl
import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class PendingShareImportQueueTest {
    @Test fun savesBeforeNetworkAndOverwritesTheSameTaskId() {
        val directory = Files.createTempDirectory("pending-share-queue").toFile()
        val queue = PendingShareImportQueue(directory)
        val original = item(id = "same-id", createdAt = "2026-08-24T01:00:00Z")

        queue.save(original)
        assertEquals(original, queue.pending().single())

        queue.save(original.copy(importJobId = "job-1", importStatus = "queued"))
        val updated = queue.pending().single()
        assertEquals("same-id", updated.id)
        assertEquals("job-1", updated.importJobId)
        assertEquals(1, directory.listFiles { file -> file.extension == "json" }.orEmpty().size)
    }

    @Test fun returnsOldestFirstAndRemovalIsIdempotent() {
        val directory = Files.createTempDirectory("pending-share-order").toFile()
        val queue = PendingShareImportQueue(directory)
        queue.save(item("later", "2026-08-24T02:00:00Z"))
        queue.save(item("earlier", "2026-08-24T01:00:00Z"))

        assertEquals(listOf("earlier", "later"), queue.pending().map { it.id })
        queue.remove("earlier")
        queue.remove("earlier")
        assertEquals(listOf("later"), queue.pending().map { it.id })
        assertFalse(directory.resolve("earlier.json").exists())
        assertTrue(directory.resolve("later.json").exists())
    }

    @Test fun refusesToTreatAnUnreadableQueueAsEmpty() {
        val directory = Files.createTempDirectory("pending-share-corrupt").toFile()
        directory.resolve("broken.json").writeText("not-json")

        assertThrows(java.io.IOException::class.java) {
            PendingShareImportQueue(directory).pending()
        }
    }

    @Test fun refusesToTreatAFileAsAQueueDirectory() {
        val notDirectory = Files.createTempFile("pending-share", ".tmp").toFile()

        assertThrows(java.io.IOException::class.java) {
            PendingShareImportQueue(notDirectory).save(item("blocked", "2026-08-24T01:00:00Z"))
        }
    }

    private fun item(id: String, createdAt: String) = PendingShareImport(
        id = id,
        url = "https://www.tiktok.com/@creator/video/123",
        source = sourceForUrl("https://www.tiktok.com/@creator/video/123"),
        ownerUserId = "user-1",
        createdAt = createdAt,
    )
}
