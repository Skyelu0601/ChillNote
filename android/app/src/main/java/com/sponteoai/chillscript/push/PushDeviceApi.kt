package com.sponteoai.chillscript.push

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

interface PushDeviceDataSource {
    suspend fun register(accessToken: String, payload: PushDeviceRegistrationPayload)
    suspend fun deactivate(accessToken: String, deviceToken: String)
}

enum class PushDeviceApiError(val retryable: Boolean) {
    INVALID_REQUEST(false),
    UNAUTHORIZED(false),
    RATE_LIMITED(true),
    NETWORK(true),
    SERVER(true),
}

class PushDeviceApiException(
    val reason: PushDeviceApiError,
    val statusCode: Int? = null,
    cause: Throwable? = null,
) : Exception("Push device request failed: $reason", cause)

internal data class PushDeviceHttpRequest(
    val method: String,
    val url: String,
    val headers: Map<String, String>,
    val body: String,
)

internal data class PushDeviceHttpResponse(val statusCode: Int)

internal fun interface PushDeviceTransport {
    suspend fun execute(request: PushDeviceHttpRequest): PushDeviceHttpResponse
}

class PushDeviceApi internal constructor(
    baseUrl: String,
    private val json: Json,
    private val transport: PushDeviceTransport,
) : PushDeviceDataSource {
    constructor(
        baseUrl: String = "https://api.chillnoteai.com",
        json: Json = Json { encodeDefaults = true; explicitNulls = false },
    ) : this(baseUrl, json, HttpUrlConnectionPushDeviceTransport())

    private val endpoint = "${baseUrl.trimEnd('/')}/push-devices"

    override suspend fun register(accessToken: String, payload: PushDeviceRegistrationPayload) {
        validateDeviceToken(payload.token)
        execute(
            accessToken = accessToken,
            method = "POST",
            body = json.encodeToString(payload),
        )
    }

    override suspend fun deactivate(accessToken: String, deviceToken: String) {
        validateDeviceToken(deviceToken)
        execute(
            accessToken = accessToken,
            method = "DELETE",
            body = json.encodeToString(mapOf("token" to deviceToken.trim())),
        )
    }

    private suspend fun execute(accessToken: String, method: String, body: String) {
        val token = accessToken.trim()
        if (token.isEmpty()) throw PushDeviceApiException(PushDeviceApiError.UNAUTHORIZED)
        val request = PushDeviceHttpRequest(
            method = method,
            url = endpoint,
            headers = mapOf(
                "Authorization" to "Bearer $token",
                "Accept" to "application/json",
                "Content-Type" to "application/json",
            ),
            body = body,
        )
        val response = try {
            transport.execute(request)
        } catch (error: CancellationException) {
            throw error
        } catch (error: PushDeviceApiException) {
            throw error
        } catch (error: IOException) {
            throw PushDeviceApiException(PushDeviceApiError.NETWORK, cause = error)
        } catch (error: Exception) {
            throw PushDeviceApiException(PushDeviceApiError.NETWORK, cause = error)
        }
        when (response.statusCode) {
            in 200..299 -> Unit
            400, 404, 409, 422 -> throw PushDeviceApiException(
                PushDeviceApiError.INVALID_REQUEST,
                response.statusCode,
            )
            401, 403 -> throw PushDeviceApiException(
                PushDeviceApiError.UNAUTHORIZED,
                response.statusCode,
            )
            408, 425, 429 -> throw PushDeviceApiException(
                PushDeviceApiError.RATE_LIMITED,
                response.statusCode,
            )
            in 500..599 -> throw PushDeviceApiException(
                PushDeviceApiError.SERVER,
                response.statusCode,
            )
            else -> throw PushDeviceApiException(
                PushDeviceApiError.INVALID_REQUEST,
                response.statusCode,
            )
        }
    }
}

internal fun validateDeviceToken(token: String) {
    val normalized = token.trim()
    if (normalized.length !in 20..4096 || normalized.any(Char::isWhitespace)) {
        throw PushDeviceApiException(PushDeviceApiError.INVALID_REQUEST)
    }
}

internal class HttpUrlConnectionPushDeviceTransport : PushDeviceTransport {
    override suspend fun execute(request: PushDeviceHttpRequest): PushDeviceHttpResponse =
        withContext(Dispatchers.IO) {
            val connection = URL(request.url).openConnection() as HttpURLConnection
            try {
                connection.requestMethod = request.method
                connection.connectTimeout = 15_000
                connection.readTimeout = 20_000
                connection.doOutput = true
                request.headers.forEach(connection::setRequestProperty)
                connection.outputStream.bufferedWriter().use { it.write(request.body) }
                val statusCode = connection.responseCode
                val stream = if (statusCode in 200..299) connection.inputStream else connection.errorStream
                stream?.close()
                PushDeviceHttpResponse(statusCode)
            } finally {
                connection.disconnect()
            }
        }
}
