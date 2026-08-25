package com.sponteoai.chillscript.weekly

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL
import java.net.URLEncoder
import java.nio.charset.StandardCharsets

interface WeeklyTopicsDataSource {
    suspend fun dashboard(accessToken: String): WeeklyTopicDashboard

    suspend fun updateSettings(
        accessToken: String,
        payload: WeeklyTopicSettingsPayload,
    ): WeeklyTopicSettings

    suspend fun reports(accessToken: String, limit: Int = 30): List<WeeklyTopicReport>

    suspend fun report(accessToken: String, reportId: String): WeeklyTopicReport

    suspend fun markRead(accessToken: String, reportId: String)

    suspend fun regenerate(accessToken: String, reportId: String): WeeklyTopicReport
}

enum class WeeklyTopicsApiError {
    INVALID_URL,
    UNAUTHORIZED,
    NOT_FOUND,
    CONFLICT,
    NETWORK,
    INVALID_RESPONSE,
    SERVER,
}

class WeeklyTopicsApiException(
    val reason: WeeklyTopicsApiError,
    val statusCode: Int? = null,
    cause: Throwable? = null,
) : Exception("Weekly topics request failed: $reason", cause)

internal data class WeeklyTopicsHttpRequest(
    val url: String,
    val method: String,
    val headers: Map<String, String>,
    val body: String? = null,
)

internal data class WeeklyTopicsHttpResponse(
    val statusCode: Int,
    val body: String,
)

internal fun interface WeeklyTopicsTransport {
    suspend fun execute(request: WeeklyTopicsHttpRequest): WeeklyTopicsHttpResponse
}

