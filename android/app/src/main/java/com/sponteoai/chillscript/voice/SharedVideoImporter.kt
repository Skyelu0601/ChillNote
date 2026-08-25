package com.sponteoai.chillscript.voice

import android.content.ContentResolver
import android.content.Context
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.net.Uri
import android.provider.OpenableColumns
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.util.UUID

internal object SharedVideoImportRules {
    const val MAX_SOURCE_BYTES = 100L * 1024L * 1024L
    const val MAX_AUDIO_BYTES = 100L * 1024L * 1024L
    const val MAX_DURATION_MILLIS = 3L * 60L * 60L * 1_000L

    fun normalizedVideoMime(
        declaredMimeType: String?,
        resolverMimeType: String?,
        displayName: String?,
    ): String? {
        val candidates = listOf(declaredMimeType, resolverMimeType)
            .mapNotNull { it?.substringBefore(';')?.trim()?.lowercase()?.takeIf(String::isNotEmpty) }
        candidates.firstOrNull { it.startsWith("video/") && it != "video/*" }?.let { return it }
        if (candidates.any { it == "video/*" }) return "video/mp4"
        return when (displayName?.substringAfterLast('.', "")?.lowercase()) {
            "mp4" -> "video/mp4"
            "mov" -> "video/quicktime"
            "m4v" -> "video/x-m4v"
            "webm" -> "video/webm"
            "3gp", "3gpp" -> "video/3gpp"
            "mkv" -> "video/x-matroska"
            else -> null
        }
    }

    fun validateKnownSize(sizeBytes: Long?) {
        if (sizeBytes == 0L) throw SharedVideoImportException.Empty
        if (sizeBytes != null && sizeBytes > MAX_SOURCE_BYTES) {
            throw SharedVideoImportException.TooLarge
        }
    }

    fun validateDuration(durationMillis: Long) {
        if (durationMillis > MAX_DURATION_MILLIS) throw SharedVideoImportException.TooLong
    }
}

sealed class SharedVideoImportException(message: String) : Exception(message) {
    data object UnsupportedType : SharedVideoImportException("Unsupported shared video type")
    data object Empty : SharedVideoImportException("Shared video was empty")
    data object TooLarge : SharedVideoImportException("Shared video exceeded the size limit")
    data object TooLong : SharedVideoImportException("Shared video exceeded the duration limit")
    data object NoAudioTrack : SharedVideoImportException("Shared video had no audio track")
    data object UnableToRead : SharedVideoImportException("Unable to read shared video")
    data object UnableToExtractAudio : SharedVideoImportException("Unable to extract shared video audio")
}

data class SharedVideoImportSource(
    val uri: Uri,
    val declaredMimeType: String?,
    val sourcePackage: String?,
)

/**
 * Copies a one-shot share URI into private storage, extracts its audio track without
 * decoding/re-encoding, then discards the large video copy. Only the compact audio file
 * enters the crash-recovery queue.
 */
