package com.sponteoai.chillscript.auth

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.net.URI
import java.net.URLDecoder
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.security.KeyStore
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

@Serializable
internal data class PendingOAuthPkce(
    val requestId: String,
    val codeVerifier: String,
    val redirectBaseUri: String,
    val createdAtEpochMillis: Long,
)

internal data class OAuthPkceLaunch(
    val authorizationUri: URI,
    val pending: PendingOAuthPkce,
)

internal sealed interface OAuthPkceCallback {
    data class AuthorizationCode(val value: String) : OAuthPkceCallback
    data class ProviderError(val code: String, val description: String?) : OAuthPkceCallback
}

internal class OAuthPkceException(message: String) : Exception(message)

/**
 * Pure PKCE protocol helpers. Keeping these independent from Android URI APIs makes the
 * security-sensitive parsing deterministic and unit-testable on the JVM.
 */
internal object OAuthPkceProtocol {
    const val REQUEST_ID_PARAMETER = "oauth_request_id"
    const val MAX_PENDING_AGE_MILLIS = 10 * 60 * 1_000L
    private const val MAX_CALLBACK_VALUE_LENGTH = 8_192
    private val callbackParameters = setOf(
        REQUEST_ID_PARAMETER,
        "code",
        "error",
        "error_code",
        "error_description",
    )

    fun createLaunch(
        supabaseUrl: String,
        provider: String,
        redirectBaseUri: String,
        nowEpochMillis: Long = System.currentTimeMillis(),
        secureRandom: SecureRandom = SecureRandom(),
    ): OAuthPkceLaunch {
        require(provider.matches(Regex("^[A-Za-z0-9]+$"))) { "Invalid OAuth provider" }
        val supabase = validatedSupabaseBaseUri(supabaseUrl)
        val redirect = validatedRedirectBaseUri(redirectBaseUri)
        val requestId = randomBase64Url(secureRandom)
        val verifier = randomBase64Url(secureRandom)
        val callbackUri = redirect.toASCIIString() + "?" +
            encodeQueryComponent(REQUEST_ID_PARAMETER) + "=" + encodeQueryComponent(requestId)
        val challenge = codeChallenge(verifier)
        val authorizeEndpoint = supabase.toASCIIString().trimEnd('/') + "/auth/v1/authorize"
        val authorizeQuery = listOf(
            "provider" to provider,
            "redirect_to" to callbackUri,
            "code_challenge" to challenge,
            "code_challenge_method" to "s256",
        ).joinToString("&") { (key, value) ->
            "${encodeQueryComponent(key)}=${encodeQueryComponent(value)}"
        }
        return OAuthPkceLaunch(
            authorizationUri = URI.create("$authorizeEndpoint?$authorizeQuery"),
            pending = PendingOAuthPkce(
                requestId = requestId,
                codeVerifier = verifier,
                redirectBaseUri = redirect.toASCIIString(),
                createdAtEpochMillis = nowEpochMillis,
            ),
        )
    }

    fun validateCallback(
        callbackUri: URI,
        pending: PendingOAuthPkce,
        nowEpochMillis: Long = System.currentTimeMillis(),
    ): OAuthPkceCallback {
        if (callbackUri.rawFragment != null) {
            throw OAuthPkceException("OAuth callbacks must not contain a URI fragment")
        }
        val expectedTarget = validatedRedirectBaseUri(pending.redirectBaseUri)
        validateExactCallbackTarget(callbackUri, expectedTarget)
        val parameters = parseUniqueQuery(callbackUri.rawQuery)
        if (parameters.keys.any { it.equals("access_token", true) || it.equals("refresh_token", true) }) {
            throw OAuthPkceException("OAuth callback attempted to deliver session tokens")
        }
        if (parameters.keys.any { it !in callbackParameters }) {
            throw OAuthPkceException("OAuth callback contains an unexpected parameter")
        }
        val callbackRequestId = parameters[REQUEST_ID_PARAMETER]
            ?: throw OAuthPkceException("OAuth callback is missing its request identifier")
        if (!constantTimeEquals(callbackRequestId, pending.requestId)) {
            throw OAuthPkceException("OAuth callback does not match the pending request")
        }
        if (nowEpochMillis < pending.createdAtEpochMillis ||
            nowEpochMillis - pending.createdAtEpochMillis > MAX_PENDING_AGE_MILLIS
        ) {
            throw OAuthPkceException("The pending OAuth request has expired")
        }

        val providerErrorCode = parameters["error"] ?: parameters["error_code"]
        if (!providerErrorCode.isNullOrBlank()) {
            return OAuthPkceCallback.ProviderError(
                code = providerErrorCode.take(MAX_CALLBACK_VALUE_LENGTH),
                description = parameters["error_description"]?.take(MAX_CALLBACK_VALUE_LENGTH),
            )
        }
        val code = parameters["code"]
            ?.takeIf { it.isNotBlank() && it.length <= MAX_CALLBACK_VALUE_LENGTH }
            ?: throw OAuthPkceException("OAuth callback is missing a valid authorization code")
        return OAuthPkceCallback.AuthorizationCode(code)
    }

    internal fun codeChallenge(codeVerifier: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(codeVerifier.toByteArray(StandardCharsets.US_ASCII))
        return Base64.getUrlEncoder().withoutPadding().encodeToString(digest)
    }

    private fun randomBase64Url(secureRandom: SecureRandom): String =
        ByteArray(32).also(secureRandom::nextBytes).let {
            Base64.getUrlEncoder().withoutPadding().encodeToString(it)
        }

