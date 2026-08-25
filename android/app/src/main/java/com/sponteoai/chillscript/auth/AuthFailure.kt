package com.sponteoai.chillscript.auth

import java.io.IOException

internal enum class AuthOperation {
    SendEmailCode,
    VerifyEmailCode,
    GoogleSignIn,
    AppleSignIn,
}

internal enum class AuthFailure {
    Cancelled,
    Network,
    TooManyRequests,
    InvalidVerificationCode,
    SendCodeFailed,
    VerificationFailed,
    GoogleSignInFailed,
    AppleSignInFailed,
}

internal class AuthCancelledException : Exception("Authentication was cancelled")

internal fun classifyAuthFailure(operation: AuthOperation, error: Throwable): AuthFailure {
    if (error is AuthCancelledException) return AuthFailure.Cancelled
    if (error is IOException) return AuthFailure.Network

    val authError = error as? AuthException
    val code = authError?.errorCode.orEmpty().lowercase()
    val isRateLimited = authError?.statusCode == 429 || code in setOf(
        "over_email_send_rate_limit",
        "over_request_rate_limit",
        "over_sms_send_rate_limit",
    )
    if (isRateLimited) return AuthFailure.TooManyRequests

    return when (operation) {
        AuthOperation.SendEmailCode -> AuthFailure.SendCodeFailed
        AuthOperation.VerifyEmailCode -> {
            if (code == "otp_expired" || authError?.statusCode == 403) {
                AuthFailure.InvalidVerificationCode
            } else {
                AuthFailure.VerificationFailed
            }
        }
        AuthOperation.GoogleSignIn -> AuthFailure.GoogleSignInFailed
        AuthOperation.AppleSignIn -> AuthFailure.AppleSignInFailed
    }
}
