package com.sponteoai.chillscript.ai

import android.content.Context
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

enum class AIConsentTrigger { Audio, Text }

data class AIConsentPrompt(val trigger: AIConsentTrigger)

class AIConsentManager(context: Context) {
    private val preferences = context.getSharedPreferences("ai_data_consent", Context.MODE_PRIVATE)
    private val mutablePrompt = MutableStateFlow<AIConsentPrompt?>(null)
    val prompt: StateFlow<AIConsentPrompt?> = mutablePrompt.asStateFlow()
    private val pendingRequests = mutableListOf<CompletableDeferred<Boolean>>()

    fun hasAcceptedCurrentVersion(): Boolean =
        preferences.getString(KEY_ACCEPTED_VERSION, null) == CURRENT_VERSION

    suspend fun ensureConsent(trigger: AIConsentTrigger): Boolean {
        if (hasAcceptedCurrentVersion()) return true
        val request = CompletableDeferred<Boolean>()
        synchronized(pendingRequests) {
            pendingRequests += request
            if (mutablePrompt.value == null) mutablePrompt.value = AIConsentPrompt(trigger)
        }
        return request.await()
    }

    fun accept() {
        preferences.edit()
            .putString(KEY_ACCEPTED_VERSION, CURRENT_VERSION)
            .putLong(KEY_ACCEPTED_AT, System.currentTimeMillis())
            .apply()
        completePendingRequests(true)
    }

    fun decline() = completePendingRequests(false)

    private fun completePendingRequests(accepted: Boolean) {
        val requests = synchronized(pendingRequests) {
            mutablePrompt.value = null
            pendingRequests.toList().also { pendingRequests.clear() }
        }
        requests.forEach { it.complete(accepted) }
    }

    companion object {
        const val CURRENT_VERSION = "v1"
        private const val KEY_ACCEPTED_VERSION = "ai_data_consent_version_accepted"
        private const val KEY_ACCEPTED_AT = "ai_data_consent_accepted_at"
    }
}
