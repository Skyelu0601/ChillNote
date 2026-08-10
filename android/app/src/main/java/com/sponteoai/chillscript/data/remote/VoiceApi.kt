package com.sponteoai.chillscript.data.remote

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.net.HttpURLConnection
import java.net.URL

@Serializable private data class VoiceRequest(
    val audioBase64: String,
    val mimeType: String,
    val locale: String,
    val spokenLanguageMode: String,
    val spokenLanguageHint: String? = null,
    val countUsage: Boolean = true,
)
@Serializable private data class VoiceResponse(val text: String? = null, val content: String? = null)
@Serializable private data class RefineRequest(val prompt: String, val systemPrompt: String)
@Serializable private data class RefineResponse(val content: String)

class VoiceApi(
    private val baseUrl: String = "https://api.chillnoteai.com",
    private val json: Json = Json { ignoreUnknownKeys = true },
) {
    suspend fun transcribe(
        accessToken: String, audioBase64: String, mimeType: String, locale: String,
        spokenLanguageMode: String = "auto", spokenLanguageHint: String? = null,
    ): String = post(
        "/ai/voice-note", accessToken,
        json.encodeToString(VoiceRequest.serializer(), VoiceRequest(
            audioBase64, mimeType, locale, spokenLanguageMode,
            spokenLanguageHint?.trim()?.takeIf { it.isNotEmpty() },
        )),
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
}
