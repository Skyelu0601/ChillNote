package com.sponteoai.chillscript.ai

import android.content.Context
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import com.sponteoai.chillscript.analytics.ProductAnalytics
import java.util.UUID

enum class AIConsentTrigger { Audio, Text }

data class AIConsentPrompt(val trigger: AIConsentTrigger, val id: UUID = UUID.randomUUID())

internal interface AIConsentStore {
    fun acceptedVersion(): String?
    fun accept(version: String)
}

class AIConsentManager internal constructor(
    private val store: AIConsentStore,
    private val capture: (String, Map<String, Any>) -> Unit = ProductAnalytics::capture,
) {
    constructor(context: Context) : this(object : AIConsentStore {
        private val preferences = context.getSharedPreferences("ai_data_consent", Context.MODE_PRIVATE)
        override fun acceptedVersion(): String? = preferences.getString(KEY_ACCEPTED_VERSION, null)
        override fun accept(version: String) {
            preferences.edit().putString(KEY_ACCEPTED_VERSION, version)
                .putLong(KEY_ACCEPTED_AT, System.currentTimeMillis()).apply()
        }
    })
    private val mutablePrompt = MutableStateFlow<AIConsentPrompt?>(null)
    val prompt: StateFlow<AIConsentPrompt?> = mutablePrompt.asStateFlow()
    private val pendingRequests = mutableListOf<CompletableDeferred<Boolean>>()

    fun hasAcceptedCurrentVersion(): Boolean =
        store.acceptedVersion() == CURRENT_VERSION

    suspend fun ensureConsent(trigger: AIConsentTrigger): Boolean {
        currentCoroutineContext().ensureActive()
        val request = CompletableDeferred<Boolean>()
        synchronized(pendingRequests) {
            if (hasAcceptedCurrentVersion()) return true
            pendingRequests += request
            if (mutablePrompt.value == null) {
                val prompt = AIConsentPrompt(trigger)
                mutablePrompt.value = prompt
                capture("ai_consent_prompted", properties(prompt))
            }
        }
        return try {
            request.await().also { currentCoroutineContext().ensureActive() }
        } finally {
            synchronized(pendingRequests) {
                pendingRequests.remove(request)
                if (pendingRequests.isEmpty()) mutablePrompt.value = null
            }
            request.cancel()
        }
    }

    fun accept(promptId: UUID? = null) = completePendingRequests(true, promptId)

    fun decline(promptId: UUID? = null) = completePendingRequests(false, promptId)

    private fun completePendingRequests(accepted: Boolean, promptId: UUID?) {
        val requests = synchronized(pendingRequests) {
            val prompt = mutablePrompt.value ?: return
            if (promptId != null && prompt.id != promptId) return
            if (accepted) store.accept(CURRENT_VERSION)
            capture(if (accepted) "ai_consent_accepted" else "ai_consent_declined", properties(prompt))
            mutablePrompt.value = null
            pendingRequests.toList().also { pendingRequests.clear() }
        }
        requests.forEach { it.complete(accepted) }
    }

    private fun properties(prompt: AIConsentPrompt): Map<String, Any> = mapOf(
        "trigger" to if (prompt.trigger == AIConsentTrigger.Audio) "audio" else "text",
        "consent_version" to CURRENT_VERSION,
        "diagnostic_schema" to 2,
    )

    companion object {
        const val CURRENT_VERSION = "v1"
        private const val KEY_ACCEPTED_VERSION = "ai_data_consent_version_accepted"
        private const val KEY_ACCEPTED_AT = "ai_data_consent_accepted_at"
    }
}
