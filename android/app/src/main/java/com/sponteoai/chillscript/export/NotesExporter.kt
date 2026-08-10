package com.sponteoai.chillscript.export

import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import com.sponteoai.chillscript.data.local.NoteEntity
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.io.File
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

enum class NoteExportFormat(val extension: String, val mimeType: String) {
    MARKDOWN("md", "text/markdown"),
    TEXT("txt", "text/plain"),
    JSON("json", "application/json"),
}

enum class NotesExportStage {
    PREPARING,
    WRITING,
    PACKAGING,
}

data class NotesExportProgress(
    val stage: NotesExportStage,
    val processed: Int,
    val total: Int,
) {
    val fraction: Float
        get() = if (total == 0) 0f else (processed.toFloat() / total).coerceIn(0f, 1f)
}

object NotesExporter {
    fun exportNote(context: Context, note: NoteEntity, format: NoteExportFormat): File {
        val dir = File(context.filesDir, "exports").apply { mkdirs() }
        val file = File(dir, "${safeBaseName(note)}.${format.extension}")
        file.writeText(when (format) {
            NoteExportFormat.MARKDOWN, NoteExportFormat.TEXT -> note.content
            NoteExportFormat.JSON -> prettyJson.encodeToString(JsonElement.serializer(), noteJson(note))
        })
        return file
    }

    suspend fun exportAll(
        context: Context,
        notes: List<NoteEntity>,
        onProgress: suspend (NotesExportProgress) -> Unit = {},
    ): File = exportAllToDirectory(
        directory = File(context.filesDir, "exports"),
        notes = notes,
        onProgress = onProgress,
    )

    internal suspend fun exportAllToDirectory(
        directory: File,
        notes: List<NoteEntity>,
        onProgress: suspend (NotesExportProgress) -> Unit = {},
    ): File {
        require(notes.isNotEmpty())
        val active = notes.filter { it.deletedAt == null }
        require(active.isNotEmpty())
        directory.mkdirs()
        val output = File(directory, "ChillScript-notes-${System.currentTimeMillis()}.zip")
        try {
            onProgress(NotesExportProgress(NotesExportStage.PREPARING, 0, active.size))
            ZipOutputStream(output.outputStream().buffered()).use { zip ->
                active.forEachIndexed { index, note ->
                    currentCoroutineContext().ensureActive()
                    zip.putNextEntry(ZipEntry("markdown/${safeBaseName(note)}.md"))
                    zip.write(note.content.toByteArray())
                    zip.closeEntry()
                    onProgress(NotesExportProgress(NotesExportStage.WRITING, index + 1, active.size))
                }
                currentCoroutineContext().ensureActive()
                onProgress(NotesExportProgress(NotesExportStage.PACKAGING, active.size, active.size))
                zip.putNextEntry(ZipEntry("notes.json"))
                val json = buildJsonArray { active.forEach { add(noteJson(it)) } }
                zip.write(prettyJson.encodeToString(JsonElement.serializer(), json).toByteArray())
                zip.closeEntry()
                currentCoroutineContext().ensureActive()
                zip.putNextEntry(ZipEntry("notes.txt"))
                zip.write(active.joinToString("\n\n---\n\n") { it.content }.toByteArray())
                zip.closeEntry()
            }
            currentCoroutineContext().ensureActive()
            return output
        } catch (error: Throwable) {
            output.delete()
            throw error
        }
    }

    fun share(context: Context, file: File, mimeType: String) {
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", file)
        context.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }, null))
    }

    fun safeBaseName(note: NoteEntity): String {
        val raw = note.content.lineSequence().map(String::trim).firstOrNull(String::isNotEmpty).orEmpty()
        val clean = raw.replace(Regex("[\\\\/:*?\"<>|]"), "-")
            .replace(Regex("\\s+"), " ").trim().ifBlank { "ChillScript" }.take(60).trim()
        return "$clean-${note.id.take(6)}"
    }

    private fun noteJson(note: NoteEntity) = buildJsonObject {
        put("id", note.id)
        put("content", note.content)
        put("section", note.section)
        put("createdAt", note.createdAt)
        put("updatedAt", note.updatedAt)
        note.sourceUrl?.let { put("sourceUrl", it) }
        note.sourceTitle?.let { put("sourceTitle", it) }
    }

    private val prettyJson = Json { prettyPrint = true }
}
