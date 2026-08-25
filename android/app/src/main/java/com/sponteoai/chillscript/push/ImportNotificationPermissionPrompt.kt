package com.sponteoai.chillscript.push

import android.content.Context
import java.time.Duration
import java.time.Instant

class ImportNotificationPromptPreferences(context: Context) {
    private val preferences = context.applicationContext.getSharedPreferences(
        FILE_NAME,
        Context.MODE_PRIVATE,
    )

    fun hasSeen(userId: String): Boolean = preferences.getBoolean(key(userId), false)

    fun markSeen(userId: String) {
        preferences.edit().putBoolean(key(userId), true).apply()
    }

    private fun key(userId: String) = "import_permission_prompt_seen.$userId"

    private companion object {
        const val FILE_NAME = "notification_permission_prompts"
    }
}

internal data class ImportedContentCandidate(
    val sourceUrl: String?,
    val createdAt: String,
)

internal fun shouldOfferImportNotificationPrompt(
    alreadySeen: Boolean,
    firebaseConfigured: Boolean,
    notificationPermissionGranted: Boolean,
    candidates: List<ImportedContentCandidate>,
    now: Instant = Instant.now(),
): Boolean {
    if (alreadySeen || !firebaseConfigured || notificationPermissionGranted) return false
    val cutoff = now.minus(Duration.ofHours(24))
    return candidates.any { candidate ->
        if (candidate.sourceUrl.isNullOrBlank()) return@any false
        val createdAt = runCatching { Instant.parse(candidate.createdAt) }.getOrNull()
            ?: return@any false
        !createdAt.isBefore(cutoff)
    }
}
