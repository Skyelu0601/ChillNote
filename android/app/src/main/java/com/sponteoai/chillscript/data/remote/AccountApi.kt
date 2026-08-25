package com.sponteoai.chillscript.data.remote

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.net.HttpURLConnection
import java.net.URL

@Serializable data class SubscriptionStatusResponse(
    val success: Boolean,
    val tier: String,
    val expiresAt: String? = null,
    val activeProductId: String? = null,
)

@Serializable data class CreditBalanceResponse(val balance: Int? = null, val tier: String? = null)
@Serializable data class CreditConsumeResponse(val balance: Int? = null, val tier: String? = null)

class AccountApi(
    private val baseUrl: String = "https://api.chillnoteai.com",
    private val json: Json = Json { ignoreUnknownKeys = true },
) {
    suspend fun subscriptionStatus(accessToken: String): SubscriptionStatusResponse =
        request("GET", "/subscription/status", accessToken) {
            json.decodeFromString(SubscriptionStatusResponse.serializer(), it)
        }

    suspend fun creditBalance(accessToken: String): CreditBalanceResponse =
        request("GET", "/credits/balance", accessToken) {
            json.decodeFromString(CreditBalanceResponse.serializer(), it)
        }

    suspend fun consumeImportCredits(accessToken: String): CreditConsumeResponse =
        consumeCredits(accessToken, "import")

    suspend fun consumeVoiceCredits(accessToken: String): CreditConsumeResponse =
        consumeCredits(accessToken, "voice")

    private suspend fun consumeCredits(accessToken: String, feature: String): CreditConsumeResponse =
        request(
            "POST",
            "/credits/consume",
            accessToken,
            json.encodeToString(CreditConsumeRequest.serializer(), CreditConsumeRequest(feature)),
        ) { json.decodeFromString(CreditConsumeResponse.serializer(), it) }

    suspend fun deleteAccount(accessToken: String) {
        request("DELETE", "/auth/account", accessToken) { Unit }
    }

    suspend fun verifyGooglePlayPurchase(
        accessToken: String,
        productId: String,
        purchaseToken: String,
    ): SubscriptionStatusResponse = request("POST", "/subscription/google/verify", accessToken, body =
        json.encodeToString(GooglePlayVerifyRequest.serializer(), GooglePlayVerifyRequest(productId, purchaseToken))) {
        json.decodeFromString(SubscriptionStatusResponse.serializer(), it)
    }

    private suspend fun <T> request(
        method: String, path: String, token: String, body: String? = null, decode: (String) -> T,
    ): T =
        withContext(Dispatchers.IO) {
            val connection = URL("${baseUrl.trimEnd('/')}$path").openConnection() as HttpURLConnection
            try {
                connection.requestMethod = method
                connection.connectTimeout = 15_000
                connection.readTimeout = 30_000
                connection.setRequestProperty("Authorization", "Bearer $token")
                connection.setRequestProperty("Accept", "application/json")
                if (body != null) {
                    connection.doOutput = true
                    connection.setRequestProperty("Content-Type", "application/json")
                    connection.outputStream.bufferedWriter().use { it.write(body) }
                }
                val status = connection.responseCode
                val stream = if (status in 200..299) connection.inputStream else connection.errorStream
                val body = stream?.bufferedReader()?.use { it.readText() }.orEmpty()
                if (status !in 200..299) throw SyncHttpException(status, body)
                decode(body)
            } finally { connection.disconnect() }
        }
}

@Serializable private data class GooglePlayVerifyRequest(val productId: String, val purchaseToken: String)
@Serializable private data class CreditConsumeRequest(val feature: String)
