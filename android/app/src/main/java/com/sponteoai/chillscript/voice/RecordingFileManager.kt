package com.sponteoai.chillscript.voice

import android.content.Context
import android.media.MediaMetadataRetriever
import java.io.File
import java.time.Duration
import java.time.Instant
import java.util.UUID

data class PendingRecording(
    val file: File,
    val createdAt: Instant,
    val durationMillis: Long,
    val mimeType: String = "audio/mp4",
    val origin: PendingRecordingOrigin = PendingRecordingOrigin.VoiceRecording,
    val originalDisplayName: String? = null,
    val originalVideoMimeType: String? = null,
    val sourcePackage: String? = null,
    val ownerUserId: String? = null,
    val creditAuthorized: Boolean = false,
) {
    val durationText: String
        get() {
            val totalSeconds = (durationMillis / 1_000).coerceAtLeast(0)
            return "%d:%02d".format(totalSeconds / 60, totalSeconds % 60)
    }
}

enum class PendingRecordingOrigin(val persistedValue: String) {
    VoiceRecording("voice_recording"),
    SharedVideo("shared_video");

    companion object {
        fun fromPersistedValue(value: String?): PendingRecordingOrigin =
            entries.firstOrNull { it.persistedValue == value } ?: VoiceRecording
    }
}

/** Result reported back to the pending-recordings row that started the save. */
enum class PendingRecordingSaveOutcome {
    Saved,
    ConsentDeclined,
    Error,
}

class RecordingFileManager(context: Context) {
    private val directory = File(context.filesDir, "PendingRecordings")
    private val noteLinks = context.getSharedPreferences("pending_recording_note_links", Context.MODE_PRIVATE)
    private val mediaMetadata = context.getSharedPreferences("pending_recording_media_metadata", Context.MODE_PRIVATE)

    fun createRecordingFile(): File {
        directory.mkdirs()
        return File(directory, "${UUID.randomUUID()}_${System.currentTimeMillis()}.m4a")
    }

    fun pendingRecordings(now: Instant = Instant.now()): List<PendingRecording> {
        directory.mkdirs()
        val cutoff = now.minus(Duration.ofDays(7))
        directory.listFiles { file -> file.isFile && file.extension.equals("m4a", ignoreCase = true) }
            .orEmpty()
            .forEach { file ->
                if (Instant.ofEpochMilli(file.lastModified()).isBefore(cutoff)) {
                    file.delete()
                    clearMetadata(file)
                }
            }
        return directory.listFiles { file -> file.isFile && file.length() > 0 && file.extension.equals("m4a", ignoreCase = true) }
            .orEmpty()
            .map { file -> pendingRecording(file) }
            .sortedByDescending { it.createdAt }
    }

    fun adoptSharedVideoAudio(
        stagedAudio: File,
        durationMillis: Long,
        originalDisplayName: String?,
        originalVideoMimeType: String,
        sourcePackage: String?,
        ownerUserId: String?,
    ): PendingRecording {
        check(stagedAudio.isFile && stagedAudio.length() > 0L) { "Extracted audio was empty" }
        directory.mkdirs()
        val destination = File(directory, "${UUID.randomUUID()}_${System.currentTimeMillis()}.m4a")
        if (!stagedAudio.renameTo(destination)) {
            stagedAudio.inputStream().buffered().use { input ->
                destination.outputStream().buffered().use { output -> input.copyTo(output) }
            }
            stagedAudio.delete()
        }
        val now = System.currentTimeMillis()
        destination.setLastModified(now)
        mediaMetadata.edit()
            .putString(metadataKey(destination, KEY_ORIGIN), PendingRecordingOrigin.SharedVideo.persistedValue)
            .putString(metadataKey(destination, KEY_MIME_TYPE), "audio/mp4")
            .putString(metadataKey(destination, KEY_ORIGINAL_NAME), originalDisplayName?.take(240))
            .putString(metadataKey(destination, KEY_ORIGINAL_VIDEO_MIME), originalVideoMimeType)
            .putString(metadataKey(destination, KEY_SOURCE_PACKAGE), sourcePackage?.take(240))
            .putString(metadataKey(destination, KEY_OWNER_USER_ID), ownerUserId)
            .putLong(metadataKey(destination, KEY_DURATION_MILLIS), durationMillis.coerceAtLeast(0L))
            .commit()
        return pendingRecording(destination)
    }

