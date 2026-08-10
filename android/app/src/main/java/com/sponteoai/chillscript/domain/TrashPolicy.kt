package com.sponteoai.chillscript.domain

import java.time.Instant
import java.time.temporal.ChronoUnit
import kotlin.math.max

object TrashPolicy {
    const val RetentionDays = 30L

    fun cutoff(now: Instant = Instant.now()): Instant = now.minus(RetentionDays, ChronoUnit.DAYS)

    fun daysRemaining(deletedAt: String, now: Instant = Instant.now()): Long {
        val deleted = runCatching { Instant.parse(deletedAt) }.getOrNull() ?: return 0
        val expiration = deleted.plus(RetentionDays, ChronoUnit.DAYS)
        val seconds = ChronoUnit.SECONDS.between(now, expiration)
        return max(0, (seconds + 86_399) / 86_400)
    }
}
