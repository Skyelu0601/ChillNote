package com.sponteoai.chillscript.auth

import java.net.URI
import java.net.URLDecoder
import java.nio.charset.StandardCharsets
import java.security.SecureRandom
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class OAuthPkceProtocolTest {
    @Test
    fun `uses the RFC 7636 S256 challenge`() {
        val verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        assertEquals(
            "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
            OAuthPkceProtocol.codeChallenge(verifier),
        )
    }

    @Test
    fun `authorization request contains PKCE and no session tokens`() {
        val launch = OAuthPkceProtocol.createLaunch(
            supabaseUrl = "https://project.supabase.co",
            provider = "apple",
            redirectBaseUri = "chillscript://auth-callback",
            nowEpochMillis = 1_000L,
            secureRandom = DeterministicSecureRandom(),
        )
        val authorizeParameters = queryParameters(launch.authorizationUri)
        val callback = URI.create(authorizeParameters.getValue("redirect_to"))
        val callbackParameters = queryParameters(callback)

        assertEquals("apple", authorizeParameters["provider"])
        assertEquals("s256", authorizeParameters["code_challenge_method"])
        assertEquals(43, authorizeParameters.getValue("code_challenge").length)
        assertEquals(launch.pending.requestId, callbackParameters[OAuthPkceProtocol.REQUEST_ID_PARAMETER])
        assertEquals(43, launch.pending.codeVerifier.length)
        assertFalse(launch.authorizationUri.toString().contains("access_token"))
        assertFalse(launch.authorizationUri.toString().contains("refresh_token"))
        assertFalse(launch.authorizationUri.toString().contains(launch.pending.codeVerifier))
    }

    @Test
    fun `accepts only a matching fresh query authorization code`() {
        val pending = pending()
        val callback = URI.create(
            "chillscript://auth-callback?oauth_request_id=${pending.requestId}&code=single-use-code",
        )

        assertEquals(
            OAuthPkceCallback.AuthorizationCode("single-use-code"),
            OAuthPkceProtocol.validateCallback(callback, pending, nowEpochMillis = 2_000L),
        )
    }

    @Test
    fun `returns a correlated provider error without accepting a code`() {
        val pending = pending()
        val callback = URI.create(
            "chillscript://auth-callback?oauth_request_id=${pending.requestId}" +
                "&error=access_denied&error_description=Cancelled",
        )

        assertEquals(
            OAuthPkceCallback.ProviderError("access_denied", "Cancelled"),
            OAuthPkceProtocol.validateCallback(callback, pending, nowEpochMillis = 2_000L),
        )
    }

    @Test
    fun `rejects implicit fragment tokens`() {
        val pending = pending()
        assertRejected(
            URI.create(
                "chillscript://auth-callback?oauth_request_id=${pending.requestId}" +
                    "#access_token=stolen&refresh_token=stolen",
            ),
            pending,
        )
    }

    @Test
    fun `rejects token delivery in query parameters`() {
        val pending = pending()
        assertRejected(
            URI.create(
                "chillscript://auth-callback?oauth_request_id=${pending.requestId}" +
                    "&access_token=stolen&code=code",
            ),
            pending,
        )
    }

    @Test
    fun `rejects mismatched request callback target and duplicate parameters`() {
        val pending = pending()
        listOf(
            URI.create("chillscript://other-host?oauth_request_id=${pending.requestId}&code=code"),
            URI.create("chillscript://auth-callback?oauth_request_id=wrong&code=code"),
            URI.create(
                "chillscript://auth-callback?oauth_request_id=${pending.requestId}" +
                    "&oauth_request_id=${pending.requestId}&code=code",
            ),
        ).forEach { assertRejected(it, pending) }
    }

    @Test
    fun `rejects expired pending request`() {
        val pending = pending()
        val callback = URI.create(
            "chillscript://auth-callback?oauth_request_id=${pending.requestId}&code=code",
        )
        assertRejected(
            callback,
            pending,
            nowEpochMillis = pending.createdAtEpochMillis + OAuthPkceProtocol.MAX_PENDING_AGE_MILLIS + 1,
        )
    }

    private fun pending() = PendingOAuthPkce(
        requestId = "request-id-with-enough-entropy-for-test",
        codeVerifier = "verifier-with-enough-entropy-for-test-only-123456789",
        redirectBaseUri = "chillscript://auth-callback",
        createdAtEpochMillis = 1_000L,
    )

    private fun assertRejected(
        callback: URI,
        pending: PendingOAuthPkce,
        nowEpochMillis: Long = 2_000L,
    ) {
        try {
            OAuthPkceProtocol.validateCallback(callback, pending, nowEpochMillis)
            fail("Expected OAuth callback rejection")
        } catch (expected: OAuthPkceException) {
            assertTrue(expected.message?.isNotBlank() == true)
        }
    }

    private fun queryParameters(uri: URI): Map<String, String> =
        uri.rawQuery.orEmpty().split('&').filter { it.isNotEmpty() }.associate { part ->
            val separator = part.indexOf('=')
            val key = if (separator >= 0) part.substring(0, separator) else part
            val value = if (separator >= 0) part.substring(separator + 1) else ""
            URLDecoder.decode(key, StandardCharsets.UTF_8.name()) to
                URLDecoder.decode(value, StandardCharsets.UTF_8.name())
        }

    private class DeterministicSecureRandom : SecureRandom() {
        private var counter = 1

        override fun nextBytes(bytes: ByteArray) {
            bytes.indices.forEach { index -> bytes[index] = (counter + index).toByte() }
            counter += bytes.size
        }
    }
}
