package com.sponteoai.chillscript.data.local

import androidx.room.testing.MigrationTestHelper
import androidx.sqlite.db.framework.FrameworkSQLiteOpenHelperFactory
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ChillScriptDatabaseMigrationTest {
    private val databaseName = "migration-test"

    @get:Rule
    val helper = MigrationTestHelper(
        InstrumentationRegistry.getInstrumentation(),
        ChillScriptDatabase::class.java,
        emptyList(),
        FrameworkSQLiteOpenHelperFactory(),
    )

    @Test
    fun migrateFrom1To4_preservesNotesAndBuildsSearchIndex() {
        helper.createDatabase(databaseName, 1).apply {
            execSQL(
                """
                INSERT INTO notes (
                    id, userId, content, contentFormat, checklistNotes, previewPlainText,
                    createdAt, updatedAt, deletedAt, pinnedAt, version,
                    lastModifiedByDeviceId, sourceUrl, sourceTitle, sourcePlatformId,
                    sourcePlatformName, sourceHost, sourceCapturedAt, section,
                    importStatus, importJobId, importErrorCode, importStartedAt,
                    importCompletedAt, needsSync
                ) VALUES (
                    'note-1', 'user-1', 'A preserved note', 'markdown', '', 'A preserved note',
                    '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL, 1,
                    NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'inbox',
                    NULL, NULL, NULL, NULL, NULL, 0
                )
                """.trimIndent(),
            )
            close()
        }

        val database = helper.runMigrationsAndValidate(
            databaseName,
            4,
            true,
            *ChillScriptDatabase.ALL_MIGRATIONS,
        )

        database.query("SELECT content FROM notes WHERE id = 'note-1'").use { cursor ->
            cursor.moveToFirst()
            assertEquals("A preserved note", cursor.getString(0))
        }
        database.query("SELECT content FROM notes_fts WHERE noteId = 'note-1'").use { cursor ->
            cursor.moveToFirst()
            assertEquals("A preserved note", cursor.getString(0))
        }
        database.query("PRAGMA table_info(checklist_items)").use { cursor ->
            val nameIndex = cursor.getColumnIndexOrThrow("name")
            val columns = buildSet {
                while (cursor.moveToNext()) add(cursor.getString(nameIndex))
            }
            assertEquals(true, "createdAt" in columns)
            assertEquals(true, "updatedAt" in columns)
        }
        database.close()
    }
}
