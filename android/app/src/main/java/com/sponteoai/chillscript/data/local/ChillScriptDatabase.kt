package com.sponteoai.chillscript.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

@Database(
    entities = [NoteEntity::class, TagEntity::class, NoteTagCrossRef::class, ChecklistItemEntity::class, SyncStateEntity::class, PendingHardDeleteEntity::class, NoteSearchEntity::class],
    version = 4,
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

        internal val ALL_MIGRATIONS = arrayOf(MIGRATION_1_2, MIGRATION_2_3, MIGRATION_3_4)
    }
}
