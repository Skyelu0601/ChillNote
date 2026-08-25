package com.sponteoai.chillscript.sync

import androidx.work.BackoffPolicy
import com.sponteoai.chillscript.auth.AuthException
import com.sponteoai.chillscript.auth.AuthSession
import com.sponteoai.chillscript.auth.AuthUser
import com.sponteoai.chillscript.data.remote.SyncHttpException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException

class BackgroundSyncPolicyTest {
    @Test
    fun schedulesUseUniqueConnectedWorkWithExponentialBackoff() {
        val periodic = backgroundSyncScheduleSpec(BackgroundSyncSchedule.PERIODIC)
        val foreground = backgroundSyncScheduleSpec(BackgroundSyncSchedule.FOREGROUND)
        val linkImport = backgroundSyncScheduleSpec(BackgroundSyncSchedule.LINK_IMPORT)

        assertEquals("chillscript.periodic-sync", periodic.uniqueName)
        assertEquals(15L, periodic.repeatIntervalMinutes)
        assertEquals(BackgroundSyncUniquePolicy.KEEP, periodic.uniquePolicy)
        assertTrue(periodic.requiresConnectedNetwork)
        assertEquals(BackoffPolicy.EXPONENTIAL, periodic.backoffPolicy)
        assertEquals(30L, periodic.backoffDelaySeconds)

        assertEquals("chillscript.foreground-sync", foreground.uniqueName)
        assertEquals(BackgroundSyncUniquePolicy.KEEP, foreground.uniquePolicy)
        assertNull(foreground.repeatIntervalMinutes)

        assertEquals("chillscript.link-import-recovery", linkImport.uniqueName)
        assertEquals(BackgroundSyncUniquePolicy.APPEND_OR_REPLACE, linkImport.uniquePolicy)
        assertNull(linkImport.repeatIntervalMinutes)
    }

    @Test
    fun authenticationRejectionDoesNotRetry() {
        assertEquals(
            BackgroundSyncFailureDisposition.AUTH_REJECTED,
            classifyBackgroundSyncFailure(SyncHttpException(401, "expired")),
        )
        assertEquals(
            BackgroundSyncFailureDisposition.AUTH_REJECTED,
            classifyBackgroundSyncFailure(SyncHttpException(403, "forbidden")),
        )
        assertEquals(
            BackgroundSyncFailureDisposition.AUTH_REJECTED,
            classifyBackgroundSyncFailure(AuthException(400, "invalid refresh token")),
        )
    }

    @Test
    fun transientFailuresRetryAndPermanentClientFailuresStop() {
        assertEquals(
            BackgroundSyncFailureDisposition.RETRY,
            classifyBackgroundSyncFailure(SyncHttpException(503, "unavailable")),
        )
        assertEquals(
            BackgroundSyncFailureDisposition.RETRY,
            classifyBackgroundSyncFailure(SyncHttpException(429, "rate limited")),
        )
        assertEquals(
            BackgroundSyncFailureDisposition.RETRY,
            classifyBackgroundSyncFailure(IOException("offline")),
        )
        assertEquals(
            BackgroundSyncFailureDisposition.FAILURE,
            classifyBackgroundSyncFailure(SyncHttpException(422, "invalid payload")),
        )
    }

    @Test
    fun pendingImportPollingIsBounded() {
        assertTrue(shouldRetryPendingLinkImport(hasPendingImport = true, runAttemptCount = 0))
        assertTrue(shouldRetryPendingLinkImport(hasPendingImport = true, runAttemptCount = 3))
        assertFalse(shouldRetryPendingLinkImport(hasPendingImport = true, runAttemptCount = 4))
        assertFalse(shouldRetryPendingLinkImport(hasPendingImport = false, runAttemptCount = 0))
    }

    @Test
    fun expiredOrUnknownSessionExpiryRequiresRefresh() {
        val user = AuthUser(id = "user")
        val valid = AuthSession("access", "refresh", 3_600L, 10_000L, user)
        val expiring = valid.copy(expiresAt = 1_200L)
        val unknown = valid.copy(expiresAt = null)

        assertFalse(shouldRefreshBackgroundSession(valid, nowEpochSeconds = 1_000L))
        assertTrue(shouldRefreshBackgroundSession(expiring, nowEpochSeconds = 1_000L))
        assertTrue(shouldRefreshBackgroundSession(unknown, nowEpochSeconds = 1_000L))
    }
}
