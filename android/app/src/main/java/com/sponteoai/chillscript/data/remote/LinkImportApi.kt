package com.sponteoai.chillscript.data.remote

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL
import com.sponteoai.chillscript.domain.SourcePlatformResolver

@Serializable data class LinkSourceDto(
    val url: String,
    val title: String,
    val platformID: String,
    val platformName: String,
    val host: String,
)

@Serializable data class MediaLinkSectionsDto(
    val showDescription: Boolean = true,
    val showAuthor: Boolean = true,
    val showHook: Boolean = true,
    val showTranscript: Boolean = true,
)

@Serializable data class LinkImportRequest(
    val noteId: String,
    val url: String,
    val placeholderContent: String,
    val source: LinkSourceDto,
    val section: String,
    val mediaLinkSections: MediaLinkSectionsDto = MediaLinkSectionsDto(),
)

@Serializable data class LinkImportJobResponse(val jobId: String, val status: String)

class LinkImportApi(
    private val baseUrl: String = "https://api.chillnoteai.com",
    private val json: Json = Json { ignoreUnknownKeys = true },
) {
    suspend fun enqueue(accessToken: String, request: LinkImportRequest): LinkImportJobResponse = withContext(Dispatchers.IO) {
        val connection = URL("${baseUrl.trimEnd('/')}/link-import-jobs").openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 15_000
            connection.readTimeout = 30_000
            connection.doOutput = true
            connection.setRequestProperty("Authorization", "Bearer $accessToken")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.outputStream.bufferedWriter().use {
                it.write(json.encodeToString(LinkImportRequest.serializer(), request))
            }
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val body = stream?.bufferedReader()?.use { it.readText() }.orEmpty()
            if (status !in 200..299) throw SyncHttpException(status, body)
            json.decodeFromString(LinkImportJobResponse.serializer(), body)
        } finally { connection.disconnect() }
    }
}

fun sourceForUrl(rawUrl: String): LinkSourceDto {
    val uri = URI(rawUrl)
    val host = uri.host?.removePrefix("www.").orEmpty()
    val platform = SourcePlatformResolver.resolve(rawUrl)
    return LinkSourceDto(rawUrl, host.ifBlank { rawUrl }, platform.id, platform.displayName, host)
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