class WeeklyTopicsApi internal constructor(
    baseUrl: String,
    private val json: Json,
    private val transport: WeeklyTopicsTransport,
) : WeeklyTopicsDataSource {
    constructor(
        baseUrl: String = "https://api.chillnoteai.com",
        json: Json = defaultWeeklyTopicsJson(),
    ) : this(baseUrl, json, HttpUrlConnectionWeeklyTopicsTransport())

    private val baseUrl = baseUrl.trimEnd('/')

    override suspend fun dashboard(accessToken: String): WeeklyTopicDashboard = request(
        path = "/weekly-topics/dashboard",
        accessToken = accessToken,
        serializer = WeeklyTopicDashboard.serializer(),
    )

    override suspend fun updateSettings(
        accessToken: String,
        payload: WeeklyTopicSettingsPayload,
    ): WeeklyTopicSettings = request(
        path = "/weekly-topics/settings",
        method = "PUT",
        accessToken = accessToken,
        requestBody = json.encodeToString(WeeklyTopicSettingsPayload.serializer(), payload),
        serializer = WeeklyTopicSettings.serializer(),
    )

    override suspend fun reports(accessToken: String, limit: Int): List<WeeklyTopicReport> {
        val boundedLimit = limit.coerceIn(1, 52)
        return request(
            path = "/weekly-topics/reports?limit=$boundedLimit",
            accessToken = accessToken,
            serializer = WeeklyTopicReportsResponse.serializer(),
        ).reports
    }

    override suspend fun report(accessToken: String, reportId: String): WeeklyTopicReport = request(
        path = "/weekly-topics/reports/${encodePathSegment(reportId)}",
        accessToken = accessToken,
        serializer = WeeklyTopicReport.serializer(),
    )

    override suspend fun markRead(accessToken: String, reportId: String) {
        requestWithoutResponse(
            path = "/weekly-topics/reports/${encodePathSegment(reportId)}/read",
            method = "POST",
            accessToken = accessToken,
        )
    }

    override suspend fun regenerate(accessToken: String, reportId: String): WeeklyTopicReport = request(
        path = "/weekly-topics/reports/${encodePathSegment(reportId)}/regenerate",
        method = "POST",
        accessToken = accessToken,
        serializer = WeeklyTopicReport.serializer(),
    )

    private suspend fun <T> request(
        path: String,
        method: String = "GET",
        accessToken: String,
        requestBody: String? = null,
        serializer: KSerializer<T>,
    ): T {
        val response = execute(path, method, accessToken, requestBody)
        if (response.body.isBlank()) {
            throw WeeklyTopicsApiException(
                reason = WeeklyTopicsApiError.INVALID_RESPONSE,
                statusCode = response.statusCode,
            )
        }
        return try {
            json.decodeFromString(serializer, response.body)
        } catch (error: SerializationException) {
            throw WeeklyTopicsApiException(
                reason = WeeklyTopicsApiError.INVALID_RESPONSE,
                statusCode = response.statusCode,
                cause = error,
            )
        }
    }

    private suspend fun requestWithoutResponse(
        path: String,
        method: String,
        accessToken: String,
    ) {
        execute(path, method, accessToken, requestBody = null)
    }

    private suspend fun execute(
        path: String,
        method: String,
        accessToken: String,
        requestBody: String?,
    ): WeeklyTopicsHttpResponse {
        val token = accessToken.trim()
        if (token.isEmpty()) {
            throw WeeklyTopicsApiException(WeeklyTopicsApiError.UNAUTHORIZED)
        }
        val request = WeeklyTopicsHttpRequest(
            url = makeUrl(path),
            method = method,
            headers = buildMap {
                put("Authorization", "Bearer $token")
                put("Accept", "application/json")
                if (requestBody != null) put("Content-Type", "application/json")
            },
            body = requestBody,
        )
        val response = try {
            transport.execute(request)
        } catch (error: CancellationException) {
            throw error
        } catch (error: WeeklyTopicsApiException) {
            throw error
        } catch (error: IOException) {
            throw WeeklyTopicsApiException(WeeklyTopicsApiError.NETWORK, cause = error)
        } catch (error: Exception) {
            throw WeeklyTopicsApiException(WeeklyTopicsApiError.NETWORK, cause = error)
        }
        validate(response.statusCode)
        return response
    }

    private fun makeUrl(path: String): String {
        val candidate = "$baseUrl$path"
        val uri = try {
            URI(candidate)
        } catch (error: Exception) {
            throw WeeklyTopicsApiException(WeeklyTopicsApiError.INVALID_URL, cause = error)
        }
        if (uri.scheme !in setOf("http", "https") || uri.host.isNullOrBlank()) {
            throw WeeklyTopicsApiException(WeeklyTopicsApiError.INVALID_URL)
        }
        return candidate
    }

    private fun validate(statusCode: Int) {
        when (statusCode) {
            in 200..299 -> Unit
            401, 403 -> throw WeeklyTopicsApiException(
                WeeklyTopicsApiError.UNAUTHORIZED,
                statusCode,
            )
            404 -> throw WeeklyTopicsApiException(WeeklyTopicsApiError.NOT_FOUND, statusCode)
            409 -> throw WeeklyTopicsApiException(WeeklyTopicsApiError.CONFLICT, statusCode)
            in 500..599 -> throw WeeklyTopicsApiException(WeeklyTopicsApiError.SERVER, statusCode)
            else -> throw WeeklyTopicsApiException(WeeklyTopicsApiError.INVALID_RESPONSE, statusCode)
        }
    }

    private fun encodePathSegment(value: String): String =
        URLEncoder.encode(value, StandardCharsets.UTF_8.toString()).replace("+", "%20")
}

internal class HttpUrlConnectionWeeklyTopicsTransport : WeeklyTopicsTransport {
    override suspend fun execute(request: WeeklyTopicsHttpRequest): WeeklyTopicsHttpResponse =
        withContext(Dispatchers.IO) {
            val connection = URL(request.url).openConnection() as HttpURLConnection
            try {
                connection.requestMethod = request.method
                connection.connectTimeout = 15_000
                connection.readTimeout = 30_000
                request.headers.forEach(connection::setRequestProperty)
                request.body?.let { body ->
                    connection.doOutput = true
                    connection.outputStream.bufferedWriter().use { writer -> writer.write(body) }
                }
                val statusCode = connection.responseCode
                val stream = if (statusCode in 200..299) {
                    connection.inputStream
                } else {
                    connection.errorStream
                }
                WeeklyTopicsHttpResponse(
                    statusCode = statusCode,
                    body = stream?.bufferedReader()?.use { it.readText() }.orEmpty(),
                )
            } finally {
                connection.disconnect()
            }
        }
}

fun defaultWeeklyTopicsJson(): Json = Json {
    ignoreUnknownKeys = true
    explicitNulls = false
}
