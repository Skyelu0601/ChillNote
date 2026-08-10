package com.sponteoai.chillscript.voice

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import java.io.File

class VoiceRecorder(private val context: Context) {
    private val fileManager = RecordingFileManager(context)
    private var recorder: MediaRecorder? = null
    private var outputFile: File? = null

    val isRecording: Boolean get() = recorder != null

    fun start(): File {
        check(recorder == null) { "Recording already started" }
        val file = fileManager.createRecordingFile()
        val mediaRecorder = if (Build.VERSION.SDK_INT >= 31) MediaRecorder(context) else @Suppress("DEPRECATION") MediaRecorder()
        mediaRecorder.setAudioSource(MediaRecorder.AudioSource.MIC)
        mediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
        mediaRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
        mediaRecorder.setAudioSamplingRate(44_100)
        mediaRecorder.setAudioEncodingBitRate(128_000)
        mediaRecorder.setOutputFile(file.absolutePath)
        mediaRecorder.prepare()
        mediaRecorder.start()
        recorder = mediaRecorder
        outputFile = file
        return file
    }

    fun stop(): File? {
        val active = recorder ?: return null
        val file = outputFile
        return try {
            active.stop()
            file?.takeIf { it.exists() && it.length() > 0 }
        } catch (_: RuntimeException) {
            file?.delete()
            null
        } finally {
            active.release()
            recorder = null
            outputFile = null
        }
    }

    fun cancel() { stop()?.let(fileManager::cancel) }
}
