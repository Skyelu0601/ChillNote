package com.sponteoai.chillscript.data.remote

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.net.HttpURLConnection
import java.io.IOException
import java.net.URI
import java.net.URL
import com.sponteoai.chillscript.domain.SourcePlatformResolver

@Serializable data class LinkSourceDto(
    val url: String,
    val title: String,
    val platformID: String,
    val platformName: String,
    val host: String,
    val authorName: String? = null,
    val authorHandle: String? = null,
)

@Serializable data class MediaLinkSectionsDto(
    val showDescription: Boolean,
    val showAuthor: Boolean,
    val showHook: Boolean,
    val showTranscript: Boolean,
) {
    companion object {
        /** The current iOS canonical format: source metadata stays out of the note body. */
        val TranscriptOnly = MediaLinkSectionsDto(
            showDescription = false,
            showAuthor = false,
            showHook = false,
            showTranscript = true,
        )
    }
}

@Serializable data class LinkImportRequest(
    val noteId: String,
    val url: String,
    val placeholderContent: String,
    val source: LinkSourceDto,
    val section: String,
    val contentLocale: String,
    // Keep this required. kotlinx.serialization omits default-valued properties unless
    // encodeDefaults is enabled; omission makes older servers enable every legacy section.
    val mediaLinkSections: MediaLinkSectionsDto,
)

@Serializable data class LinkImportJobResponse(val jobId: String, val status: String)

internal data class LinkImportHttpResponse(val statusCode: Int, val body: String)

internal fun interface LinkImportTransport {
    suspend fun execute(url: String, accessToken: String, body: String): LinkImportHttpResponse
}

class LinkImportApi internal constructor(
    private val baseUrl: String,
    private val json: Json,
    private val transport: LinkImportTransport,
    private val retryDelay: suspend (Long) -> Unit,
) {
    constructor(
        baseUrl: String = "https://api.chillnoteai.com",
        json: Json = Json { ignoreUnknownKeys = true },
    ) : this(baseUrl, json, HttpUrlConnectionLinkImportTransport(), { delay(it) })

    suspend fun enqueue(accessToken: String, request: LinkImportRequest): LinkImportJobResponse {
        val url = "${baseUrl.trimEnd('/')}/link-import-jobs"
        val body = json.encodeToString(LinkImportRequest.serializer(), request)
        var lastError: Throwable? = null
        repeat(MAX_ATTEMPTS) { attempt ->
            try {
                val response = transport.execute(url, accessToken, body)
                if (response.statusCode !in 200..299) {
                    throw SyncHttpException(response.statusCode, response.body)
                }
                return json.decodeFromString(LinkImportJobResponse.serializer(), response.body)
            } catch (error: Throwable) {
                lastError = error
                val canRetry = error is IOException ||
                    (error is SyncHttpException && error.statusCode.isTransientHttpStatus())
                if (!canRetry || attempt == MAX_ATTEMPTS - 1) throw error
                retryDelay(BASE_RETRY_DELAY_MILLIS shl attempt)
            }
        }
        throw checkNotNull(lastError)
    }

    private companion object {
        const val MAX_ATTEMPTS = 3
        const val BASE_RETRY_DELAY_MILLIS = 500L
    }
}

internal class HttpUrlConnectionLinkImportTransport : LinkImportTransport {
    override suspend fun execute(url: String, accessToken: String, body: String): LinkImportHttpResponse =
        withContext(Dispatchers.IO) {
            val connection = URL(url).openConnection() as HttpURLConnection
            try {
                connection.requestMethod = "POST"
                connection.connectTimeout = 15_000
                connection.readTimeout = 30_000
                connection.doOutput = true
                connection.setRequestProperty("Authorization", "Bearer $accessToken")
                connection.setRequestProperty("Content-Type", "application/json")
                connection.outputStream.bufferedWriter().use { it.write(body) }
                val status = connection.responseCode
                val stream = if (status in 200..299) connection.inputStream else connection.errorStream
                LinkImportHttpResponse(status, stream?.bufferedReader()?.use { it.readText() }.orEmpty())
            } finally {
                connection.disconnect()
            }
        }
}

private fun Int.isTransientHttpStatus(): Boolean = this in setOf(408, 425, 429) || this in 500..599

fun sourceForUrl(rawUrl: String): LinkSourceDto {
    val uri = URI(rawUrl)
    val host = uri.host?.removePrefix("www.").orEmpty()
    val platform = SourcePlatformResolver.resolve(rawUrl)
    return LinkSourceDto(
        url = rawUrl,
        title = platform.displayName.ifBlank { host.ifBlank { rawUrl } },
        platformID = platform.id,
        platformName = platform.displayName,
        host = host,
    )
}

fun extractWebUrl(text: String): String? {
    val inline = Regex("(?i)(https?://[^\\s<>\\\"'“”‘’]+|www\\.[^\\s<>\\\"'“”‘’]+)").find(text)?.value
    val candidate = inline ?: text.trim().takeIf {
        Regex("(?i)^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+(?:/[^^\\s<>\\\"']*)?$").matches(it)
    } ?: return null
    val cleaned = candidate.trim().trim('<', '>', '[', ']', '{', '}', '(', ')', '"', '\'', '“', '”', '‘', '’', '`', '.', ',', ';', ':', '!', '?', '，', '。', '；', '：', '！', '？', '、')
    val normalized = when {
        cleaned.startsWith("http://", ignoreCase = true) -> "https://${cleaned.substringAfter("://")}" 
        cleaned.startsWith("https://", ignoreCase = true) -> "https://${cleaned.substringAfter("://")}" 
        else -> "https://$cleaned"
    }
    val uri = runCatching { URI(normalized) }.getOrNull()
    return normalized.takeIf { uri?.host?.isNotBlank() == true }
}

/** Matches iOS QuickCaptureLinkParser: Paste Link only accepts creator media URLs. */
fun extractCreatorMediaUrl(text: String): String? =
    extractWebUrl(text)?.takeIf(::isCreatorMediaUrl)

fun isCreatorMediaUrl(rawUrl: String): Boolean {
    val uri = runCatching { URI(rawUrl) }.getOrNull() ?: return false
    val path = uri.path.orEmpty().lowercase()
    return when (sourceForUrl(rawUrl).platformID) {
        "tiktok" -> true
        "youtube" -> {
            val normalizedHost = uri.host.orEmpty().removePrefix("www.").lowercase()
            val hasVideoId = uri.rawQuery.orEmpty()
                .split('&')
                .any { queryPart ->
                    val parts = queryPart.split('=', limit = 2)
                    parts.firstOrNull()?.equals("v", ignoreCase = true) == true &&
                        parts.getOrNull(1).orEmpty().isNotBlank()
                }
            (normalizedHost == "youtu.be" && path.length > 1) ||
                hasVideoId ||
                path.startsWith("/shorts/") ||
                path.startsWith("/live/") ||
                path.startsWith("/embed/")
        }
        "instagram" -> path.startsWith("/reel/") ||
            path.startsWith("/reels/") ||
            path.startsWith("/p/") ||
            path.startsWith("/tv/")
        else -> false
    }
}
