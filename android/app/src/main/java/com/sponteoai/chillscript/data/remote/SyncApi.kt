package com.sponteoai.chillscript.data.remote

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import java.net.HttpURLConnection
import java.net.URL

fun interface SyncClient {
    suspend fun sync(accessToken: String, payload: SyncPayload): SyncResponse
}

class SyncApi(
    private val baseUrl: String = "https://api.chillnoteai.com",
    private val json: Json = Json { ignoreUnknownKeys = true; explicitNulls = true },
) : SyncClient {
    override suspend fun sync(accessToken: String, payload: SyncPayload): SyncResponse = withContext(Dispatchers.IO) {
        val connection = URL("${baseUrl.trimEnd('/')}/sync").openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 15_000
            connection.readTimeout = 30_000
            connection.doOutput = true
            connection.setRequestProperty("Authorization", "Bearer $accessToken")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.outputStream.bufferedWriter(Charsets.UTF_8).use {
                it.write(json.encodeToString(SyncPayload.serializer(), payload))
            }
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val body = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
            if (status !in 200..299) throw SyncHttpException(status, body)
            json.decodeFromString(SyncResponse.serializer(), body)
        } finally {
            connection.disconnect()
        }
    }
}

class SyncHttpException(val statusCode: Int, responseBody: String) :
    Exception("Sync failed ($statusCode): ${responseBody.take(300)}")
