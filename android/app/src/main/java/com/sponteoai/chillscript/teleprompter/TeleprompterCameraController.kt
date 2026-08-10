package com.sponteoai.chillscript.teleprompter

import android.Manifest
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Build
import android.provider.MediaStore
import androidx.camera.core.CameraSelector
import androidx.camera.core.MirrorMode
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.FallbackStrategy
import androidx.camera.video.FileOutputOptions
import androidx.camera.video.Quality
import androidx.camera.video.QualitySelector
import androidx.camera.video.Recorder
import androidx.camera.video.Recording
import androidx.camera.video.VideoCapture
import androidx.camera.video.VideoRecordEvent
import androidx.camera.view.PreviewView
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.lifecycle.LifecycleOwner
import com.sponteoai.chillscript.R
import java.io.File
import java.nio.ByteBuffer
import java.util.UUID
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

data class TeleprompterClip(val id: String, val file: File, val durationMillis: Long)

class TeleprompterCameraController(
    private val context: Context,
    private val lifecycleOwner: LifecycleOwner,
) {
    val clips = mutableStateListOf<TeleprompterClip>()
    var isRecording by mutableStateOf(false)
        private set
    var recordedMillis by mutableLongStateOf(0L)
        private set
    var isFrontCamera by mutableStateOf(true)
        private set
    var quality by mutableStateOf(Quality.FHD)
        private set
    var errorMessage by mutableStateOf<String?>(null)
    var exporting by mutableStateOf(false)
        private set
    var exportedFile by mutableStateOf<File?>(null)
        private set

    private var provider: ProcessCameraProvider? = null
    private var previewView: PreviewView? = null
    private var videoCapture: VideoCapture<Recorder>? = null
    private var activeRecording: Recording? = null

    fun attach(view: PreviewView) {
        previewView = view
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) bind()
    }

    fun onPermissionsGranted() = bind()

    fun switchCamera() {
        if (isRecording) return
        isFrontCamera = !isFrontCamera
        bind()
    }

    fun updateQuality(next: Quality) {
        if (isRecording || next == quality) return
        quality = next
        bind()
    }

    fun startRecording() {
        val capture = videoCapture ?: return
        if (activeRecording != null) return
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) return
        val dir = File(context.cacheDir, "teleprompter").apply { mkdirs() }
        val file = File(dir, "clip-${UUID.randomUUID()}.mp4")
        var pending = capture.output.prepareRecording(context, FileOutputOptions.Builder(file).build())
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
            pending = pending.withAudioEnabled()
        }
        recordedMillis = 0
        activeRecording = pending.start(ContextCompat.getMainExecutor(context)) { event ->
            when (event) {
                is VideoRecordEvent.Start -> isRecording = true
                is VideoRecordEvent.Status -> recordedMillis = event.recordingStats.recordedDurationNanos / 1_000_000
                is VideoRecordEvent.Finalize -> {
                    isRecording = false
                    activeRecording = null
                    if (!event.hasError() && file.length() > 0) {
                        clips += TeleprompterClip(UUID.randomUUID().toString(), file, event.recordingStats.recordedDurationNanos / 1_000_000)
                    } else {
                        file.delete()
                        errorMessage = event.cause?.message ?: context.getString(R.string.teleprompter_error_record_failed)
                    }
                }
            }
        }
    }

    fun stopRecording() {
        activeRecording?.stop()
    }

    fun removeClip(clip: TeleprompterClip) {
        if (isRecording) return
        clips.removeAll { it.id == clip.id }
        clip.file.delete()
    }

    fun moveClip(from: Int, to: Int) {
        if (from !in clips.indices || to !in clips.indices || from == to) return
        val clip = clips.removeAt(from)
        clips.add(to, clip)
    }

    suspend fun export(): File? {
        if (clips.isEmpty() || isRecording || exporting) return null
        exporting = true
        errorMessage = null
        return try {
            val dir = File(context.filesDir, "exports").apply { mkdirs() }
            val output = File(dir, "ChillScript-${System.currentTimeMillis()}.mp4")
            withContext(Dispatchers.IO) {
                if (clips.size == 1) clips.first().file.copyTo(output, overwrite = true)
                else VideoClipMerger.merge(clips.map { it.file }, output)
            }
            exportedFile = output
            output
        } catch (error: Throwable) {
            errorMessage = error.message
            null
        } finally {
            exporting = false
        }
    }

    fun clearExport() { exportedFile = null }

    fun cleanup() {
        activeRecording?.stop()
        activeRecording = null
        provider?.unbindAll()
        clips.forEach { it.file.delete() }
        clips.clear()
    }

    private fun bind() {
        val view = previewView ?: return
        val future = ProcessCameraProvider.getInstance(context)
        future.addListener({
            runCatching {
                val cameraProvider = future.get()
                provider = cameraProvider
                val preview = Preview.Builder().build().also { it.surfaceProvider = view.surfaceProvider }
                val selector = if (isFrontCamera) CameraSelector.DEFAULT_FRONT_CAMERA else CameraSelector.DEFAULT_BACK_CAMERA
                val recorder = Recorder.Builder().setQualitySelector(
                    QualitySelector.from(quality, FallbackStrategy.higherQualityOrLowerThan(Quality.SD)),
                ).build()
                val capture = VideoCapture.Builder(recorder)
                    .setMirrorMode(MirrorMode.MIRROR_MODE_ON_FRONT_ONLY)
                    .build()
                videoCapture = capture
                cameraProvider.unbindAll()
                cameraProvider.bindToLifecycle(lifecycleOwner, selector, preview, capture)
            }.onFailure { errorMessage = it.message }
        }, ContextCompat.getMainExecutor(context))
    }
}

