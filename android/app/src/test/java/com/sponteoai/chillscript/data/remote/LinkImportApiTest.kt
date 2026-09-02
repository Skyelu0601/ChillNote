package com.sponteoai.chillscript.data.remote

import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LinkImportApiTest {
    @Test fun extractsUrlFromSharedCaption() {
        assertEquals("https://youtu.be/abc123", extractWebUrl("Useful video https://youtu.be/abc123 🎬"))
    }

    @Test fun ignoresPlainText() {
        assertNull(extractWebUrl("An idea without a link"))
    }

    @Test fun normalizesWwwBareDomainsAndHttp() {
        assertEquals("https://www.example.com/post", extractWebUrl("www.example.com/post"))
        assertEquals("https://example.com", extractWebUrl("example.com"))
        assertEquals("https://example.com/a", extractWebUrl("See http://example.com/a."))
    }

    @Test fun pasteLinkAcceptsTheSameCreatorMediaUrlsAsIos() {
        assertEquals(
            "https://www.youtube.com/watch?v=abc123",
            extractCreatorMediaUrl("https://www.youtube.com/watch?v=abc123"),
        )
        assertEquals(
            "https://www.instagram.com/reel/example/",
            extractCreatorMediaUrl("https://www.instagram.com/reel/example/"),
        )
        assertEquals(
            "https://www.tiktok.com/@creator/video/123",
            extractCreatorMediaUrl("https://www.tiktok.com/@creator/video/123"),
        )
        assertEquals(
            "https://www.youtube-nocookie.com/embed/abc123",
            extractCreatorMediaUrl("https://www.youtube-nocookie.com/embed/abc123"),
        )
        assertNull(extractCreatorMediaUrl("https://www.youtube.com/"))
        assertNull(extractCreatorMediaUrl("https://www.instagram.com/creator/"))
        assertNull(extractCreatorMediaUrl("https://example.com/article"))
        assertNull(extractCreatorMediaUrl("https://notyoutube.com/watch?v=abc123"))
        assertNull(extractCreatorMediaUrl("https://mytiktok.com/@creator/video/123"))
        assertNull(extractCreatorMediaUrl("https://fakeinstagram.com/reel/example/"))
    }

    @Test fun resolvesCreatorPlatforms() {
        assertEquals("tiktok", sourceForUrl("https://www.tiktok.com/@creator/video/123").platformID)
        assertEquals("youtube", sourceForUrl("https://youtu.be/abc123").platformID)
        assertEquals("youtube", sourceForUrl("https://www.youtube-nocookie.com/embed/abc123").platformID)
        assertEquals("instagram", sourceForUrl("https://www.instagram.com/reel/example/").platformID)
    }

    @Test fun transcriptOnlyRequestMatchesIosCanonicalFormat() {
        val sections = sampleRequest().mediaLinkSections

        assertFalse(sections.showDescription)
        assertFalse(sections.showAuthor)
        assertFalse(sections.showHook)
        assertTrue(sections.showTranscript)
    }

    @Test fun enqueueSerializesEveryTranscriptOnlyFlagEvenWhenJsonOmitsDefaults() = runTest {
        var capturedBody = ""
        val api = LinkImportApi(
            baseUrl = "https://api.example.com",
            json = Json { ignoreUnknownKeys = true },
            transport = LinkImportTransport { _, _, body ->
                capturedBody = body
                LinkImportHttpResponse(202, "{\"jobId\":\"job-1\",\"status\":\"queued\"}")
            },
            retryDelay = {},
        )

        api.enqueue("token", sampleRequest())

        val sections = Json.parseToJsonElement(capturedBody)
            .jsonObject.getValue("mediaLinkSections").jsonObject
        assertEquals(
            "zh-Hant",
            Json.parseToJsonElement(capturedBody).jsonObject.getValue("contentLocale").jsonPrimitive.content,
        )
        assertFalse(sections.getValue("showDescription").jsonPrimitive.boolean)
        assertFalse(sections.getValue("showAuthor").jsonPrimitive.boolean)
        assertFalse(sections.getValue("showHook").jsonPrimitive.boolean)
        assertTrue(sections.getValue("showTranscript").jsonPrimitive.boolean)
    }

    @Test fun retriesTransientFailuresThreeTimes() = runTest {
        var attempts = 0
        val delays = mutableListOf<Long>()
        val api = LinkImportApi(
            baseUrl = "https://api.example.com",
            json = Json { ignoreUnknownKeys = true },
            transport = LinkImportTransport { _, _, _ ->
                attempts += 1
                if (attempts < 3) LinkImportHttpResponse(503, "unavailable")
                else LinkImportHttpResponse(202, "{\"jobId\":\"job-1\",\"status\":\"queued\"}")
            },
            retryDelay = { delays += it },
        )

        val response = api.enqueue("token", sampleRequest())

        assertEquals("job-1", response.jobId)
        assertEquals(3, attempts)
        assertEquals(listOf(500L, 1_000L), delays)
    }

    @Test fun doesNotRetryInsufficientCredits() = runTest {
        var attempts = 0
        val api = LinkImportApi(
            baseUrl = "https://api.example.com",
            json = Json { ignoreUnknownKeys = true },
            transport = LinkImportTransport { _, _, _ ->
                attempts += 1
                LinkImportHttpResponse(402, "insufficient credits")
            },
            retryDelay = {},
        )

        val error = runCatching { api.enqueue("token", sampleRequest()) }.exceptionOrNull()

        assertTrue(error is SyncHttpException && error.statusCode == 402)
        assertEquals(1, attempts)
    }

    private fun sampleRequest() = LinkImportRequest(
        noteId = "note",
        url = "https://example.com/video",
        placeholderContent = "Preparing",
        source = sourceForUrl("https://example.com/video"),
        section = "inbox",
        contentLocale = "zh-Hant",
        mediaLinkSections = MediaLinkSectionsDto.TranscriptOnly,
    )
}
