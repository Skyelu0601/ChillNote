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
) {
    val durationText: String
        get() {
            val totalSeconds = (durationMillis / 1_000).coerceAtLeast(0)
            return "%d:%02d".format(totalSeconds / 60, totalSeconds % 60)
        }
}

class RecordingFileManager(context: Context) {
    private val directory = File(context.filesDir, "PendingRecordings")

    fun createRecordingFile(): File {
        directory.mkdirs()
        return File(directory, "${UUID.randomUUID()}_${System.currentTimeMillis()}.m4a")
    }

    fun pendingRecordings(now: Instant = Instant.now()): List<PendingRecording> {
        directory.mkdirs()
        val cutoff = now.minus(Duration.ofDays(7))
        directory.listFiles { file -> file.isFile && file.extension.equals("m4a", ignoreCase = true) }
            .orEmpty()
            .forEach { file -> if (Instant.ofEpochMilli(file.lastModified()).isBefore(cutoff)) file.delete() }
        return directory.listFiles { file -> file.isFile && file.length() > 0 && file.extension.equals("m4a", ignoreCase = true) }
            .orEmpty()
            .map { file -> PendingRecording(file, Instant.ofEpochMilli(file.lastModified()), durationMillis(file)) }
            .sortedByDescending { it.createdAt }
    }

    fun complete(file: File) { file.delete() }
    fun cancel(file: File) { file.delete() }

    fun clearAll() {
        directory.listFiles().orEmpty().forEach(File::delete)
    }

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
}