object TeleprompterVideoFiles {
    fun share(context: Context, file: File) {
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", file)
        context.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
            type = "video/mp4"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }, null))
    }

    fun preview(context: Context, file: File) {
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", file)
        context.startActivity(Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "video/mp4")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        })
    }

    fun saveToGallery(context: Context, file: File): Boolean = runCatching {
        val values = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, file.name)
            put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/ChillScript")
                put(MediaStore.Video.Media.IS_PENDING, 1)
            }
        }
        val uri = requireNotNull(context.contentResolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values))
        context.contentResolver.openOutputStream(uri)?.use { output -> file.inputStream().use { it.copyTo(output) } }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            context.contentResolver.update(uri, ContentValues().apply { put(MediaStore.Video.Media.IS_PENDING, 0) }, null, null)
        }
        true
    }.getOrDefault(false)
}

private object VideoClipMerger {
    fun merge(inputs: List<File>, output: File): File {
        require(inputs.isNotEmpty())
        val first = MediaExtractor().apply { setDataSource(inputs.first().absolutePath) }
        val muxer = MediaMuxer(output.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        val outputTracks = mutableMapOf<String, Int>()
        val trackOrder = mutableListOf<String>()
        repeat(first.trackCount) { index ->
            val format = first.getTrackFormat(index)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: return@repeat
            outputTracks[mime] = muxer.addTrack(format)
            trackOrder += mime
            if (format.containsKey(MediaFormat.KEY_ROTATION)) muxer.setOrientationHint(format.getInteger(MediaFormat.KEY_ROTATION))
        }
        first.release()
        require(outputTracks.isNotEmpty())
        muxer.start()
        val buffer = ByteBuffer.allocateDirect(4 * 1024 * 1024)
        val info = MediaCodec.BufferInfo()
        var clipOffsetUs = 0L
        try {
            inputs.forEach { file ->
                val globalFirst = trackOrder.mapNotNull { mime -> firstSampleTime(file, mime) }.minOrNull() ?: 0L
                var clipEndUs = clipOffsetUs
                trackOrder.forEach { mime ->
                    val extractor = MediaExtractor().apply { setDataSource(file.absolutePath) }
                    val trackIndex = (0 until extractor.trackCount).firstOrNull {
                        extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME) == mime
                    }
                    if (trackIndex != null) {
                        extractor.selectTrack(trackIndex)
                        while (true) {
                            buffer.clear()
                            val size = extractor.readSampleData(buffer, 0)
                            if (size < 0) break
                            info.offset = 0
                            info.size = size
                            info.presentationTimeUs = clipOffsetUs + (extractor.sampleTime - globalFirst).coerceAtLeast(0)
                            val sampleFlags = extractor.sampleFlags
                            info.flags = 0
                            if (sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC != 0) {
                                info.flags = info.flags or MediaCodec.BUFFER_FLAG_KEY_FRAME
                            }
                            if (sampleFlags and MediaExtractor.SAMPLE_FLAG_PARTIAL_FRAME != 0) {
                                info.flags = info.flags or MediaCodec.BUFFER_FLAG_PARTIAL_FRAME
                            }
                            muxer.writeSampleData(requireNotNull(outputTracks[mime]), buffer, info)
                            clipEndUs = maxOf(clipEndUs, info.presentationTimeUs)
                            extractor.advance()
                        }
                    }
                    extractor.release()
                }
                clipOffsetUs = clipEndUs + 33_333L
            }
        } finally {
            muxer.stop()
            muxer.release()
        }
        return output
    }

    private fun firstSampleTime(file: File, mime: String): Long? {
        val extractor = MediaExtractor().apply { setDataSource(file.absolutePath) }
        return try {
            val index = (0 until extractor.trackCount).firstOrNull { extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME) == mime } ?: return null
            extractor.selectTrack(index)
            extractor.sampleTime.takeIf { it >= 0 }
        } finally {
            extractor.release()
        }
    }
}
