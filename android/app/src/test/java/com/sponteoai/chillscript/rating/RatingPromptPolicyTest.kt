package com.sponteoai.chillscript.rating

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RatingPromptPolicyTest {
    private val now = 2_000_000_000_000L

    @Test
    fun `first successful event requests immediately`() {
        assertTrue(
            RatingPromptPolicy.shouldRequest(
                successfulEventCount = 1,
                attemptDatesMillis = emptyList(),
                lastAttemptEventCount = 0,
                nowMillis = now,
            ),
        )
    }

    @Test
    fun `retry requires thirty days and three additional events`() {
        val previousAttempt = now - RatingPromptPolicy.REPEAT_INTERVAL_MILLIS

        assertFalse(
            RatingPromptPolicy.shouldRequest(3, listOf(previousAttempt), 1, now),
        )
        assertTrue(
            RatingPromptPolicy.shouldRequest(4, listOf(previousAttempt), 1, now),
        )
    }

    @Test
    fun `retry does not request before thirty days`() {
        assertFalse(
            RatingPromptPolicy.shouldRequest(
                successfulEventCount = 10,
                attemptDatesMillis = listOf(now - RatingPromptPolicy.REPEAT_INTERVAL_MILLIS + 1),
                lastAttemptEventCount = 1,
                nowMillis = now,
            ),
        )
    }

    @Test
    fun `stops after three attempts in window`() {
        val day = 24L * 60 * 60 * 1_000
        assertFalse(
            RatingPromptPolicy.shouldRequest(
                successfulEventCount = 20,
                attemptDatesMillis = listOf(now - 30 * day, now - 60 * day, now - 90 * day),
                lastAttemptEventCount = 10,
                nowMillis = now,
            ),
        )
    }
}
