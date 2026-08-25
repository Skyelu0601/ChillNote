package com.sponteoai.chillscript.share

import android.content.Context
import android.util.Log
import com.sponteoai.chillscript.data.remote.LinkSourceDto
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.io.File
import java.time.Instant

@Serializable
data class PendingShareImport(
    val id: String,
    val url: String,
    val source: LinkSourceDto,
    val importJobId: String? = null,
    val importStatus: String? = null,
    val ownerUserId: String? = null,
    val createdAt: String,
)

/**
 * Android counterpart of iOS SharedImportQueue.
 *
 * Every share is written before the network request starts. Rewriting the same
 * UUID after a remote job is accepted makes the hand-off idempotent across
 * process death, sign-in changes, and app foregrounding.
 */
class PendingShareImportQueue(
    private val directory: File,
    private val json: Json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
        explicitNulls = false
        prettyPrint = true
    },
) {
    fun save(item: PendingShareImport) {
        directory.mkdirs()
        val destination = fileFor(item.id)
        val temporary = File(directory, ".${item.id}.${System.nanoTime()}.tmp")
        temporary.writeText(json.encodeToString(PendingShareImport.serializer(), item))
        if (!temporary.renameTo(destination)) {
            temporary.copyTo(destination, overwrite = true)
            temporary.delete()
        }
    }

    fun pending(): List<PendingShareImport> {
        directory.mkdirs()
        return directory.listFiles { file -> file.isFile && file.extension == FILE_EXTENSION }
            .orEmpty()
            .mapNotNull { file ->
                runCatching {
                    json.decodeFromString(PendingShareImport.serializer(), file.readText())
                }.onFailure { error ->
                    Log.w(TAG, "Could not read pending share ${file.name}", error)
                }.getOrNull()
            }
            .sortedBy { item -> runCatching { Instant.parse(item.createdAt) }.getOrNull() }
    }

    fun remove(id: String) {
        fileFor(id).delete()
    }

    fun clear() {
        directory.listFiles().orEmpty().forEach { it.delete() }
    }

    private fun fileFor(id: String): File = File(directory, "$id.$FILE_EXTENSION")

    companion object {
        private const val TAG = "PendingShareQueue"
        private const val FILE_EXTENSION = "json"
        private const val DIRECTORY_NAME = "PendingShareImports"

        fun get(context: Context): PendingShareImportQueue = PendingShareImportQueue(
            File(context.applicationContext.filesDir, DIRECTORY_NAME),
        )
    }
}
