package com.sponteoai.chillscript.auth

import java.net.SocketTimeoutException
import org.junit.Assert.assertEquals
import org.junit.Test

class AuthFailureTest {
    @Test
    fun `maps a cancelled provider flow without showing an error`() {
        assertEquals(
            AuthFailure.Cancelled,
            classifyAuthFailure(AuthOperation.AppleSignIn, AuthCancelledException()),
        )
    }

    @Test
    fun `maps network failures consistently for every login method`() {
        AuthOperation.entries.forEach { operation ->
            assertEquals(
                AuthFailure.Network,
                classifyAuthFailure(operation, SocketTimeoutException()),
            )
        }
    }

    @Test
    fun `maps Supabase email rate limits to an actionable message`() {
        assertEquals(
            AuthFailure.TooManyRequests,
            classifyAuthFailure(
                AuthOperation.SendEmailCode,
                AuthException(429, "over_email_send_rate_limit"),
            ),
        )
    }

    @Test
    fun `maps expired and rejected verification codes`() {
        assertEquals(
            AuthFailure.InvalidVerificationCode,
            classifyAuthFailure(
                AuthOperation.VerifyEmailCode,
                AuthException(422, "otp_expired"),
            ),
        )
        assertEquals(
            AuthFailure.InvalidVerificationCode,
            classifyAuthFailure(AuthOperation.VerifyEmailCode, AuthException(403)),
        )
    }

    @Test
    fun `keeps provider and email fallback failures specific`() {
        assertEquals(
            AuthFailure.SendCodeFailed,
            classifyAuthFailure(AuthOperation.SendEmailCode, AuthException(500)),
        )
        assertEquals(
            AuthFailure.VerificationFailed,
            classifyAuthFailure(AuthOperation.VerifyEmailCode, AuthException(500)),
        )
        assertEquals(
            AuthFailure.GoogleSignInFailed,
            classifyAuthFailure(AuthOperation.GoogleSignIn, AuthException(400)),
        )
        assertEquals(
            AuthFailure.AppleSignInFailed,
            classifyAuthFailure(AuthOperation.AppleSignIn, AuthException(400)),
        )
    }
}
