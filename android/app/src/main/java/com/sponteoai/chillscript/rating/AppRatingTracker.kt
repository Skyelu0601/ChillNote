package com.sponteoai.chillscript.rating

import android.content.Context
import com.sponteoai.chillscript.analytics.ProductAnalytics
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.receiveAsFlow

class AppRatingTracker(
    context: Context,
    private val nowMillis: () -> Long = System::currentTimeMillis,
) {
    private val preferences = context.getSharedPreferences("app_rating", Context.MODE_PRIVATE)
    private val requestChannel = Channel<Unit>(capacity = 1)
    val requests: Flow<Unit> = requestChannel.receiveAsFlow()

    @Synchronized
    fun registerVoiceNote() = registerSuccessfulEvent("voice_note")

    @Synchronized
    fun registerCompletedLinkImport(noteId: String) {
        val counted = preferences.getStringSet(KEY_COUNTED_LINKS, emptySet()).orEmpty().toMutableSet()
        if (!counted.add(noteId)) return
        preferences.edit().putStringSet(KEY_COUNTED_LINKS, counted).apply()
        registerSuccessfulEvent("link_import")
    }

    private fun registerSuccessfulEvent(trigger: String) {
        val now = nowMillis()
        migrateLegacyScheduleIfNeeded(now)
        val count = preferences.getInt(KEY_COUNT, 0) + 1
        val recentAttempts = readAttemptDates().filter { now - it < RatingPromptPolicy.ATTEMPT_WINDOW_MILLIS }
        val lastAttemptEventCount = preferences.getInt(KEY_LAST_ATTEMPT_EVENT_COUNT, 0)
        val shouldRequest = RatingPromptPolicy.shouldRequest(
            successfulEventCount = count,
            attemptDatesMillis = recentAttempts,
            lastAttemptEventCount = lastAttemptEventCount,
            nowMillis = now,
        )

        val editor = preferences.edit()
            .putInt(KEY_COUNT, count)
            .putString(KEY_ATTEMPT_DATES, recentAttempts.joinToString(","))
        if (!shouldRequest) {
            editor.apply()
            return
        }

        val attemptIndex = recentAttempts.size + 1
        editor
            .putString(KEY_ATTEMPT_DATES, (recentAttempts + now).joinToString(","))
            .putInt(KEY_LAST_ATTEMPT_EVENT_COUNT, count)
            .apply()
        ProductAnalytics.capture(
            "rating_prompt_eligible",
            mapOf(
                "attempt_index" to attemptIndex,
                "successful_event_count" to count,
                "trigger" to trigger,
            ),
        )
        requestChannel.trySend(Unit)
    }

    private fun readAttemptDates(): List<Long> = preferences.getString(KEY_ATTEMPT_DATES, null)
        ?.split(',')
        ?.mapNotNull(String::toLongOrNull)
        .orEmpty()

    private fun migrateLegacyScheduleIfNeeded(now: Long) {
        if (preferences.getBoolean(KEY_SCHEDULE_MIGRATED, false)) return

        val editor = preferences.edit()
        if (readAttemptDates().isEmpty() && preferences.getBoolean(KEY_TRIGGERED, false)) {
            editor
                .putString(KEY_ATTEMPT_DATES, (now - RatingPromptPolicy.REPEAT_INTERVAL_MILLIS).toString())
                .putInt(KEY_LAST_ATTEMPT_EVENT_COUNT, preferences.getInt(KEY_COUNT, 0))
        }
        editor.putBoolean(KEY_SCHEDULE_MIGRATED, true).apply()
    }

    private companion object {
        const val KEY_COUNT = "successful_event_count"
        const val KEY_TRIGGERED = "has_triggered_prompt"
        const val KEY_COUNTED_LINKS = "counted_link_import_ids"
        const val KEY_ATTEMPT_DATES = "prompt_attempt_dates"
        const val KEY_LAST_ATTEMPT_EVENT_COUNT = "last_prompt_event_count"
        const val KEY_SCHEDULE_MIGRATED = "did_migrate_prompt_schedule"
    }
}

internal object RatingPromptPolicy {
    const val REPEAT_INTERVAL_MILLIS = 30L * 24 * 60 * 60 * 1_000
    const val ATTEMPT_WINDOW_MILLIS = 365L * 24 * 60 * 60 * 1_000
    const val ADDITIONAL_EVENTS_FOR_RETRY = 3
    const val MAXIMUM_ATTEMPTS_PER_WINDOW = 3

    fun shouldRequest(
        successfulEventCount: Int,
        attemptDatesMillis: List<Long>,
        lastAttemptEventCount: Int,
        nowMillis: Long,
    ): Boolean {
        if (attemptDatesMillis.isEmpty()) return successfulEventCount >= 1
        if (attemptDatesMillis.size >= MAXIMUM_ATTEMPTS_PER_WINDOW) return false
        val lastAttempt = attemptDatesMillis.maxOrNull() ?: return successfulEventCount >= 1
        if (nowMillis - lastAttempt < REPEAT_INTERVAL_MILLIS) return false
        return successfulEventCount - lastAttemptEventCount >= ADDITIONAL_EVENTS_FOR_RETRY
    }
}
