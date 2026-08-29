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
    fun migrateFrom1To7_preservesNotesAndBuildsSearchIndex() {
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
            7,
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
            assertEquals(true, "serverVersion" in columns)
            assertEquals(true, "serverMutationId" in columns)
            assertEquals(true, "lastSubmittedMutationId" in columns)
            assertEquals(true, "lastSubmittedFingerprint" in columns)
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
    fun migrateFrom5To6_invalidatesUntrustworthyServerVersionsAndCursors() {
        val sourceDatabaseName = "migration-test-server-version"
        helper.createDatabase(sourceDatabaseName, 5).apply {
            execSQL(
                """
                INSERT INTO notes (
                    id, userId, content, contentFormat, checklistNotes, previewPlainText,
                    createdAt, updatedAt, version, section, needsSync
                ) VALUES
                    ('clean-note', 'user-1', 'Clean', 'text', '', 'Clean',
                     '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', 7, 'inbox', 0),
                    ('dirty-note', 'user-1', 'Dirty', 'text', '', 'Dirty',
                     '2026-01-01T00:00:00Z', '2026-01-01T01:00:00Z', 11, 'inbox', 1)
                """.trimIndent(),
            )
            execSQL(
                """
                INSERT INTO tags (
                    id, userId, name, colorHex, createdAt, updatedAt, lastUsedAt,
                    sortOrder, version, needsSync
                ) VALUES
                    ('clean-tag', 'user-1', 'Clean', '#5EAFA5',
                     '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z',
                     '2026-01-01T00:00:00Z', 0, 5, 0),
                    ('dirty-tag', 'user-1', 'Dirty', '#8B5CF6',
                     '2026-01-01T00:00:00Z', '2026-01-01T01:00:00Z',
                     '2026-01-01T01:00:00Z', 1, 9, 1)
                """.trimIndent(),
            )
            execSQL(
                """
                INSERT INTO sync_state (userId, cursor, deviceId, lastSyncedAt)
                VALUES ('user-1', 'stale-cursor', 'device-1', '2026-01-01T02:00:00Z')
                """.trimIndent(),
            )
            close()
        }

        val database = helper.runMigrationsAndValidate(
            sourceDatabaseName,
            6,
            true,
            ChillScriptDatabase.MIGRATION_5_6,
        )

        database.query("SELECT id, version, serverVersion FROM notes ORDER BY id").use { cursor ->
            cursor.moveToFirst()
            assertEquals("clean-note", cursor.getString(0))
            assertEquals(7, cursor.getInt(1))
            assertEquals(true, cursor.isNull(2))
            cursor.moveToNext()
            assertEquals("dirty-note", cursor.getString(0))
            assertEquals(11, cursor.getInt(1))
            assertEquals(true, cursor.isNull(2))
        }
        database.query("SELECT id, version, serverVersion FROM tags ORDER BY id").use { cursor ->
            cursor.moveToFirst()
            assertEquals("clean-tag", cursor.getString(0))
            assertEquals(5, cursor.getInt(1))
            assertEquals(true, cursor.isNull(2))
            cursor.moveToNext()
            assertEquals("dirty-tag", cursor.getString(0))
            assertEquals(9, cursor.getInt(1))
            assertEquals(true, cursor.isNull(2))
        }
        database.query("SELECT COUNT(*) FROM sync_state").use { cursor ->
            cursor.moveToFirst()
            assertEquals(0, cursor.getInt(0))
        }
        database.close()
    }

    @Test
    fun migrateFrom6To7_addsDurableMutationMetadataWithoutChangingRows() {
        val sourceDatabaseName = "migration-test-durable-mutation"
        helper.createDatabase(sourceDatabaseName, 6).apply {
            execSQL(
                """
                INSERT INTO notes (
                    id, userId, content, contentFormat, checklistNotes, previewPlainText,
                    createdAt, updatedAt, version, serverVersion, section, needsSync
                ) VALUES (
                    'note-1', 'user-1', 'Dirty body', 'text', '', 'Dirty body',
                    '2026-01-01T00:00:00Z', '2026-01-01T01:00:00Z', 8, 3, 'drafts', 1
                )
                """.trimIndent(),
            )
            execSQL(
                """
                INSERT INTO tags (
                    id, userId, name, colorHex, createdAt, updatedAt, lastUsedAt,
                    sortOrder, version, serverVersion, needsSync
                ) VALUES (
                    'tag-1', 'user-1', 'Ideas', '#5EAFA5',
                    '2026-01-01T00:00:00Z', '2026-01-01T01:00:00Z',
                    '2026-01-01T01:00:00Z', 0, 6, 2, 1
                )
                """.trimIndent(),
            )
            close()
        }

        val database = helper.runMigrationsAndValidate(
            sourceDatabaseName,
            7,
            true,
            ChillScriptDatabase.MIGRATION_6_7,
        )

        database.query(
            "SELECT content, version, serverVersion, serverMutationId, lastSubmittedMutationId, lastSubmittedFingerprint FROM notes WHERE id = 'note-1'",
        ).use { cursor ->
            cursor.moveToFirst()
            assertEquals("Dirty body", cursor.getString(0))
            assertEquals(8, cursor.getInt(1))
            assertEquals(3, cursor.getInt(2))
            assertEquals(true, cursor.isNull(3))
            assertEquals(true, cursor.isNull(4))
            assertEquals(true, cursor.isNull(5))
        }
        database.query(
            "SELECT name, version, serverVersion, serverMutationId, lastSubmittedMutationId, lastSubmittedFingerprint FROM tags WHERE id = 'tag-1'",
        ).use { cursor ->
            cursor.moveToFirst()
            assertEquals("Ideas", cursor.getString(0))
            assertEquals(6, cursor.getInt(1))
            assertEquals(2, cursor.getInt(2))
            assertEquals(true, cursor.isNull(3))
            assertEquals(true, cursor.isNull(4))
            assertEquals(true, cursor.isNull(5))
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
