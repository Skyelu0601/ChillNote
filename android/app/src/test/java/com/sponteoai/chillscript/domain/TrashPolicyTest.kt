package com.sponteoai.chillscript.domain

import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Test

class TrashPolicyTest {
    private val now = Instant.parse("2026-07-13T12:00:00Z")

    @Test fun cutoffIsThirtyDaysBeforeNow() {
        assertEquals(Instant.parse("2026-06-13T12:00:00Z"), TrashPolicy.cutoff(now))
    }

    @Test fun remainingDaysRoundsUpAndNeverBecomesNegative() {
        assertEquals(30L, TrashPolicy.daysRemaining("2026-07-13T11:59:59Z", now))
        assertEquals(1L, TrashPolicy.daysRemaining("2026-06-13T12:00:01Z", now))
        assertEquals(0L, TrashPolicy.daysRemaining("2026-06-01T00:00:00Z", now))
    }
}
