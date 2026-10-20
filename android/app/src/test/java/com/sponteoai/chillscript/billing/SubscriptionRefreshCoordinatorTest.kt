package com.sponteoai.chillscript.billing

import com.sponteoai.chillscript.data.remote.SubscriptionStatusResponse
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.withContext
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class SubscriptionRefreshCoordinatorTest {
    private fun status(tier: String) = SubscriptionStatusResponse(true, tier)

    @Test fun aPurchaseInvalidatesTheFreeResponseAlreadyInFlight() = runTest {
        val beforePurchase = CompletableDeferred<SubscriptionStatusResponse>()
        val confirmed = mutableListOf<String>()
        var requests = 0
        val refresh = SubscriptionRefreshCoordinator(this, {
            if (++requests == 1) beforePurchase.await() else status("pro")
        }, {}, { _, result -> confirmed += result.tier }, { _, error -> throw error })
        refresh.request("a")
        runCurrent()
        refresh.request("a", purchaseCompleted = true)
        repeat(3) { refresh.request("a") }
        beforePurchase.complete(status("free"))
        advanceUntilIdle()
        assertEquals(2, requests)
        assertEquals(listOf("pro"), confirmed)
    }

    @Test fun temporaryFailuresRetryWithoutPublishingFreeMembership() = runTest {
        var requests = 0
        val confirmed = mutableListOf<String>()
        val refresh = SubscriptionRefreshCoordinator(this, {
            if (++requests < 3) error("503")
            status("pro")
        }, {}, { _, result -> confirmed += result.tier }, { _, error -> throw error })
        refresh.request("a", purchaseCompleted = true)
        advanceUntilIdle()
        assertEquals(3, requests)
        assertEquals(listOf("pro"), confirmed)
    }

    @Test fun delayedPurchaseVerificationNeverReopensCheckoutAndCanBeRetried() = runTest {
        var tier = "free"
        var failures = 0
        val confirmed = mutableListOf<String>()
        val refresh = SubscriptionRefreshCoordinator(this, { status(tier) }, {},
            { _, result -> confirmed += result.tier }, { _, _ -> failures++ })
        refresh.request("a", purchaseCompleted = true)
        advanceUntilIdle()
        assertEquals(1, failures)
        assertTrue(confirmed.isEmpty())
        // A foreground refresh also retains the pending purchase requirement.
        refresh.request("a")
        advanceUntilIdle()
        assertEquals(2, failures)
        assertTrue(confirmed.isEmpty())
        tier = "pro"
        refresh.request("a")
        advanceUntilIdle()
        assertEquals(listOf("pro"), confirmed)
    }

    @Test fun aFailedRefreshPreservesTheLastConfirmedMembership() = runTest {
        var unavailable = false
        var tier = "free"
        var check = SubscriptionCheck.Checking
        val refresh = SubscriptionRefreshCoordinator(this, {
            if (unavailable) error("offline") else status("pro")
        }, { check = SubscriptionCheck.Checking }, { _, result ->
            tier = result.tier
            check = SubscriptionCheck.Confirmed
        }, { _, _ -> check = SubscriptionCheck.Failed })
        refresh.request("a")
        advanceUntilIdle()
        unavailable = true
        refresh.request("a")
        advanceUntilIdle()
        assertEquals("pro", tier)
        assertEquals(SubscriptionCheck.Failed, check)
        assertFalse(allowsSubscriptionPurchase(tier, check))
    }

    @Test fun changingAccountsDiscardsEvenAnUncancellableOldResponse() = runTest {
        val oldResponse = CompletableDeferred<SubscriptionStatusResponse>()
        val confirmed = mutableListOf<Pair<String, String>>()
        val refresh = SubscriptionRefreshCoordinator(this, { userId ->
            if (userId == "a") withContext(NonCancellable) { oldResponse.await() }
            else status("free")
        }, {}, { userId, result -> confirmed += userId to result.tier }, { _, error -> throw error })
        refresh.request("a")
        runCurrent()
        refresh.reset()
        refresh.request("b")
        runCurrent()
        oldResponse.complete(status("pro"))
        advanceUntilIdle()
        assertEquals(listOf("b" to "free"), confirmed)
    }

    @Test fun aRealExpiryAfterConfirmedPurchaseCanReturnToFree() = runTest {
        var tier = "pro"
        val confirmed = mutableListOf<String>()
        val refresh = SubscriptionRefreshCoordinator(this, { status(tier) }, {},
            { _, result -> confirmed += result.tier }, { _, error -> throw error })
        refresh.request("a", purchaseCompleted = true)
        advanceUntilIdle()
        tier = "free"
        refresh.request("a")
        advanceUntilIdle()
        assertEquals(listOf("pro", "free"), confirmed)
    }

    @Test fun onlyConfirmedFreeUsersCanPurchase() {
        for (check in SubscriptionCheck.entries) {
            assertFalse(allowsSubscriptionPurchase("pro", check))
            assertFalse(allowsSubscriptionPurchase("unknown", check))
        }
        assertFalse(allowsSubscriptionPurchase("free", SubscriptionCheck.Checking))
        assertFalse(allowsSubscriptionPurchase("free", SubscriptionCheck.Failed))
        assertTrue(allowsSubscriptionPurchase("free", SubscriptionCheck.Confirmed))
    }
}
