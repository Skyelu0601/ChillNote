package com.sponteoai.chillscript.export

import com.sponteoai.chillscript.data.local.NoteEntity
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.fail
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.util.zip.ZipFile

class NotesExporterTest {
    @get:Rule val temporaryFolder = TemporaryFolder()

    @Test fun filenameRemovesUnsafeCharactersAndKeepsStableSuffix() {
        val note = NoteEntity(
            id = "abcdef123", userId = "u", content = "My / bad:* title?\nBody",
            createdAt = "now", updatedAt = "now",
        )
        val name = NotesExporter.safeBaseName(note)
        assertFalse(name.contains('/'))
        assertFalse(name.contains('*'))
        assertTrue(name.endsWith("-abcdef"))
    }

    @Test fun exportAllCreatesCompleteArchiveAndReportsProgress() = runBlocking {
        val notes = listOf(note("first-note", "# First\nBody"), note("second-note", "# Second\nBody"))
        val progress = mutableListOf<NotesExportProgress>()

        val archive = NotesExporter.exportAllToDirectory(temporaryFolder.root, notes) { progress += it }

        assertTrue(archive.isFile)
        ZipFile(archive).use { zip ->
            val names = zip.entries().asSequence().map { it.name }.toSet()
            assertTrue(names.any { it.startsWith("markdown/") && it.endsWith("-first-.md") })
            assertTrue(names.any { it.startsWith("markdown/") && it.endsWith("-second.md") })
            assertTrue("notes.json" in names)
            assertTrue("notes.txt" in names)
        }
        assertEquals(NotesExportStage.PREPARING, progress.first().stage)
        assertEquals(NotesExportStage.PACKAGING, progress.last().stage)
        assertEquals(notes.size, progress.last().processed)
    }

    @Test fun cancelledExportDeletesPartialArchive() = runBlocking {
        val notes = listOf(note("first-note", "First"), note("second-note", "Second"))

        try {
            NotesExporter.exportAllToDirectory(temporaryFolder.root, notes) {
                if (it.stage == NotesExportStage.WRITING) throw CancellationException("test cancellation")
            }
            fail("Expected export cancellation")
        } catch (_: CancellationException) {
            // Expected.
        }

        assertFalse(temporaryFolder.root.listFiles().orEmpty().any { it.extension == "zip" })
    }

    private fun note(id: String, content: String) = NoteEntity(
        id = id,
        userId = "u",
        content = content,
        createdAt = "2026-07-13T00:00:00Z",
        updatedAt = "2026-07-13T00:00:00Z",
    )
}