class SharedVideoImporter(
    context: Context,
    private val recordingFileManager: RecordingFileManager = RecordingFileManager(context),
) {
    private val appContext = context.applicationContext
    private val resolver: ContentResolver = appContext.contentResolver
    private val stagingDirectory = File(appContext.cacheDir, "SharedVideoImports")

    suspend fun import(
        source: SharedVideoImportSource,
        ownerUserId: String?,
    ): PendingRecording = withContext(Dispatchers.IO) {
        stagingDirectory.mkdirs()
        cleanupAbandonedStagingFiles()

        val descriptor = queryDescriptor(source.uri)
        val videoMimeType = SharedVideoImportRules.normalizedVideoMime(
            source.declaredMimeType,
            descriptor.mimeType,
            descriptor.displayName,
        ) ?: throw SharedVideoImportException.UnsupportedType
        SharedVideoImportRules.validateKnownSize(descriptor.sizeBytes)

        val token = UUID.randomUUID().toString()
        val stagedVideo = File(stagingDirectory, "$token.video.partial")
        val stagedAudio = File(stagingDirectory, "$token.audio.partial")
        try {
            copyWithLimit(source.uri, stagedVideo)
            val extracted = extractAudioTrack(stagedVideo, stagedAudio)
            if (stagedAudio.length() <= 0L) throw SharedVideoImportException.NoAudioTrack
            if (stagedAudio.length() > SharedVideoImportRules.MAX_AUDIO_BYTES) {
                throw SharedVideoImportException.TooLarge
            }
            recordingFileManager.adoptSharedVideoAudio(
                stagedAudio = stagedAudio,
                durationMillis = extracted.durationMillis,
                originalDisplayName = descriptor.displayName,
                originalVideoMimeType = videoMimeType,
                sourcePackage = source.sourcePackage,
                ownerUserId = ownerUserId,
            )
        } finally {
            stagedVideo.delete()
            stagedAudio.delete()
        }
    }

    private fun queryDescriptor(uri: Uri): SharedVideoDescriptor {
        var displayName: String? = null
        var sizeBytes: Long? = null
        runCatching {
            resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)
                ?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (nameIndex >= 0 && !cursor.isNull(nameIndex)) displayName = cursor.getString(nameIndex)
                        val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                        if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) {
                            cursor.getLong(sizeIndex).takeIf { it >= 0L }?.let { sizeBytes = it }
                        }
                    }
                }
        }
        val mimeType = runCatching { resolver.getType(uri) }.getOrNull()
        return SharedVideoDescriptor(displayName?.take(240), sizeBytes, mimeType)
    }

    private fun copyWithLimit(uri: Uri, destination: File) {
        val input = try {
            resolver.openInputStream(uri)
        } catch (_: Throwable) {
            null
        } ?: throw SharedVideoImportException.UnableToRead

        var copied = 0L
        try {
            input.buffered().use { source ->
                FileOutputStream(destination).buffered().use { output ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    while (true) {
                        val count = source.read(buffer)
                        if (count < 0) break
                        copied += count
                        if (copied > SharedVideoImportRules.MAX_SOURCE_BYTES) {
                            throw SharedVideoImportException.TooLarge
                        }
                        output.write(buffer, 0, count)
                    }
                }
            }
        } catch (known: SharedVideoImportException) {
            throw known
        } catch (_: Throwable) {
            throw SharedVideoImportException.UnableToRead
        }
        if (copied == 0L) throw SharedVideoImportException.Empty
    }

    private fun extractAudioTrack(video: File, destination: File): ExtractedAudio {
        val extractor = MediaExtractor()
        var muxer: MediaMuxer? = null
        var muxerStarted = false
        var wroteSamples = false
        try {
            extractor.setDataSource(video.absolutePath)
            val audioTrackIndex = (0 until extractor.trackCount).firstOrNull { index ->
                extractor.getTrackFormat(index).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
            } ?: throw SharedVideoImportException.NoAudioTrack
            val format = extractor.getTrackFormat(audioTrackIndex)
            val durationMillis = trackDurationMillis(format, video)
            SharedVideoImportRules.validateDuration(durationMillis)

            extractor.selectTrack(audioTrackIndex)
            muxer = MediaMuxer(destination.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            val outputTrack = muxer.addTrack(format)
            muxer.start()
            muxerStarted = true

            val bufferSize = format.getIntegerOrNull(MediaFormat.KEY_MAX_INPUT_SIZE)
                ?.coerceIn(64 * 1024, 4 * 1024 * 1024)
                ?: 512 * 1024
            val buffer = ByteBuffer.allocateDirect(bufferSize)
            val info = MediaCodec.BufferInfo()
            while (true) {
                buffer.clear()
                val sampleSize = extractor.readSampleData(buffer, 0)
                if (sampleSize < 0) break
                val extractorFlags = extractor.sampleFlags
                if ((extractorFlags and MediaExtractor.SAMPLE_FLAG_ENCRYPTED) != 0) {
                    throw SharedVideoImportException.UnableToExtractAudio
                }
                val codecFlags =
                    (if ((extractorFlags and MediaExtractor.SAMPLE_FLAG_SYNC) != 0) {
                        MediaCodec.BUFFER_FLAG_KEY_FRAME
                    } else 0) or
                    (if ((extractorFlags and MediaExtractor.SAMPLE_FLAG_PARTIAL_FRAME) != 0) {
                        MediaCodec.BUFFER_FLAG_PARTIAL_FRAME
                    } else 0)
                info.set(0, sampleSize, extractor.sampleTime.coerceAtLeast(0L), codecFlags)
                muxer.writeSampleData(outputTrack, buffer, info)
                wroteSamples = true
                if (!extractor.advance()) break
            }
            if (!wroteSamples) throw SharedVideoImportException.NoAudioTrack
            muxer.stop()
            muxerStarted = false
            return ExtractedAudio(durationMillis)
        } catch (known: SharedVideoImportException) {
            throw known
        } catch (_: Throwable) {
            throw SharedVideoImportException.UnableToExtractAudio
        } finally {
            if (muxerStarted) runCatching { muxer?.stop() }
            runCatching { muxer?.release() }
            runCatching { extractor.release() }
        }
    }

    private fun trackDurationMillis(format: MediaFormat, video: File): Long {
        val trackDuration = format.getLongOrNull(MediaFormat.KEY_DURATION)?.div(1_000L)
        if (trackDuration != null && trackDuration > 0L) return trackDuration
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(video.absolutePath)
            retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
        } catch (_: Throwable) {
            0L
        } finally {
            runCatching { retriever.release() }
        }
    }

    private fun cleanupAbandonedStagingFiles(nowMillis: Long = System.currentTimeMillis()) {
        val cutoff = nowMillis - STAGING_MAX_AGE_MILLIS
        stagingDirectory.listFiles().orEmpty().forEach { file ->
            if (file.isFile && file.lastModified() < cutoff) file.delete()
        }
    }

    private data class SharedVideoDescriptor(
        val displayName: String?,
        val sizeBytes: Long?,
        val mimeType: String?,
    )

    private data class ExtractedAudio(val durationMillis: Long)

    private companion object {
        const val STAGING_MAX_AGE_MILLIS = 24L * 60L * 60L * 1_000L
    }
}

private fun MediaFormat.getIntegerOrNull(key: String): Int? =
    if (containsKey(key)) runCatching { getInteger(key) }.getOrNull() else null

private fun MediaFormat.getLongOrNull(key: String): Long? =
    if (containsKey(key)) runCatching { getLong(key) }.getOrNull() else null
