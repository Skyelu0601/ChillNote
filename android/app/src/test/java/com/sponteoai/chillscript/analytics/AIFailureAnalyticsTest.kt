package com.sponteoai.chillscript.analytics

import com.sponteoai.chillscript.data.remote.SyncHttpException
import com.sponteoai.chillscript.data.remote.AIInvalidResponseException
import kotlinx.coroutines.CancellationException
import java.io.IOException
import java.net.SocketTimeoutException
import org.junit.Assert.*
import org.junit.Test

class AIFailureAnalyticsTest {
    @Test fun separatesRestrictionsCancellationAndTechnicalFailures() {
        val cases = listOf(
            Triple(SyncHttpException(402, "private"), "blocked", "insufficient_credits"),
            Triple(SyncHttpException(429, "private"), "blocked", "rate_limited"),
            Triple(SyncHttpException(401, "private"), "blocked", "authentication_required"),
            Triple(SyncHttpException(403, "private"), "blocked", "access_denied"),
            Triple(SyncHttpException(502, "private"), "failed", "server_error"),
            Triple(SocketTimeoutException("private"), "failed", "network_timeout"),
            Triple(IOException("private"), "failed", "network_error"),
            Triple(AIInvalidResponseException(), "failed", "invalid_response"),
            Triple(CancellationException("private"), "cancelled", "request_cancelled"),
        )
        cases.forEach { (error, outcome, code) ->
            val failure = AIFailureAnalytics.classify(error)
            assertEquals(outcome, failure.outcome)
            assertEquals(code, failure.code)
            assertFalse(failure.properties.toString().contains("private"))
        }
        assertEquals(502, AIFailureAnalytics.classify(SyncHttpException(502, "body")).properties["http_status"])
    }
}
