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
    fun migrateFrom1To5_preservesNotesAndBuildsSearchIndex() {
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
            5,
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
        database.query("PRAGMA table_info(notes)").use { cursor ->
            val nameIndex = cursor.getColumnIndexOrThrow("name")
            val columns = buildSet {
                while (cursor.moveToNext()) add(cursor.getString(nameIndex))
            }
            assertEquals(true, "sourceAuthorName" in columns)
            assertEquals(true, "sourceAuthorHandle" in columns)
        }
        database.query("PRAGMA table_info(notes_fts)").use { cursor ->
            val nameIndex = cursor.getColumnIndexOrThrow("name")
            val columns = buildSet {
                while (cursor.moveToNext()) add(cursor.getString(nameIndex))
            }
            assertEquals(true, "sourceAuthorName" in columns)
            assertEquals(true, "sourceAuthorHandle" in columns)
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

    @Test
    fun migrateFrom4To5_indexesSourceAuthorMetadata() {
        val sourceDatabaseName = "migration-test-source-author"
        helper.createDatabase(sourceDatabaseName, 4).apply {
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
                    'source-note', 'user-1', 'Imported transcript', 'markdown', '', 'Imported transcript',
                    '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', NULL, NULL, 1,
                    NULL, 'https://example.com/video', 'Video title', 'web',
                    'Web', 'example.com', NULL, 'inbox',
                    'completed', 'job-1', NULL, NULL, NULL, 0
                )
                """.trimIndent(),
            )
            close()
        }

        val database = helper.runMigrationsAndValidate(
            sourceDatabaseName,
            5,
            true,
            ChillScriptDatabase.MIGRATION_4_5,
        )
        database.execSQL(
            "UPDATE notes SET sourceAuthorName = 'Creator Name', sourceAuthorHandle = '@creator' WHERE id = 'source-note'",
        )

        database.query("SELECT noteId FROM notes_fts WHERE notes_fts MATCH 'Creator'").use { cursor ->
            cursor.moveToFirst()
            assertEquals("source-note", cursor.getString(0))
        }
        database.close()
    }
}