    fun setOwnerUserId(file: File, userId: String) {
        mediaMetadata.edit().putString(metadataKey(file, KEY_OWNER_USER_ID), userId).commit()
    }

    fun setCreditAuthorized(file: File, authorized: Boolean) {
        mediaMetadata.edit().putBoolean(metadataKey(file, KEY_CREDIT_AUTHORIZED), authorized).commit()
    }

    fun mimeType(file: File): String =
        mediaMetadata.getString(metadataKey(file, KEY_MIME_TYPE), null) ?: "audio/mp4"

    fun setNoteId(file: File, noteId: String) {
        noteLinks.edit().putString(file.name, noteId).apply()
    }

    fun noteId(file: File): String? = noteLinks.getString(file.name, null)

    fun complete(file: File) {
        file.delete()
        clearMetadata(file)
    }

    fun cancel(file: File) {
        file.delete()
        clearMetadata(file)
    }

    fun clearAll() {
        directory.listFiles().orEmpty().forEach(File::delete)
        noteLinks.edit().clear().apply()
        mediaMetadata.edit().clear().apply()
    }

    private fun pendingRecording(file: File): PendingRecording {
        val persistedDuration = mediaMetadata.getLong(metadataKey(file, KEY_DURATION_MILLIS), -1L)
        return PendingRecording(
            file = file,
            createdAt = Instant.ofEpochMilli(file.lastModified()),
            durationMillis = persistedDuration.takeIf { it >= 0L } ?: durationMillis(file),
            mimeType = mimeType(file),
            origin = PendingRecordingOrigin.fromPersistedValue(
                mediaMetadata.getString(metadataKey(file, KEY_ORIGIN), null),
            ),
            originalDisplayName = mediaMetadata.getString(metadataKey(file, KEY_ORIGINAL_NAME), null),
            originalVideoMimeType = mediaMetadata.getString(metadataKey(file, KEY_ORIGINAL_VIDEO_MIME), null),
            sourcePackage = mediaMetadata.getString(metadataKey(file, KEY_SOURCE_PACKAGE), null),
            ownerUserId = mediaMetadata.getString(metadataKey(file, KEY_OWNER_USER_ID), null),
            creditAuthorized = mediaMetadata.getBoolean(metadataKey(file, KEY_CREDIT_AUTHORIZED), false),
        )
    }

    private fun clearMetadata(file: File) {
        noteLinks.edit().remove(file.name).apply()
        mediaMetadata.edit()
            .remove(metadataKey(file, KEY_ORIGIN))
            .remove(metadataKey(file, KEY_MIME_TYPE))
            .remove(metadataKey(file, KEY_ORIGINAL_NAME))
            .remove(metadataKey(file, KEY_ORIGINAL_VIDEO_MIME))
            .remove(metadataKey(file, KEY_SOURCE_PACKAGE))
            .remove(metadataKey(file, KEY_OWNER_USER_ID))
            .remove(metadataKey(file, KEY_DURATION_MILLIS))
            .remove(metadataKey(file, KEY_CREDIT_AUTHORIZED))
            .apply()
    }

    private fun metadataKey(file: File, field: String) = "${file.name}:$field"

    private fun durationMillis(file: File): Long {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(file.absolutePath)
            retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0
        } catch (_: Throwable) {
            0
        } finally {
            runCatching { retriever.release() }
        }
    }

    private companion object {
        const val KEY_ORIGIN = "origin"
        const val KEY_MIME_TYPE = "mime_type"
        const val KEY_ORIGINAL_NAME = "original_name"
        const val KEY_ORIGINAL_VIDEO_MIME = "original_video_mime"
        const val KEY_SOURCE_PACKAGE = "source_package"
        const val KEY_OWNER_USER_ID = "owner_user_id"
        const val KEY_DURATION_MILLIS = "duration_millis"
        const val KEY_CREDIT_AUTHORIZED = "credit_authorized"
    }
}
