package com.sponteoai.chillscript.push

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class ImportNotificationPermissionPromptTest {
    private val now = Instant.parse("2026-08-23T12:00:00Z")

    @Test
    fun `offers once when a recent imported item exists and permission is missing`() {
        assertTrue(
            shouldOfferImportNotificationPrompt(
                alreadySeen = false,
                firebaseConfigured = true,
                notificationPermissionGranted = false,
                candidates = listOf(
                    ImportedContentCandidate(
                        sourceUrl = "https://example.com/video",
                        createdAt = "2026-08-22T13:00:00Z",
                    ),
                ),
                now = now,
            ),
        )
    }

    @Test
    fun `does not offer without configuration or after prompt was seen`() {
        val candidates = listOf(
            ImportedContentCandidate("https://example.com/video", "2026-08-23T11:00:00Z"),
        )

        assertFalse(
            shouldOfferImportNotificationPrompt(
                alreadySeen = true,
                firebaseConfigured = true,
                notificationPermissionGranted = false,
                candidates = candidates,
                now = now,
            ),
        )
        assertFalse(
            shouldOfferImportNotificationPrompt(
                alreadySeen = false,
                firebaseConfigured = false,
                notificationPermissionGranted = false,
                candidates = candidates,
                now = now,
            ),
        )
    }

    @Test
    fun `does not offer for old local notes or already granted permission`() {
        val oldImport = listOf(
            ImportedContentCandidate("https://example.com/video", "2026-08-22T11:59:59Z"),
        )

        assertFalse(
            shouldOfferImportNotificationPrompt(
                alreadySeen = false,
                firebaseConfigured = true,
                notificationPermissionGranted = false,
                candidates = oldImport,
                now = now,
            ),
        )
        assertFalse(
            shouldOfferImportNotificationPrompt(
                alreadySeen = false,
                firebaseConfigured = true,
                notificationPermissionGranted = true,
                candidates = listOf(
                    ImportedContentCandidate("https://example.com/video", "2026-08-23T11:00:00Z"),
                ),
                now = now,
            ),
        )
    }
}
