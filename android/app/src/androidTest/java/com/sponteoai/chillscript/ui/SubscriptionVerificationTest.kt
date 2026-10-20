package com.sponteoai.chillscript.ui

import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.billing.BillingUiState
import com.sponteoai.chillscript.billing.SubscriptionCheck
import com.sponteoai.chillscript.ui.subscription.SubscriptionScreen
import com.sponteoai.chillscript.ui.theme.ChillScriptTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SubscriptionVerificationTest {
    @get:Rule val rule = createComposeRule()
    private val resources get() = InstrumentationRegistry.getInstrumentation().targetContext.resources

    @Test fun failedVerificationOffersRetryAndKeepsCheckoutHiddenUntilConfirmed() {
        val check = mutableStateOf(SubscriptionCheck.Failed)
        var retries = 0
        var purchases = 0
        rule.setContent {
            ChillScriptTheme {
                SubscriptionScreen(
                    isPro = false,
                    subscriptionExpiresAt = null,
                    subscriptionCheck = check.value,
                    billingState = BillingUiState(loading = false),
                    onPurchase = { purchases++ },
                    onRestore = {},
                    onRetryProducts = { retries++; check.value = SubscriptionCheck.Checking },
                    onDismiss = {},
                    onOpenUrl = {},
                )
            }
        }
        rule.onNodeWithText(resources.getString(R.string.subscription_status_unavailable)).assertIsDisplayed()
        rule.onNodeWithText(resources.getString(R.string.subscription_restore_purchases)).assertDoesNotExist()
        rule.onNodeWithText(resources.getString(R.string.common_retry)).performClick()
        rule.onNodeWithText(resources.getString(R.string.subscription_status_checking)).assertIsDisplayed()
        rule.onNodeWithText(resources.getString(R.string.common_retry)).assertDoesNotExist()
        rule.runOnIdle { assertEquals(1, retries); assertEquals(0, purchases) }
    }

    @Test fun aRecoveredTrialShowsMembershipInsteadOfThePurchaseScreen() {
        val check = mutableStateOf(SubscriptionCheck.Checking)
        rule.setContent {
            ChillScriptTheme {
                SubscriptionScreen(
                    isPro = check.value == SubscriptionCheck.Confirmed,
                    subscriptionExpiresAt = "2099-10-26T08:02:16Z",
                    activeProductId = "com.chillnote.pro.yearly",
                    subscriptionCheck = check.value,
                    billingState = BillingUiState(loading = false),
                    onPurchase = { error("Existing trial must not purchase again") },
                    onRestore = {},
                    onRetryProducts = {},
                    onDismiss = {},
                    onOpenUrl = {},
                )
            }
        }
        rule.onNodeWithText(resources.getString(R.string.subscription_status_checking)).assertIsDisplayed()
        rule.runOnIdle { check.value = SubscriptionCheck.Confirmed }
        rule.onNodeWithText(resources.getString(R.string.subscription_status_checking)).assertDoesNotExist()
        rule.onNodeWithText(resources.getString(R.string.subscription_active_privileges)).assertIsDisplayed()
    }
}
