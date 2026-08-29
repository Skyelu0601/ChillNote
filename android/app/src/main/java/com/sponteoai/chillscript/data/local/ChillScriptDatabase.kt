package com.sponteoai.chillscript.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

@Database(
    entities = [NoteEntity::class, TagEntity::class, NoteTagCrossRef::class, ChecklistItemEntity::class, SyncStateEntity::class, PendingHardDeleteEntity::class, NoteSearchEntity::class],
    version = 7,
    exportSchema = true,
)
abstract class ChillScriptDatabase : RoomDatabase() {
    abstract fun dao(): ChillScriptDao

    companion object {
        @Volatile private var instance: ChillScriptDatabase? = null

        fun get(context: Context): ChillScriptDatabase = instance ?: synchronized(this) {
            instance ?: Room.databaseBuilder(
                context.applicationContext,
                ChillScriptDatabase::class.java,
                "chillscript.db",
            ).addMigrations(*ALL_MIGRATIONS).build().also { instance = it }
        }

        internal val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL(
                    "CREATE TABLE IF NOT EXISTS `pending_hard_deletes` (`id` TEXT NOT NULL, `userId` TEXT NOT NULL, `entityType` TEXT NOT NULL, `entityId` TEXT NOT NULL, `enqueuedAt` TEXT NOT NULL, PRIMARY KEY(`id`))",
                )
                db.execSQL("CREATE INDEX IF NOT EXISTS `index_pending_hard_deletes_userId` ON `pending_hard_deletes` (`userId`)")
                db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS `index_pending_hard_deletes_entityType_entityId` ON `pending_hard_deletes` (`entityType`, `entityId`)")
            }
        }

        internal val MIGRATION_2_3 = object : Migration(2, 3) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE `checklist_items` ADD COLUMN `createdAt` TEXT NOT NULL DEFAULT ''")
                db.execSQL("ALTER TABLE `checklist_items` ADD COLUMN `updatedAt` TEXT NOT NULL DEFAULT ''")
            }
        }

        internal val MIGRATION_3_4 = object : Migration(3, 4) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("CREATE VIRTUAL TABLE IF NOT EXISTS `notes_fts` USING FTS4(`noteId` TEXT NOT NULL, `userId` TEXT NOT NULL, `content` TEXT NOT NULL, `previewPlainText` TEXT NOT NULL, tokenize=unicode61)")
                db.execSQL("INSERT INTO notes_fts(noteId, userId, content, previewPlainText) SELECT id, userId, content, previewPlainText FROM notes")
                db.execSQL("CREATE TRIGGER IF NOT EXISTS notes_fts_after_insert AFTER INSERT ON notes BEGIN INSERT INTO notes_fts(noteId, userId, content, previewPlainText) VALUES (new.id, new.userId, new.content, new.previewPlainText); END")
                db.execSQL("CREATE TRIGGER IF NOT EXISTS notes_fts_after_update AFTER UPDATE ON notes BEGIN DELETE FROM notes_fts WHERE noteId = old.id; INSERT INTO notes_fts(noteId, userId, content, previewPlainText) VALUES (new.id, new.userId, new.content, new.previewPlainText); END")
                db.execSQL("CREATE TRIGGER IF NOT EXISTS notes_fts_after_delete AFTER DELETE ON notes BEGIN DELETE FROM notes_fts WHERE noteId = old.id; END")
            }
        }

        internal val MIGRATION_4_5 = object : Migration(4, 5) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE `notes` ADD COLUMN `sourceAuthorName` TEXT")
                db.execSQL("ALTER TABLE `notes` ADD COLUMN `sourceAuthorHandle` TEXT")
                db.execSQL("DROP TRIGGER IF EXISTS notes_fts_after_insert")
                db.execSQL("DROP TRIGGER IF EXISTS notes_fts_after_update")
                db.execSQL("DROP TRIGGER IF EXISTS notes_fts_after_delete")
                db.execSQL("DROP TABLE IF EXISTS notes_fts")
                db.execSQL(
                    "CREATE VIRTUAL TABLE `notes_fts` USING FTS4(`noteId` TEXT NOT NULL, `userId` TEXT NOT NULL, `content` TEXT NOT NULL, `previewPlainText` TEXT NOT NULL, `sourceTitle` TEXT NOT NULL, `sourcePlatformName` TEXT NOT NULL, `sourceHost` TEXT NOT NULL, `sourceAuthorName` TEXT NOT NULL, `sourceAuthorHandle` TEXT NOT NULL, tokenize=unicode61)",
                )
                db.execSQL(
                    "INSERT INTO notes_fts(noteId, userId, content, previewPlainText, sourceTitle, sourcePlatformName, sourceHost, sourceAuthorName, sourceAuthorHandle) SELECT id, userId, content, previewPlainText, COALESCE(sourceTitle, ''), COALESCE(sourcePlatformName, ''), COALESCE(sourceHost, ''), COALESCE(sourceAuthorName, ''), COALESCE(sourceAuthorHandle, '') FROM notes",
                )
                db.execSQL("CREATE TRIGGER notes_fts_after_insert AFTER INSERT ON notes BEGIN INSERT INTO notes_fts(noteId, userId, content, previewPlainText, sourceTitle, sourcePlatformName, sourceHost, sourceAuthorName, sourceAuthorHandle) VALUES (new.id, new.userId, new.content, new.previewPlainText, COALESCE(new.sourceTitle, ''), COALESCE(new.sourcePlatformName, ''), COALESCE(new.sourceHost, ''), COALESCE(new.sourceAuthorName, ''), COALESCE(new.sourceAuthorHandle, '')); END")
                db.execSQL("CREATE TRIGGER notes_fts_after_update AFTER UPDATE ON notes BEGIN DELETE FROM notes_fts WHERE noteId = old.id; INSERT INTO notes_fts(noteId, userId, content, previewPlainText, sourceTitle, sourcePlatformName, sourceHost, sourceAuthorName, sourceAuthorHandle) VALUES (new.id, new.userId, new.content, new.previewPlainText, COALESCE(new.sourceTitle, ''), COALESCE(new.sourcePlatformName, ''), COALESCE(new.sourceHost, ''), COALESCE(new.sourceAuthorName, ''), COALESCE(new.sourceAuthorHandle, '')); END")
                db.execSQL("CREATE TRIGGER notes_fts_after_delete AFTER DELETE ON notes BEGIN DELETE FROM notes_fts WHERE noteId = old.id; END")
            }
        }

        internal val MIGRATION_5_6 = object : Migration(5, 6) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE `notes` ADD COLUMN `serverVersion` INTEGER")
                db.execSQL("ALTER TABLE `tags` ADD COLUMN `serverVersion` INTEGER")

                // v5 used `version` for local revisions as well as server comparisons,
                // so even a clean row can contain a value that never existed on the
                // server. Leave every serverVersion unknown and discard cursors so the
                // next sync bootstraps an authoritative server baseline for clean rows.
                db.execSQL("DELETE FROM `sync_state`")
            }
        }

        internal val MIGRATION_6_7 = object : Migration(6, 7) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE `notes` ADD COLUMN `serverMutationId` TEXT")
                db.execSQL("ALTER TABLE `notes` ADD COLUMN `lastSubmittedMutationId` TEXT")
                db.execSQL("ALTER TABLE `notes` ADD COLUMN `lastSubmittedFingerprint` TEXT")
                db.execSQL("ALTER TABLE `tags` ADD COLUMN `serverMutationId` TEXT")
                db.execSQL("ALTER TABLE `tags` ADD COLUMN `lastSubmittedMutationId` TEXT")
                db.execSQL("ALTER TABLE `tags` ADD COLUMN `lastSubmittedFingerprint` TEXT")
            }
        }

        internal val ALL_MIGRATIONS = arrayOf(
            MIGRATION_1_2,
            MIGRATION_2_3,
            MIGRATION_3_4,
            MIGRATION_4_5,
            MIGRATION_5_6,
            MIGRATION_6_7,
        )
    }
}
