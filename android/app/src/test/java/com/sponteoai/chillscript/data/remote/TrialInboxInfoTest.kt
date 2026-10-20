package com.sponteoai.chillscript.data.remote

import kotlinx.serialization.json.Json
import org.junit.Assert.*
import org.junit.Test

class TrialInboxInfoTest {
    private val json = Json { ignoreUnknownKeys = true }

    @Test fun olderResponsesAndUnknownFieldsRemainCompatible() {
        val item = json.decodeFromString(InboxNotification.serializer(), """
            {"id":"item","kind":"welcome_pro","createdAt":"2026-10-10T12:00:00Z","futureField":true}
        """.trimIndent())
        assertTrue(item.supported)
        assertNull(item.trial)
        assertNull(item.readAt)
    }

    @Test fun cancellationKeepsTheTrialEndAndReadState() {
        val item = json.decodeFromString(InboxNotification.serializer(), """
            {"id":"item","kind":"welcome_pro","createdAt":"2026-10-10T12:00:00Z",
             "readAt":"2026-10-11T12:00:00Z","trial":{"expiresAt":"2026-10-17T12:00:00.000Z",
             "autoRenew":false,"reminderStatus":"cancelled",
             "manageSubscriptionURL":"https://play.google.com/store/account/subscriptions"}}
        """.trimIndent())
        assertEquals("2026-10-17T12:00:00Z", item.trial?.endDate.toString())
        assertEquals(false, item.trial?.autoRenew)
        assertNotNull(item.readAt)
        assertNotNull(item.trial?.subscriptionURL)
    }

    @Test fun malformedDatesAndUntrustedSubscriptionLinksFailSafely() {
        val trial = TrialInboxInfo("invalid", true, "future_status", reminderAt = "invalid")
        assertNull(trial.endDate)
        assertNull(trial.reminderDate)
        for (url in listOf("http://play.google.com/store/account/subscriptions",
            "https://play.google.com.evil.test/store/account/subscriptions", "https://example.com",
            "https://user@play.google.com/store/account/subscriptions", "https://apps.apple.com/account/billing")) {
            assertNull(trial.copy(manageSubscriptionURL = url).subscriptionURL)
        }
        assertNotNull(trial.copy(manageSubscriptionURL = "https://apps.apple.com/account/subscriptions").subscriptionURL)
    }
}
