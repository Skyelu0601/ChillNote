package com.sponteoai.chillscript.analytics

import com.sponteoai.chillscript.data.remote.SyncHttpException
import com.sponteoai.chillscript.data.remote.AIInvalidResponseException
import kotlinx.coroutines.CancellationException
import kotlinx.serialization.SerializationException
import java.io.IOException
import java.net.SocketTimeoutException

/** Never attach exception messages, response bodies, or user content. */
data class AIFailureAnalytics(
    val outcome: String,
    val code: String,
    val category: String,
    val httpStatus: Int? = null,
) {
    val properties: Map<String, Any> get() = buildMap {
        put("diagnostic_schema", 2)
        put("error_code", code)
        put("error_category", category)
        put("error_stage", if (category == "response") "response" else "request")
        httpStatus?.let { put("http_status", it) }
    }

    companion object {
        fun classify(error: Throwable): AIFailureAnalytics = when (error) {
            is CancellationException -> AIFailureAnalytics("cancelled", "request_cancelled", "cancelled")
            is SyncHttpException -> when (val status = error.statusCode) {
                402 -> AIFailureAnalytics("blocked", "insufficient_credits", "credits", status)
                429 -> AIFailureAnalytics("blocked", "rate_limited", "rate_limit", status)
                401 -> AIFailureAnalytics("blocked", "authentication_required", "authentication", status)
                403 -> AIFailureAnalytics("blocked", "access_denied", "authorization", status)
                else -> AIFailureAnalytics("failed", if (status >= 500) "server_error" else "http_error", "http", status)
            }
            is SocketTimeoutException -> AIFailureAnalytics("failed", "network_timeout", "network")
            is IOException -> AIFailureAnalytics("failed", "network_error", "network")
            is SerializationException, is AIInvalidResponseException -> AIFailureAnalytics("failed", "invalid_response", "response")
            else -> AIFailureAnalytics("failed", "unknown_error", "unknown")
        }
    }
}
