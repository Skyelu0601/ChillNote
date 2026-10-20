package com.sponteoai.chillscript.ui

import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.UriHandler
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.unit.Density
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.data.remote.InboxNotification
import com.sponteoai.chillscript.data.remote.TrialInboxInfo
import com.sponteoai.chillscript.ui.home.NotificationInboxScreen
import com.sponteoai.chillscript.ui.theme.ChillScriptTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class TrialNotificationInboxTest {
    @get:Rule val rule = createComposeRule()
    private val resources get() = InstrumentationRegistry.getInstrumentation().targetContext.resources
    private val trial = TrialInboxInfo(
        expiresAt = "2026-10-17T12:00:00Z", autoRenew = true, reminderStatus = "scheduled",
        reminderAt = "2026-10-15T12:00:00Z", maskedEmail = "c***@example.com",
        manageSubscriptionURL = "https://play.google.com/store/account/subscriptions",
    )
    private fun item(info: TrialInboxInfo) = InboxNotification("trial-item", "welcome_pro",
        createdAt = "2026-10-10T12:00:00Z", trial = info)

    @Test fun scheduledReminderIsVisibleAndReadOnlyAfterLoadingCompletes() {
        val loading = mutableStateOf(true)
        val read = mutableListOf<String>()
        rule.setContent {
            ChillScriptTheme {
                NotificationInboxScreen(listOf(item(trial)), loading.value, false, {}, {}, { read.add(it) })
            }
        }
        rule.onNodeWithText(resources.getString(R.string.notifications_trial_scheduled)).assertIsDisplayed()
        rule.onNodeWithText("c***@example.com", substring = true).assertDoesNotExist()
        rule.runOnIdle { assertEquals(emptyList<String>(), read); loading.value = false }
        rule.runOnIdle { assertEquals(listOf("trial-item"), read) }
    }

    @Test fun pendingUnavailableAndCancelledStatesKeepTheTrialVisibleWithoutEmailStatusCopy() {
        val current = mutableStateOf(trial.copy(reminderStatus = "unavailable"))
        rule.setContent {
            ChillScriptTheme {
                NotificationInboxScreen(listOf(item(current.value)), false, false, {}, {}, {})
            }
        }
        rule.onNodeWithText(resources.getString(R.string.notifications_trial_title)).assertIsDisplayed()
        rule.onNodeWithTag("trial-renewal-summary").assertIsDisplayed()
        rule.onNodeWithText("c***@example.com", substring = true).assertDoesNotExist()
        rule.runOnIdle { current.value = trial.copy(reminderStatus = "pending") }
        rule.onNodeWithText(resources.getString(R.string.notifications_trial_title)).assertIsDisplayed()
        rule.onNodeWithTag("trial-renewal-summary").assertIsDisplayed()
        rule.onNodeWithText("c***@example.com", substring = true).assertDoesNotExist()
        rule.runOnIdle { current.value = trial.copy(reminderStatus = "cancelled", autoRenew = false) }
        rule.onNodeWithText("c***@example.com", substring = true).assertDoesNotExist()
        rule.onNodeWithTag("trial-renewal-summary").assertDoesNotExist()
        rule.onNodeWithText(resources.getString(R.string.notifications_trial_title)).assertIsDisplayed()
    }

    @Test fun largeTextKeepsTheStoreSubscriptionActionReachable() {
        var opened: String? = null
        val handler = object : UriHandler { override fun openUri(uri: String) { opened = uri } }
        rule.setContent {
            val density = LocalDensity.current
            CompositionLocalProvider(LocalDensity provides Density(density.density, fontScale = 1.8f), LocalUriHandler provides handler) {
                ChillScriptTheme {
                    NotificationInboxScreen(listOf(item(trial)), false, false, {}, {}, {})
                }
            }
        }
        rule.onNodeWithText(resources.getString(R.string.notifications_trial_details))
            .performScrollTo().assertIsDisplayed().performClick()
        rule.runOnIdle { assertEquals(trial.manageSubscriptionURL, opened) }
    }
}
