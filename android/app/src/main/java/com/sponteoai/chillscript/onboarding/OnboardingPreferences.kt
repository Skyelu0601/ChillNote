package com.sponteoai.chillscript.onboarding

import android.content.Context

class OnboardingPreferences(context: Context) {
    private val preferences = context.getSharedPreferences("onboarding_state", Context.MODE_PRIVATE)

    fun hasViewedIntroOnDevice(): Boolean = preferences.getBoolean(KEY_INTRO_VIEWED, false)

    fun setIntroViewedOnDevice() {
        preferences.edit().putBoolean(KEY_INTRO_VIEWED, true).apply()
    }

    fun hasHandledWelcomeNote(userId: String): Boolean =
        preferences.getBoolean("$KEY_WELCOME_PREFIX$userId", false)

    fun setWelcomeNoteHandled(userId: String) {
        preferences.edit().putBoolean("$KEY_WELCOME_PREFIX$userId", true).apply()
    }

    fun hasShownIntroPaywall(userId: String): Boolean =
        preferences.getBoolean("$KEY_PAYWALL_PREFIX$userId", false)

    fun setIntroPaywallShown(userId: String) {
        preferences.edit().putBoolean("$KEY_PAYWALL_PREFIX$userId", true).apply()
    }

    fun clearUserData(userId: String) {
        preferences.edit()
            .remove("$KEY_WELCOME_PREFIX$userId")
            .remove("$KEY_PAYWALL_PREFIX$userId")
            .apply()
    }

    private companion object {
        const val KEY_INTRO_VIEWED = "intro_viewed_on_device"
        const val KEY_WELCOME_PREFIX = "welcome_note_handled:"
        const val KEY_PAYWALL_PREFIX = "intro_paywall_shown:"
    }
}
