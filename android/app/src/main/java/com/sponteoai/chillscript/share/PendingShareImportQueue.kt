package com.sponteoai.chillscript.share

import android.content.Context
import android.util.Log
import com.sponteoai.chillscript.data.remote.LinkSourceDto
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.io.File
import java.io.IOException
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
        ensureDirectory()
        val destination = fileFor(item.id)
        val temporary = File(directory, ".${item.id}.${System.nanoTime()}.tmp")
        temporary.writeText(json.encodeToString(PendingShareImport.serializer(), item))
        if (!temporary.renameTo(destination)) {
            temporary.copyTo(destination, overwrite = true)
            if (!temporary.delete() && temporary.exists()) {
                Log.w(TAG, "Could not remove temporary pending-share file ${temporary.name}")
            }
        }
    }

    fun pending(): List<PendingShareImport> {
        ensureDirectory()
        val files = directory.listFiles { file -> file.isFile && file.extension == FILE_EXTENSION }
            ?: throw IOException("Could not list pending share directory")
        return files
            .map { file ->
                try {
                    json.decodeFromString(PendingShareImport.serializer(), file.readText())
                } catch (error: Throwable) {
                    throw IOException("Could not read pending share ${file.name}", error)
                }
            }
            .sortedBy { item -> runCatching { Instant.parse(item.createdAt) }.getOrNull() }
    }

    fun remove(id: String) {
        val file = fileFor(id)
        if (file.exists() && !file.delete()) {
            throw IOException("Could not remove pending share ${file.name}")
        }
    }

    fun clear() {
        ensureDirectory()
        val files = directory.listFiles() ?: throw IOException("Could not list pending share directory")
        files.forEach { file ->
            if (!file.delete() && file.exists()) {
                throw IOException("Could not remove pending share ${file.name}")
            }
        }
    }

    private fun fileFor(id: String): File = File(directory, "$id.$FILE_EXTENSION")

    private fun ensureDirectory() {
        if (directory.isDirectory) return
        if (!directory.mkdirs() && !directory.isDirectory) {
            throw IOException("Could not create pending share directory")
        }
    }

    companion object {
        private const val TAG = "PendingShareQueue"
        private const val FILE_EXTENSION = "json"
        private const val DIRECTORY_NAME = "PendingShareImports"

        fun get(context: Context): PendingShareImportQueue = PendingShareImportQueue(
            File(context.applicationContext.filesDir, DIRECTORY_NAME),
        )
    }
}
