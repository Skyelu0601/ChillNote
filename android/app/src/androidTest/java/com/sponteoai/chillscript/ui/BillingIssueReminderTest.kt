package com.sponteoai.chillscript.ui

import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.billing.BillingReminderStore
import com.sponteoai.chillscript.ui.home.BillingIssueReminder
import com.sponteoai.chillscript.ui.home.BillingIssueSheet
import com.sponteoai.chillscript.ui.theme.ChillScriptTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class BillingIssueReminderTest {
    @get:Rule val rule = createComposeRule()
    private val resources get() = InstrumentationRegistry.getInstrumentation().targetContext.resources

    private class MemoryStorage : BillingReminderStore.Storage {
        private val values = mutableMapOf<String, Long>()
        override fun read(key: String) = values[key] ?: 0L
        override fun write(key: String, value: Long) { values[key] = value }
        override fun remove(key: String) { values.remove(key) }
    }

    @Test fun gracePeriodUsesActiveProCopyAndLaterCanDismiss() {
        var dismissed = false
        rule.setContent {
            ChillScriptTheme {
                BillingIssueSheet(hasProAccess = true, onDismiss = { dismissed = true }, onFixPayment = {})
            }
        }
        rule.onNodeWithText(resources.getString(R.string.subscription_billing_issue_message)).assertIsDisplayed()
        rule.onNodeWithText(resources.getString(R.string.subscription_billing_issue_paused_title)).assertDoesNotExist()
        rule.onNodeWithText(resources.getString(R.string.subscription_billing_issue_later)).performClick()
        rule.runOnIdle { assertTrue(dismissed) }
    }

    @Test fun pausedProUsesRecoveryCopyAndActionOpensRepair() {
        var opened = false
        rule.setContent {
            ChillScriptTheme {
                BillingIssueSheet(hasProAccess = false, onDismiss = {}, onFixPayment = { opened = true })
            }
        }
        rule.onNodeWithText(resources.getString(R.string.subscription_billing_issue_paused_title)).assertIsDisplayed()
        rule.onNodeWithText(resources.getString(R.string.subscription_billing_issue_paused_message)).assertIsDisplayed()
        rule.onNodeWithText(resources.getString(R.string.subscription_billing_issue_action)).performClick()
        rule.runOnIdle { assertTrue(opened) }
    }

    @Test fun laterDoesNotReopenWhenReturningHomeDuringCooldown() {
        val store = BillingReminderStore(MemoryStorage())
        val enabled = mutableStateOf(true)
        rule.setContent {
            ChillScriptTheme {
                BillingIssueReminder("account-a", true, true, enabled.value, store, {})
            }
        }
        rule.onNodeWithText(resources.getString(R.string.subscription_billing_issue_later)).performClick()
        rule.runOnIdle { enabled.value = false }
        rule.waitForIdle()
        rule.runOnIdle { enabled.value = true }
        rule.onNodeWithText(resources.getString(R.string.subscription_billing_issue_title)).assertDoesNotExist()
        rule.runOnIdle { assertTrue(store.nextReminderAt("account-a") > System.currentTimeMillis() + 86_000_000L) }
    }

    @Test fun confirmedRecoveryClosesTheVisibleSheet() {
        val store = BillingReminderStore(MemoryStorage())
        val issue = mutableStateOf(true)
        rule.setContent {
            ChillScriptTheme { BillingIssueReminder("account-a", issue.value, true, true, store, {}) }
        }
        rule.onNodeWithText(resources.getString(R.string.subscription_billing_issue_title)).assertIsDisplayed()
        rule.runOnIdle {
            store.subscriptionStatusConfirmed("account-a", false)
            issue.value = false
        }
        rule.onNodeWithText(resources.getString(R.string.subscription_billing_issue_title)).assertDoesNotExist()
    }

    @Test fun openingPaymentRepairSnoozesButDoesNotClearTheIssue() {
        val store = BillingReminderStore(MemoryStorage())
        var opens = 0
        rule.setContent {
            ChillScriptTheme { BillingIssueReminder("account-a", true, true, true, store, { opens++ }) }
        }
        rule.onNodeWithText(resources.getString(R.string.subscription_billing_issue_action)).performClick()
        rule.onNodeWithText(resources.getString(R.string.subscription_billing_issue_title)).assertDoesNotExist()
        rule.runOnIdle {
            assertEquals(1, opens)
            assertTrue(store.nextReminderAt("account-a") > System.currentTimeMillis())
        }
    }

    @Test fun largeFontKeepsBothRecoveryActionsReachable() {
        rule.setContent {
            val density = LocalDensity.current
            CompositionLocalProvider(LocalDensity provides Density(density.density, fontScale = 1.8f)) {
                ChillScriptTheme { BillingIssueSheet(false, {}, {}) }
            }
        }
        rule.onNodeWithText(resources.getString(R.string.subscription_billing_issue_action))
            .performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(resources.getString(R.string.subscription_billing_issue_later))
            .performScrollTo().assertIsDisplayed()
    }

    @Test fun persistentStoreReadsTheSameCooldownAcrossInstances() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val userId = "billing-reminder-test-${java.util.UUID.randomUUID()}"
        val original = BillingReminderStore(context)
        try {
            val expected = original.snooze(userId, 1_791_612_000_000L)
            assertEquals(expected, BillingReminderStore(context).nextReminderAt(userId))
        } finally {
            original.subscriptionStatusConfirmed(userId, false)
        }
    }
}
