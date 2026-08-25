package com.sponteoai.chillscript.auth

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import com.sponteoai.chillscript.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.contentOrNull
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL
import android.net.Uri
import java.security.KeyStore
import java.util.concurrent.atomic.AtomicLong
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

@Serializable
data class AuthUser(
    val id: String,
    val email: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
)

@Serializable
data class AuthSession(
    @SerialName("access_token") val accessToken: String,
    @SerialName("refresh_token") val refreshToken: String,
    @SerialName("expires_in") val expiresIn: Long,
    @SerialName("expires_at") val expiresAt: Long? = null,
    val user: AuthUser,
)

@Serializable
private data class PkceTokenExchange(
    @SerialName("auth_code") val authCode: String,
    @SerialName("code_verifier") val codeVerifier: String,
)

private data class PendingOAuthExchange(
    val authorizationCode: String,
    val codeVerifier: String,
)

sealed interface AuthState {
    data object Checking : AuthState
    data object SignedOut : AuthState
    data class SignedIn(val session: AuthSession) : AuthState
}

class AuthRepository(context: Context) {
    private val sessionStorage = SecureSessionStorage(context.applicationContext)
    private val json = Json { ignoreUnknownKeys = true; explicitNulls = false }
    private val oauthStorage = SecureOAuthPendingStorage(context.applicationContext, json)
    private val oauthLock = Any()

    private val appReviewEmails: Set<String> by lazy {
        BuildConfig.APP_REVIEW_WHITELIST_EMAILS
            .split(',')
            .map { it.trim().lowercase() }
            .filter { it.isNotEmpty() }
            .toSet()
    }

    private fun isAppReviewEmail(email: String): Boolean =
        BuildConfig.APP_REVIEW_LOGIN_ENABLED && email.trim().lowercase() in appReviewEmails

    fun restoreSession(): AuthSession? {
        val raw = sessionStorage.read() ?: return null
        return runCatching { json.decodeFromString(AuthSession.serializer(), raw) }.getOrNull()
    }

    suspend fun sendEmailCode(email: String) {
        if (isAppReviewEmail(email)) return
        request(
            path = "/auth/v1/otp",
            body = "{\"email\":${json.encodeToString(email.trim().lowercase())},\"create_user\":true}",
            decode = { Unit },
        )
    }

    suspend fun verifyEmailCode(email: String, code: String): AuthSession {
        val normalizedEmail = email.trim().lowercase()
        val normalizedCode = code.trim()
        if (isAppReviewEmail(normalizedEmail) && normalizedCode == BuildConfig.APP_REVIEW_VERIFICATION_CODE) {
            val passwordBody = "{\"email\":${json.encodeToString(normalizedEmail)}," +
                "\"password\":${json.encodeToString(normalizedCode)}}"
            return request("/auth/v1/token?grant_type=password", passwordBody) {
                json.decodeFromString(AuthSession.serializer(), it)
            }.also(::saveSession)
        }
        val body = "{\"type\":\"email\",\"email\":${json.encodeToString(email.trim().lowercase())}," +
            "\"token\":${json.encodeToString(code.trim())}}"
        return request("/auth/v1/verify", body) { json.decodeFromString(AuthSession.serializer(), it) }
            .also(::saveSession)
    }

    suspend fun signInWithGoogleIdToken(idToken: String): AuthSession {
        val body = "{\"provider\":\"google\",\"id_token\":${json.encodeToString(idToken)}}"
        return request("/auth/v1/token?grant_type=id_token", body) {
            json.decodeFromString(AuthSession.serializer(), it)
        }.also(::saveSession)
    }

    /**
     * Creates a fresh, single-use Apple OAuth request and persists only the PKCE verifier and
     * callback correlation id. The browser never receives the verifier.
     */
    fun beginAppleOAuth(): Uri = synchronized(oauthLock) {
        val launch = OAuthPkceProtocol.createLaunch(
            supabaseUrl = BuildConfig.SUPABASE_URL,
            provider = "apple",
            redirectBaseUri = BuildConfig.AUTH_REDIRECT_URI,
        )
        oauthStorage.write(launch.pending)
        Uri.parse(launch.authorizationUri.toASCIIString())
    }

    suspend fun importOAuthCallback(uri: Uri): AuthSession {
        val exchange = synchronized(oauthLock) {
            val pending = oauthStorage.read()
                ?: throw OAuthPkceException("There is no pending OAuth request")
            val callback = runCatching { URI.create(uri.toString()) }
                .getOrElse { throw OAuthPkceException("Invalid OAuth callback URI") }
            val result = OAuthPkceProtocol.validateCallback(callback, pending)

            // Consume before the network exchange. A callback (including a provider-declined
            // callback) can therefore never be replayed, even if the process receives it twice.
            oauthStorage.clear()
            when (result) {
                is OAuthPkceCallback.AuthorizationCode -> PendingOAuthExchange(
                    authorizationCode = result.value,
                    codeVerifier = pending.codeVerifier,
                )
                is OAuthPkceCallback.ProviderError -> {
                    if (result.code.equals("access_denied", ignoreCase = true)) {
                        throw AuthCancelledException()
                    }
                    throw AuthException(
                        statusCode = 400,
                        errorCode = result.code,
                    )
                }
            }
        }
        val body = json.encodeToString(
            PkceTokenExchange.serializer(),
            PkceTokenExchange(exchange.authorizationCode, exchange.codeVerifier),
        )
        return request("/auth/v1/token?grant_type=pkce", body) {
            json.decodeFromString(AuthSession.serializer(), it)
        }.also(::saveSession)
    }

