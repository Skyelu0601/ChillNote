package com.sponteoai.chillscript.weekly

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException

class WeeklyTopicsApiTest {
    @Test
    fun `dashboard sends bearer token and decodes response`() = runTest {
        val transport = RecordingTransport(responseBody = dashboardJson())
        val api = WeeklyTopicsApi(
            baseUrl = "https://example.com/",
            json = defaultWeeklyTopicsJson(),
            transport = transport,
        )

        val dashboard = api.dashboard("  access-token  ")

        assertTrue(dashboard.hasUnreadReport)
        assertEquals("https://example.com/weekly-topics/dashboard", transport.lastRequest?.url)
        assertEquals("GET", transport.lastRequest?.method)
        assertEquals("Bearer access-token", transport.lastRequest?.headers?.get("Authorization"))
        assertEquals("application/json", transport.lastRequest?.headers?.get("Accept"))
        assertNull(transport.lastRequest?.body)
    }

    @Test
    fun `settings update sends canonical json payload`() = runTest {
        val response = """
            {
              "enabled": true,
              "weekday": 4,
              "hour": 20,
              "minute": 15,
              "timeZone": "Asia/Shanghai",
              "locale": "zh-Hans",
              "lastPeriodEnd": null,
              "nextRunAt": "2026-08-27T12:15:00Z"
            }
        """.trimIndent()
        val transport = RecordingTransport(responseBody = response)
        val api = testApi(transport)

        api.updateSettings(
            accessToken = "token",
            payload = WeeklyTopicSettingsPayload(
                enabled = true,
                weekday = 4,
                hour = 20,
                minute = 15,
                timeZone = "Asia/Shanghai",
                locale = "zh-Hans",
            ),
        )

        val request = requireNotNull(transport.lastRequest)
        assertEquals("PUT", request.method)
        assertEquals("application/json", request.headers["Content-Type"])
        val body = requireNotNull(request.body)
        assertTrue(body.contains("\"weekday\":4"))
        assertTrue(body.contains("\"timeZone\":\"Asia/Shanghai\""))
    }

    @Test
    fun `history clamps limit and report id is path encoded`() = runTest {
        val transport = RecordingTransport(responseBody = "{\"reports\":[]}")
        val api = testApi(transport)

        assertTrue(api.reports("token", limit = 1000).isEmpty())
        assertEquals(
            "https://example.com/weekly-topics/reports?limit=52",
            transport.lastRequest?.url,
        )

        transport.responseBody = reportJson("report-id")
        api.report("token", "report id/one")
        assertEquals(
            "https://example.com/weekly-topics/reports/report%20id%2Fone",
            transport.lastRequest?.url,
        )
    }

    @Test
    fun `mark read accepts empty 204 response`() = runTest {
        val transport = RecordingTransport(statusCode = 204, responseBody = "")
        val api = testApi(transport)

        api.markRead("token", "report-1")

        assertEquals("POST", transport.lastRequest?.method)
        assertEquals(
            "https://example.com/weekly-topics/reports/report-1/read",
            transport.lastRequest?.url,
        )
    }

    @Test
    fun `regenerate maps conflict response without exposing response body`() = runTest {
        val transport = RecordingTransport(
            statusCode = 409,
            responseBody = "{\"error\":\"Regeneration limit reached\"}",
        )
        val api = testApi(transport)

        val error = captureApiFailure { api.regenerate("token", "report-1") }

        assertEquals(WeeklyTopicsApiError.CONFLICT, error.reason)
        assertEquals(409, error.statusCode)
        assertFalse(error.message.orEmpty().contains("Regeneration limit reached"))
    }

    @Test
    fun `authentication and server status codes map to semantic errors`() = runTest {
        val cases = listOf(
            401 to WeeklyTopicsApiError.UNAUTHORIZED,
            403 to WeeklyTopicsApiError.UNAUTHORIZED,
            404 to WeeklyTopicsApiError.NOT_FOUND,
            500 to WeeklyTopicsApiError.SERVER,
            418 to WeeklyTopicsApiError.INVALID_RESPONSE,
        )
        cases.forEach { (status, expected) ->
            val transport = RecordingTransport(statusCode = status, responseBody = "error")
            val error = captureApiFailure { testApi(transport).dashboard("token") }
            assertEquals(expected, error.reason)
            assertEquals(status, error.statusCode)
        }
    }

    @Test
    fun `network and malformed json failures map to stable errors`() = runTest {
        val networkTransport = WeeklyTopicsTransport { throw IOException("offline details") }
        val networkError = captureApiFailure { testApi(networkTransport).dashboard("token") }
        assertEquals(WeeklyTopicsApiError.NETWORK, networkError.reason)

        val invalidResponse = captureApiFailure {
            testApi(RecordingTransport(responseBody = "not-json")).dashboard("token")
        }
        assertEquals(WeeklyTopicsApiError.INVALID_RESPONSE, invalidResponse.reason)
    }

    @Test
    fun `blank token fails before transport is called`() = runTest {
        val transport = RecordingTransport(responseBody = dashboardJson())

        val error = captureApiFailure { testApi(transport).dashboard("   ") }

        assertEquals(WeeklyTopicsApiError.UNAUTHORIZED, error.reason)
        assertEquals(0, transport.callCount)
    }

    @Test
    fun `invalid base url maps to invalid url`() = runTest {
        val api = WeeklyTopicsApi(
            baseUrl = "not a url",
            json = defaultWeeklyTopicsJson(),
            transport = RecordingTransport(responseBody = dashboardJson()),
        )

        val error = captureApiFailure { api.dashboard("token") }

        assertEquals(WeeklyTopicsApiError.INVALID_URL, error.reason)
    }

    private fun testApi(transport: WeeklyTopicsTransport): WeeklyTopicsApi = WeeklyTopicsApi(
        baseUrl = "https://example.com",
        json = defaultWeeklyTopicsJson(),
        transport = transport,
    )
}

private class RecordingTransport(
    var statusCode: Int = 200,
    var responseBody: String,
) : WeeklyTopicsTransport {
    var lastRequest: WeeklyTopicsHttpRequest? = null
    var callCount: Int = 0

    override suspend fun execute(request: WeeklyTopicsHttpRequest): WeeklyTopicsHttpResponse {
        callCount += 1
        lastRequest = request
        return WeeklyTopicsHttpResponse(statusCode, responseBody)
    }
}

private suspend fun captureApiFailure(block: suspend () -> Unit): WeeklyTopicsApiException = try {
    block()
    throw AssertionError("Expected WeeklyTopicsApiException")
} catch (error: WeeklyTopicsApiException) {
    error
}
