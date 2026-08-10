package com.sponteoai.chillscript.data.remote

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
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

    @Test fun resolvesCreatorPlatforms() {
        assertEquals("tiktok", sourceForUrl("https://www.tiktok.com/@creator/video/123").platformID)
        assertEquals("youtube", sourceForUrl("https://youtu.be/abc123").platformID)
        assertEquals("instagram", sourceForUrl("https://www.instagram.com/reel/example/").platformID)
    }
}
