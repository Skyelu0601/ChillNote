package com.sponteoai.chillscript.billing

import org.junit.Assert.assertEquals
import org.junit.Test

class BillingReminderStoreTest {
    private class MemoryStorage : BillingReminderStore.Storage {
        val values = mutableMapOf<String, Long>()
        override fun read(key: String) = values[key] ?: 0L
        override fun write(key: String, value: Long) { values[key] = value }
        override fun remove(key: String) { values.remove(key) }
    }

    @Test fun snoozeSurvivesStoreRecreationAndUses24Hours() {
        val storage = MemoryStorage()
        val dismissedAt = 1_791_612_000_000L
        BillingReminderStore(storage).snooze("account-a", dismissedAt)
        val reopened = BillingReminderStore(storage)
        assertEquals(dismissedAt + 86_400_000L, reopened.nextReminderAt("account-a"))
    }

    @Test fun switchingAccountsDoesNotShareTheCooldown() {
        val store = BillingReminderStore(MemoryStorage())
        store.snooze("account-a", 1_000L)
        assertEquals(0L, store.nextReminderAt("account-b"))
        assertEquals(86_401_000L, store.nextReminderAt("account-a"))
    }

    @Test fun repeatedUnpaidStatusDoesNotShortenTheCooldown() {
        val store = BillingReminderStore(MemoryStorage())
        val expected = store.snooze("account-a", 1_000L)
        repeat(3) { store.subscriptionStatusConfirmed("account-a", hasBillingIssue = true) }
        assertEquals(expected, store.nextReminderAt("account-a"))
    }

    @Test fun recoveryAllowsANewPaymentIssueToBeShownImmediately() {
        val store = BillingReminderStore(MemoryStorage())
        store.snooze("account-a", 1_000L)
        store.subscriptionStatusConfirmed("account-a", hasBillingIssue = false)
        store.subscriptionStatusConfirmed("account-a", hasBillingIssue = true)
        assertEquals(0L, store.nextReminderAt("account-a"))
    }

    @Test fun recoveryDoesNotClearAnotherAccountsCooldown() {
        val store = BillingReminderStore(MemoryStorage())
        val expected = store.snooze("account-b", 2_000L)
        store.snooze("account-a", 1_000L)
        store.subscriptionStatusConfirmed("account-a", hasBillingIssue = false)
        assertEquals(expected, store.nextReminderAt("account-b"))
    }
}
