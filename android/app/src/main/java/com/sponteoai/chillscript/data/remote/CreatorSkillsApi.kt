package com.sponteoai.chillscript.data.remote

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.net.HttpURLConnection
import java.net.URL

@Serializable private data class CreatorSkillRequest(
    val prompt: String,
    val systemPrompt: String,
    val usageType: String,
)

@Serializable private data class CreatorSkillResponse(val content: String = "")

class CreatorSkillsApi(
    private val baseUrl: String = "https://api.chillnoteai.com",
    private val json: Json = Json { ignoreUnknownKeys = true },
) {
    suspend fun generate(
        accessToken: String,
        prompt: String,
        systemPrompt: String,
        usageType: String = "agent_recipe",
    ): String = withContext(Dispatchers.IO) {
        val connection = URL("${baseUrl.trimEnd('/')}/ai/gemini").openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 20_000
            connection.readTimeout = 180_000
            connection.doOutput = true
            connection.setRequestProperty("Authorization", "Bearer $accessToken")
            connection.setRequestProperty("Content-Type", "application/json")
            val request = CreatorSkillRequest(prompt, systemPrompt, usageType)
            connection.outputStream.bufferedWriter().use {
                it.write(json.encodeToString(CreatorSkillRequest.serializer(), request))
            }
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val body = stream?.bufferedReader()?.use { it.readText() }.orEmpty()
            if (status !in 200..299) throw SyncHttpException(status, body)
            json.decodeFromString(CreatorSkillResponse.serializer(), body).content.trim()
                .also { require(it.isNotBlank()) { "AI returned an empty result" } }
        } finally {
            connection.disconnect()
        }
    }
}
