package com.sponteoai.chillscript.rating

import android.content.Context
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.receiveAsFlow

class AppRatingTracker(context: Context) {
    private val preferences = context.getSharedPreferences("app_rating", Context.MODE_PRIVATE)
    private val requestChannel = Channel<Unit>(capacity = 1)
    val requests: Flow<Unit> = requestChannel.receiveAsFlow()

    fun registerVoiceNote() = registerSuccessfulEvent()

    fun registerCompletedLinkImport(noteId: String) {
        if (preferences.getBoolean(KEY_TRIGGERED, false)) return
        val counted = preferences.getStringSet(KEY_COUNTED_LINKS, emptySet()).orEmpty().toMutableSet()
        if (!counted.add(noteId)) return
        preferences.edit().putStringSet(KEY_COUNTED_LINKS, counted).apply()
        registerSuccessfulEvent()
    }

    fun clearUserData() {
        preferences.edit().clear().apply()
    }

    private fun registerSuccessfulEvent() {
        if (preferences.getBoolean(KEY_TRIGGERED, false)) return
        val count = preferences.getInt(KEY_COUNT, 0) + 1
        val editor = preferences.edit().putInt(KEY_COUNT, count)
        if (count >= PROMPT_THRESHOLD) {
            editor.putBoolean(KEY_TRIGGERED, true)
            editor.apply()
            requestChannel.trySend(Unit)
        } else editor.apply()
    }

    private companion object {
        const val KEY_COUNT = "successful_event_count"
        const val KEY_TRIGGERED = "has_triggered_prompt"
        const val KEY_COUNTED_LINKS = "counted_link_import_ids"
        const val PROMPT_THRESHOLD = 1
    }
}