    private fun validatedSupabaseBaseUri(value: String): URI {
        val uri = runCatching { URI.create(value) }
            .getOrElse { throw OAuthPkceException("Invalid Supabase URL") }
        if (!uri.scheme.equals("https", true) || uri.host.isNullOrBlank() || uri.userInfo != null ||
            uri.rawQuery != null || uri.rawFragment != null || uri.port !in setOf(-1, 443) ||
            uri.rawPath.orEmpty() !in setOf("", "/")
        ) {
            throw OAuthPkceException("Supabase URL must be a plain HTTPS origin")
        }
        return uri
    }

    private fun validatedRedirectBaseUri(value: String): URI {
        val uri = runCatching { URI.create(value) }
            .getOrElse { throw OAuthPkceException("Invalid OAuth redirect URI") }
        val isHttps = uri.scheme.equals("https", true) && uri.port in setOf(-1, 443)
        val isPrivateScheme = uri.scheme.equals("chillscript", true) && uri.port == -1
        if (uri.isOpaque || (!isHttps && !isPrivateScheme) || uri.host.isNullOrBlank() ||
            uri.userInfo != null || uri.rawQuery != null || uri.rawFragment != null
        ) {
            throw OAuthPkceException("OAuth redirect URI is not an allowed callback target")
        }
        return uri
    }

    private fun validateExactCallbackTarget(callback: URI, expected: URI) {
        val sameTarget = !callback.isOpaque &&
            callback.scheme.equals(expected.scheme, true) &&
            callback.host.equals(expected.host, true) &&
            callback.port == expected.port &&
            callback.rawPath.orEmpty() == expected.rawPath.orEmpty() &&
            callback.userInfo == null
        if (!sameTarget) throw OAuthPkceException("OAuth callback target does not match")
    }

    private fun parseUniqueQuery(rawQuery: String?): Map<String, String> {
        if (rawQuery.isNullOrEmpty()) return emptyMap()
        val result = linkedMapOf<String, String>()
        rawQuery.split('&').forEach { part ->
            if (part.isEmpty()) throw OAuthPkceException("OAuth callback has an invalid query")
            val separator = part.indexOf('=')
            val rawName = if (separator >= 0) part.substring(0, separator) else part
            val rawValue = if (separator >= 0) part.substring(separator + 1) else ""
            val name = decodeQueryComponent(rawName)
            val value = decodeQueryComponent(rawValue)
            if (result.put(name, value) != null) {
                throw OAuthPkceException("OAuth callback contains a duplicate parameter")
            }
        }
        return result
    }

    private fun constantTimeEquals(left: String, right: String): Boolean =
        MessageDigest.isEqual(
            left.toByteArray(StandardCharsets.UTF_8),
            right.toByteArray(StandardCharsets.UTF_8),
        )

    private fun encodeQueryComponent(value: String): String =
        URLEncoder.encode(value, StandardCharsets.UTF_8.name()).replace("+", "%20")

    private fun decodeQueryComponent(value: String): String = runCatching {
        URLDecoder.decode(value, StandardCharsets.UTF_8.name())
    }.getOrElse { throw OAuthPkceException("OAuth callback contains invalid percent encoding") }
}

internal class SecureOAuthPendingStorage(
    context: Context,
    private val json: Json,
) {
    private val preferences: SharedPreferences =
        context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

    fun read(): PendingOAuthPkce? {
        val encoded = preferences.getString(KEY_CIPHERTEXT, null) ?: return null
        return runCatching {
            json.decodeFromString(PendingOAuthPkce.serializer(), decrypt(encoded))
        }.onFailure { clear() }.getOrNull()
    }

    fun write(pending: PendingOAuthPkce) {
        val encoded = encrypt(json.encodeToString(PendingOAuthPkce.serializer(), pending))
        check(preferences.edit().putString(KEY_CIPHERTEXT, encoded).commit()) {
            "Could not persist the pending OAuth request"
        }
    }

    fun clear() {
        preferences.edit().remove(KEY_CIPHERTEXT).commit()
    }

    private fun encrypt(value: String): String {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey())
        cipher.updateAAD(AUTHENTICATED_DATA)
        val ciphertext = cipher.doFinal(value.toByteArray(StandardCharsets.UTF_8))
        return Base64.getEncoder().encodeToString(cipher.iv) + SEPARATOR +
            Base64.getEncoder().encodeToString(ciphertext)
    }

    private fun decrypt(encoded: String): String {
        val parts = encoded.split(SEPARATOR, limit = 2)
        require(parts.size == 2) { "Invalid encrypted OAuth request" }
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(
            Cipher.DECRYPT_MODE,
            getOrCreateKey(),
            GCMParameterSpec(GCM_TAG_BITS, Base64.getDecoder().decode(parts[0])),
        )
        cipher.updateAAD(AUTHENTICATED_DATA)
        return String(cipher.doFinal(Base64.getDecoder().decode(parts[1])), StandardCharsets.UTF_8)
    }

    private fun getOrCreateKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEY_STORE).apply { load(null) }
        (keyStore.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEY_STORE)
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return generator.generateKey()
    }

    private companion object {
        const val ANDROID_KEY_STORE = "AndroidKeyStore"
        const val KEY_ALIAS = "chillscript.auth.oauth.pending.v1"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val GCM_TAG_BITS = 128
        const val SEPARATOR = ":"
        const val PREFERENCES_NAME = "auth_oauth_secure"
        const val KEY_CIPHERTEXT = "pending_ciphertext"
        val AUTHENTICATED_DATA = "chillscript.auth.oauth.pending.v1".toByteArray(StandardCharsets.UTF_8)
    }
}
