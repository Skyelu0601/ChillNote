package com.sponteoai.chillscript.push

import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PushDeviceApiTest {
    @Test
    fun `registration sends Android model with bearer token`() = runTest {
        var captured: PushDeviceHttpRequest? = null
        val api = apiWithTransport { request ->
            captured = request
            PushDeviceHttpResponse(204)
        }

        api.register(
            accessToken = "access-token",
            payload = PushDeviceRegistrationPayload(
                token = validToken(),
                locale = "zh-CN",
                timeZone = "Asia/Shanghai",
                authorizationStatus = "authorized",
            ),
        )

        val request = requireNotNull(captured)
        assertEquals("POST", request.method)
        assertEquals("Bearer access-token", request.headers["Authorization"])
        val body = Json.parseToJsonElement(request.body).jsonObject
        assertEquals("android", body.getValue("platform").jsonPrimitive.content)
        assertEquals("production", body.getValue("environment").jsonPrimitive.content)
        assertEquals("Asia/Shanghai", body.getValue("timeZone").jsonPrimitive.content)
        assertEquals(validToken(), body.getValue("token").jsonPrimitive.content)
    }

    @Test
    fun `deactivation uses authenticated delete`() = runTest {
        var captured: PushDeviceHttpRequest? = null
        val api = apiWithTransport { request ->
            captured = request
            PushDeviceHttpResponse(204)
        }

        api.deactivate("session-token", validToken())

        val request = requireNotNull(captured)
        assertEquals("DELETE", request.method)
        assertEquals("Bearer session-token", request.headers["Authorization"])
        assertEquals(
            validToken(),
            Json.parseToJsonElement(request.body).jsonObject.getValue("token").jsonPrimitive.content,
        )
    }

    @Test
    fun `unauthorized and server errors keep retry semantics distinct`() = runTest {
        val unauthorized = runCatching {
            apiWithStatus(401).register("token", payload())
        }.exceptionOrNull() as PushDeviceApiException
        val server = runCatching {
            apiWithStatus(503).register("token", payload())
        }.exceptionOrNull() as PushDeviceApiException

        assertEquals(PushDeviceApiError.UNAUTHORIZED, unauthorized.reason)
        assertFalse(unauthorized.reason.retryable)
        assertEquals(PushDeviceApiError.SERVER, server.reason)
        assertTrue(server.reason.retryable)
    }

    @Test
    fun `invalid FCM token is rejected before transport`() = runTest {
        var called = false
        val api = apiWithTransport {
            called = true
            PushDeviceHttpResponse(204)
        }

        val error = runCatching {
            api.register("access-token", payload(token = "contains whitespace"))
        }.exceptionOrNull() as PushDeviceApiException

        assertEquals(PushDeviceApiError.INVALID_REQUEST, error.reason)
        assertFalse(called)
    }

    private fun apiWithStatus(status: Int) = apiWithTransport { PushDeviceHttpResponse(status) }

    private fun apiWithTransport(block: suspend (PushDeviceHttpRequest) -> PushDeviceHttpResponse) =
        PushDeviceApi(
            baseUrl = "https://example.test",
            json = Json { encodeDefaults = true; explicitNulls = false },
            transport = PushDeviceTransport(block),
        )

    private fun payload(token: String = validToken()) = PushDeviceRegistrationPayload(
        token = token,
        locale = "en-US",
        timeZone = "UTC",
        authorizationStatus = "authorized",
    )

    private fun validToken() = "fcm-registration-token_1234567890"
}
