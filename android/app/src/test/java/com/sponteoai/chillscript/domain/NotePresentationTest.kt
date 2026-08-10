package com.sponteoai.chillscript.domain

import org.junit.Assert.assertEquals
import org.junit.Test

class NotePresentationTest {
    @Test fun platformResolverCoversCreatorAndCommunitySources() {
        assertEquals("youtube", SourcePlatformResolver.resolve("https://youtu.be/abc").id)
        assertEquals("xiaohongshu", SourcePlatformResolver.resolve("https://xhslink.com/a").id)
        assertEquals("reddit", SourcePlatformResolver.resolve("https://www.reddit.com/r/test").id)
        assertEquals("bilibili", SourcePlatformResolver.resolve("https://b23.tv/abc").id)
    }

    @Test fun markdownImagesOnlyReturnsLocalFilesAndCanRemoveAllImages() {
        val markdown = "Before\n![](file:///tmp/a.jpg)\n![web](https://example.com/a.jpg)\nAfter"
        assertEquals(listOf("file:///tmp/a.jpg"), MarkdownImages.urls(markdown))
        assertEquals("Before\n\n\nAfter", MarkdownImages.removingImages(markdown))
    }
}
