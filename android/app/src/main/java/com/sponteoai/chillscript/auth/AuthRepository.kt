package com.sponteoai.chillscript.auth

import android.content.Context
import com.sponteoai.chillscript.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.net.HttpURLConnection
import java.net.URL
import android.net.Uri

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

sealed interface AuthState {
    data object Checking : AuthState
    data object SignedOut : AuthState
    data class SignedIn(val session: AuthSession) : AuthState
}

class AuthRepository(context: Context) {
    private val preferences = context.getSharedPreferences("auth_session", Context.MODE_PRIVATE)
    private val json = Json { ignoreUnknownKeys = true; explicitNulls = false }

    fun restoreSession(): AuthSession? {
        val raw = preferences.getString(KEY_SESSION, null) ?: return null
        return runCatching { json.decodeFromString(AuthSession.serializer(), raw) }.getOrNull()
    }

    suspend fun sendEmailCode(email: String) {
        request(
            path = "/auth/v1/otp",
            body = "{\"email\":${json.encodeToString(email.trim().lowercase())},\"create_user\":true}",
            decode = { Unit },
        )
    }

    suspend fun verifyEmailCode(email: String, code: String): AuthSession {
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

    suspend fun importOAuthCallback(uri: Uri): AuthSession {
        val values = buildMap {
            uri.fragment?.split('&')?.forEach { part ->
                val pieces = part.split('=', limit = 2)
                if (pieces.size == 2) put(Uri.decode(pieces[0]), Uri.decode(pieces[1]))
            }
            uri.queryParameterNames.forEach { name -> uri.getQueryParameter(name)?.let { put(name, it) } }
        }
        values["error_description"]?.let { throw AuthException(400, it) }
        val accessToken = requireNotNull(values["access_token"]) { "OAuth callback is missing access token" }
        val refreshToken = requireNotNull(values["refresh_token"]) { "OAuth callback is missing refresh token" }
        val expiresIn = values["expires_in"]?.toLongOrNull() ?: 3600L
        val user = fetchUser(accessToken)
        return AuthSession(
            accessToken, refreshToken, expiresIn,
            values["expires_at"]?.toLongOrNull() ?: (System.currentTimeMillis() / 1000L + expiresIn),
            user,
        ).also(::saveSession)
    }

    suspend fun refresh(session: AuthSession): AuthSession {
        val body = "{\"refresh_token\":${json.encodeToString(session.refreshToken)}}"
        return request("/auth/v1/token?grant_type=refresh_token", body) {
            json.decodeFromString(AuthSession.serializer(), it)
        }.also(::saveSession)
    }

    fun signOut() {
        preferences.edit().remove(KEY_SESSION).apply()
    }

    private fun saveSession(session: AuthSession) {
        preferences.edit().putString(KEY_SESSION, json.encodeToString(AuthSession.serializer(), session)).apply()
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
            if (status !in 200..299) throw AuthException(status, response)
            decode(response)
        } finally {
            connection.disconnect()
        }
    }

    private suspend fun fetchUser(accessToken: String): AuthUser = withContext(Dispatchers.IO) {
        val connection = URL(BuildConfig.SUPABASE_URL + "/auth/v1/user").openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "GET"
            connection.connectTimeout = 15_000
            connection.readTimeout = 20_000
            connection.setRequestProperty("apikey", BuildConfig.SUPABASE_ANON_KEY)
            connection.setRequestProperty("Authorization", "Bearer $accessToken")
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val response = stream?.bufferedReader()?.use { it.readText() }.orEmpty()
            if (status !in 200..299) throw AuthException(status, response)
            json.decodeFromString(AuthUser.serializer(), response)
        } finally { connection.disconnect() }
    }

    companion object { private const val KEY_SESSION = "session" }
}

class AuthException(val statusCode: Int, responseBody: String) :
    Exception(responseBody.takeIf { it.isNotBlank() } ?: "Authentication failed ($statusCode)")