    suspend fun refresh(session: AuthSession): AuthSession = refreshMutex.withLock {
        val refreshGeneration = sessionGeneration.get()
        val stored = restoreSession() ?: throw AuthSessionUnavailableException()
        if (stored.user.id != session.user.id) throw AuthSessionUnavailableException()
        if (stored.accessToken != session.accessToken) return@withLock stored

        val body = "{\"refresh_token\":${json.encodeToString(stored.refreshToken)}}"
        val refreshed = request("/auth/v1/token?grant_type=refresh_token", body) {
            json.decodeFromString(AuthSession.serializer(), it)
        }
        if (sessionGeneration.get() != refreshGeneration) throw AuthSessionUnavailableException()
        saveSession(refreshed)
        refreshed
    }

    fun signOut() {
        sessionGeneration.incrementAndGet()
        sessionStorage.clear()
        synchronized(oauthLock) { oauthStorage.clear() }
    }

    private fun saveSession(session: AuthSession) {
        sessionStorage.write(json.encodeToString(AuthSession.serializer(), session))
    }

    private suspend fun <T> request(path: String, body: String, decode: (String) -> T): T = withContext(Dispatchers.IO) {
        val connection = URL(BuildConfig.SUPABASE_URL + path).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 15_000
            connection.readTimeout = 20_000
            connection.doOutput = true
            connection.setRequestProperty("apikey", BuildConfig.SUPABASE_ANON_KEY)
            connection.setRequestProperty("Authorization", "Bearer ${BuildConfig.SUPABASE_ANON_KEY}")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.outputStream.bufferedWriter().use { it.write(body) }
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val response = stream?.bufferedReader()?.use { it.readText() }.orEmpty()
            if (status !in 200..299) {
                throw AuthException(status, parseAuthErrorCode(response))
            }
            decode(response)
        } finally {
            connection.disconnect()
        }
    }

    private companion object {
        val refreshMutex = Mutex()
        val sessionGeneration = AtomicLong(0L)
    }

    private fun parseAuthErrorCode(response: String): String? = runCatching {
        val payload = json.parseToJsonElement(response).jsonObject
        sequenceOf("error_code", "code")
            .mapNotNull { key -> payload[key]?.jsonPrimitive?.contentOrNull }
            .firstOrNull(String::isNotBlank)
    }.getOrNull()

}

private class SecureSessionStorage(private val context: Context) {
    private val preferences: SharedPreferences =
        context.getSharedPreferences(SECURE_PREFERENCES_NAME, Context.MODE_PRIVATE)

    fun read(): String? {
        migrateLegacySessionIfNeeded()
        val encoded = preferences.getString(KEY_CIPHERTEXT, null) ?: return null
        return runCatching { decrypt(encoded) }
            .onFailure { clear() }
            .getOrNull()
    }

    fun write(value: String) {
        preferences.edit().putString(KEY_CIPHERTEXT, encrypt(value)).apply()
    }

    fun clear() {
        preferences.edit().remove(KEY_CIPHERTEXT).apply()
        context.getSharedPreferences(LEGACY_PREFERENCES_NAME, Context.MODE_PRIVATE)
            .edit().remove(LEGACY_SESSION_KEY).apply()
    }

    private fun migrateLegacySessionIfNeeded() {
        if (preferences.contains(KEY_CIPHERTEXT)) return
        val legacy = context.getSharedPreferences(LEGACY_PREFERENCES_NAME, Context.MODE_PRIVATE)
        val rawSession = legacy.getString(LEGACY_SESSION_KEY, null) ?: return
        write(rawSession)
        legacy.edit().remove(LEGACY_SESSION_KEY).apply()
    }

    private fun encrypt(value: String): String {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey())
        val ciphertext = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        return Base64.encodeToString(cipher.iv, Base64.NO_WRAP) + SEPARATOR +
            Base64.encodeToString(ciphertext, Base64.NO_WRAP)
    }

    private fun decrypt(encoded: String): String {
        val parts = encoded.split(SEPARATOR, limit = 2)
        require(parts.size == 2) { "Invalid encrypted session" }
        val iv = Base64.decode(parts[0], Base64.NO_WRAP)
        val ciphertext = Base64.decode(parts[1], Base64.NO_WRAP)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, getOrCreateKey(), GCMParameterSpec(GCM_TAG_BITS, iv))
        return cipher.doFinal(ciphertext).toString(Charsets.UTF_8)
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
        const val KEY_ALIAS = "chillscript.auth.session.v1"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val GCM_TAG_BITS = 128
        const val SEPARATOR = ":"
        const val SECURE_PREFERENCES_NAME = "auth_session_secure"
        const val KEY_CIPHERTEXT = "session_ciphertext"
        const val LEGACY_PREFERENCES_NAME = "auth_session"
        const val LEGACY_SESSION_KEY = "session"
    }
}

class AuthException(
    val statusCode: Int,
    val errorCode: String? = null,
) : Exception(
    buildString {
        append("Authentication failed (")
        append(statusCode)
        errorCode?.takeIf(String::isNotBlank)?.let { append(", ").append(it) }
        append(')')
    },
)

class AuthSessionUnavailableException : Exception("Stored authentication session is unavailable")
