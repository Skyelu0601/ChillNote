package com.sponteoai.chillscript.data.remote

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonPrimitive
import java.io.BufferedOutputStream
import java.io.FilterOutputStream
import java.io.OutputStream
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.Base64

@Serializable private data class VoiceResponse(val text: String? = null, val content: String? = null)
@Serializable private data class RefineRequest(val prompt: String, val systemPrompt: String)
@Serializable private data class RefineResponse(val content: String)

class VoiceApi(
    private val baseUrl: String = "https://api.chillnoteai.com",
    private val json: Json = Json { ignoreUnknownKeys = true },
) {
    suspend fun transcribe(
        accessToken: String, mediaFile: File, mimeType: String, locale: String,
        spokenLanguageMode: String = "auto", spokenLanguageHint: String? = null,
        countUsage: Boolean = true,
    ): String = postMedia(
        path = "/ai/voice-note",
        token = accessToken,
        mediaFile = mediaFile,
        envelope = voiceMediaJsonEnvelope(
            mimeType = mimeType,
            locale = locale,
            spokenLanguageMode = spokenLanguageMode,
            spokenLanguageHint = spokenLanguageHint?.trim()?.takeIf { it.isNotEmpty() },
            countUsage = countUsage,
        ),
    ) { body ->
        val response = json.decodeFromString(VoiceResponse.serializer(), body)
        (response.text ?: response.content).orEmpty().trim()
    }

    suspend fun refine(accessToken: String, transcript: String): String {
        val prompt = "Process this voice transcript into clean, directly usable text.\n\nVoice transcript:\n$transcript"
        val systemPrompt = """
            You are a voice-to-text optimizer called ChillScript.
            Preserve the user's intent, meaning, facts, certainty, and every spoken language exactly.
            Do not translate. Remove only obvious filler, accidental repetition, and resolved self-corrections.
            Apply light grammar, punctuation, and paragraph cleanup. Do not invent facts or tasks.
            If the content clearly contains tasks, use Markdown checklist items. For short inputs, edit minimally.
            Return only the processed note text without explanations.
        """.trimIndent()
        return post(
            "/ai/gemini", accessToken,
            json.encodeToString(RefineRequest.serializer(), RefineRequest(prompt, systemPrompt)),
        ) { json.decodeFromString(RefineResponse.serializer(), it).content.trim() }
    }

    private suspend fun <T> post(path: String, token: String, requestBody: String, decode: (String) -> T): T =
        withContext(Dispatchers.IO) {
            val connection = URL("${baseUrl.trimEnd('/')}$path").openConnection() as HttpURLConnection
            try {
                connection.requestMethod = "POST"
                connection.connectTimeout = 20_000
                connection.readTimeout = 180_000
                connection.doOutput = true
                connection.setRequestProperty("Authorization", "Bearer $token")
                connection.setRequestProperty("Content-Type", "application/json")
                connection.outputStream.bufferedWriter().use { it.write(requestBody) }
                val status = connection.responseCode
                val stream = if (status in 200..299) connection.inputStream else connection.errorStream
                val body = stream?.bufferedReader()?.use { it.readText() }.orEmpty()
                if (status !in 200..299) throw SyncHttpException(status, body)
                decode(body)
            } finally { connection.disconnect() }
        }

    /** Streams Base64 directly to the request body so large media is never duplicated in heap. */
    private suspend fun <T> postMedia(
        path: String,
        token: String,
        mediaFile: File,
        envelope: VoiceMediaJsonEnvelope,
        decode: (String) -> T,
    ): T = withContext(Dispatchers.IO) {
        require(mediaFile.isFile && mediaFile.length() > 0L) { "Media file was empty" }
        val connection = URL("${baseUrl.trimEnd('/')}$path").openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 20_000
            connection.readTimeout = 180_000
            connection.doOutput = true
            connection.setChunkedStreamingMode(64 * 1024)
            connection.setRequestProperty("Authorization", "Bearer $token")
            connection.setRequestProperty("Content-Type", "application/json")

            val output = BufferedOutputStream(connection.outputStream, 64 * 1024)
            output.write(envelope.prefix)
            val base64 = Base64.getEncoder().wrap(NonClosingOutputStream(output))
            mediaFile.inputStream().buffered(64 * 1024).use { input -> input.copyTo(base64) }
            base64.close()
            output.write(envelope.suffix)
            output.close()

            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val body = stream?.bufferedReader()?.use { it.readText() }.orEmpty()
            if (status !in 200..299) throw SyncHttpException(status, body)
            decode(body)
        } finally {
            connection.disconnect()
        }
    }
}

internal data class VoiceMediaJsonEnvelope(
    val prefix: ByteArray,
    val suffix: ByteArray,
)

internal fun voiceMediaJsonEnvelope(
    mimeType: String,
    locale: String,
    spokenLanguageMode: String,
    spokenLanguageHint: String?,
    countUsage: Boolean,
): VoiceMediaJsonEnvelope {
    val suffix = buildString {
        append("\",\"mimeType\":")
        append(JsonPrimitive(mimeType))
        append(",\"locale\":")
        append(JsonPrimitive(locale))
        append(",\"spokenLanguageMode\":")
        append(JsonPrimitive(spokenLanguageMode))
        if (spokenLanguageHint != null) {
            append(",\"spokenLanguageHint\":")
            append(JsonPrimitive(spokenLanguageHint))
        }
        append(",\"countUsage\":")
        append(countUsage)
        append('}')
    }
    return VoiceMediaJsonEnvelope(
        prefix = "{\"audioBase64\":\"".toByteArray(Charsets.UTF_8),
        suffix = suffix.toByteArray(Charsets.UTF_8),
    )
}

private class NonClosingOutputStream(output: OutputStream) : FilterOutputStream(output) {
    override fun close() {
        flush()
    }
}
