package com.sponteoai.chillscript.billing

import android.content.Context

/** Persistent cooldown per signed-in account; only a confirmed recovery resets it. */
class BillingReminderStore(private val storage: Storage) {
    constructor(context: Context) : this(object : Storage {
        private val preferences = context.applicationContext.getSharedPreferences(
            "billing_issue_reminders", Context.MODE_PRIVATE,
        )
        override fun read(key: String) = preferences.getLong(key, 0L)
        override fun write(key: String, value: Long) {
            preferences.edit().putLong(key, value).apply()
        }
        override fun remove(key: String) {
            preferences.edit().remove(key).apply()
        }
    })

    interface Storage {
        fun read(key: String): Long
        fun write(key: String, value: Long)
        fun remove(key: String)
    }

    fun nextReminderAt(userId: String): Long = storage.read(key(userId))

    fun snooze(userId: String, now: Long = System.currentTimeMillis()): Long {
        val next = now + REMINDER_INTERVAL_MILLIS
        storage.write(key(userId), next)
        return next
    }

    fun subscriptionStatusConfirmed(userId: String, hasBillingIssue: Boolean) {
        if (!hasBillingIssue) storage.remove(key(userId))
    }

    private fun key(userId: String) = "next_reminder.$userId"

    companion object {
        const val REMINDER_INTERVAL_MILLIS = 24 * 60 * 60 * 1_000L
    }
}
