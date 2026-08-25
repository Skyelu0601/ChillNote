package com.sponteoai.chillscript.push

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PushModelsTest {
    @Test
    fun `weekly topics route opens weekly topics`() {
        assertEquals(
            PushDestination.WeeklyTopics,
            parsePushDestination(PushContract.ROUTE_WEEKLY_TOPICS, null),
        )
    }

    @Test
    fun `note route requires a valid UUID`() {
        val noteId = "d9ac88ec-6494-47c1-b7e0-92a446e0f38d"

        assertEquals(
            PushDestination.Note(noteId),
            parsePushDestination(PushContract.ROUTE_NOTE, noteId),
        )
        assertEquals(
            PushDestination.Home,
            parsePushDestination(PushContract.ROUTE_NOTE, "not-a-note-id"),
        )
    }

    @Test
    fun `unknown route safely opens home`() {
        assertEquals(PushDestination.Home, parsePushDestination("removed_route", null))
    }

    @Test
    fun `registration waits for Firebase configuration and permission`() {
        val base = PushRegistrationSnapshot(
            firebaseConfigured = false,
            permissionGranted = false,
            currentToken = null,
            registeredToken = null,
            registeredUserId = null,
            currentUserId = "user-1",
        )

        assertEquals(PushRegistrationDecision.Disabled, decidePushRegistration(base))
        assertEquals(
            PushRegistrationDecision.AwaitPermission,
            decidePushRegistration(base.copy(firebaseConfigured = true)),
        )
        assertEquals(
            PushRegistrationDecision.FetchToken,
            decidePushRegistration(
                base.copy(firebaseConfigured = true, permissionGranted = true),
            ),
        )
    }

    @Test
    fun `registration is user scoped even when token is unchanged`() {
        val snapshot = PushRegistrationSnapshot(
            firebaseConfigured = true,
            permissionGranted = true,
            currentToken = validToken(),
            registeredToken = validToken(),
            registeredUserId = "old-user",
            currentUserId = "new-user",
        )

        val decision = decidePushRegistration(snapshot)
        assertTrue(decision is PushRegistrationDecision.Register)
        assertEquals(validToken(), (decision as PushRegistrationDecision.Register).token)
        assertEquals(
            PushRegistrationDecision.UpToDate,
            decidePushRegistration(snapshot.copy(registeredUserId = "new-user")),
        )
    }

    private fun validToken() = "fcm-registration-token_1234567890"
}
