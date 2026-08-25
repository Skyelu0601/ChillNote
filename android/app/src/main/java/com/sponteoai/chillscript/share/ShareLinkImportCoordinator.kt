package com.sponteoai.chillscript.share

import android.content.Context
import android.util.Log
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.auth.AuthRepository
import com.sponteoai.chillscript.data.remote.LinkImportApi
import com.sponteoai.chillscript.data.remote.LinkImportRequest
import com.sponteoai.chillscript.data.remote.MediaLinkSectionsDto
import com.sponteoai.chillscript.data.remote.extractWebUrl
import com.sponteoai.chillscript.data.remote.sourceForUrl
import com.sponteoai.chillscript.sync.BackgroundSyncScheduler
import java.time.Instant
import java.util.UUID

enum class ShareLinkImportStage {
    ReadingContent,
    Saving,
    Completed,
}

class ShareLinkImportException : Exception("No web link was found in the shared content")

/** Mirrors iOS ShareImportService: persist first, then best-effort remote enqueue. */
class ShareLinkImportCoordinator(
    context: Context,
    private val queue: PendingShareImportQueue = PendingShareImportQueue.get(context),
    private val authRepository: AuthRepository = AuthRepository(context.applicationContext),
    private val linkImportApi: LinkImportApi = LinkImportApi(),
) {
    private val appContext = context.applicationContext

    suspend fun importSharedText(
        sharedText: String,
        onStage: (ShareLinkImportStage) -> Unit,
    ): PendingShareImport {
        onStage(ShareLinkImportStage.ReadingContent)
        val url = extractWebUrl(sharedText) ?: throw ShareLinkImportException()
        val source = sourceForUrl(url)
        val session = authRepository.restoreSession()
        val pending = PendingShareImport(
            id = UUID.randomUUID().toString(),
            url = url,
            source = source,
            ownerUserId = session?.user?.id,
            createdAt = Instant.now().toString(),
        )

        onStage(ShareLinkImportStage.Saving)
        queue.save(pending)

        if (session != null) {
            runCatching {
                val job = linkImportApi.enqueue(
                    session.accessToken,
                    LinkImportRequest(
                        noteId = pending.id,
                        url = pending.url,
                        placeholderContent = placeholder(source.host.ifBlank { pending.url }),
                        source = source,
                        section = "inbox",
                        mediaLinkSections = MediaLinkSectionsDto.TranscriptOnly,
                    ),
                )
                pending.copy(importJobId = job.jobId, importStatus = job.status).also(queue::save)
            }.onSuccess {
                BackgroundSyncScheduler.enqueueLinkImportRecovery(appContext)
            }.onFailure { error ->
                // iOS deliberately treats remote enqueue as best effort. The durable queue is
                // consumed after the app next signs in or enters the foreground.
                Log.w(TAG, "Remote share enqueue failed; keeping the local queue item", error)
            }
        }

        onStage(ShareLinkImportStage.Completed)
        return pending
    }

    private fun placeholder(host: String): String = buildString {
        append("# ")
        append(appContext.getString(R.string.quick_capture_link_import_placeholder_title))
        append("\n\n")
        append(appContext.getString(R.string.quick_capture_link_import_placeholder_format, host))
    }

    private companion object {
        const val TAG = "ShareLinkImport"
    }
}
