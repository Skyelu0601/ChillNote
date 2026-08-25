package com.sponteoai.chillscript.domain

import com.sponteoai.chillscript.data.local.NoteEntity
import org.junit.Assert.assertEquals
import org.junit.Test

class NotePresentationTest {
    @Test fun platformResolverCoversCreatorAndCommunitySources() {
        assertEquals("youtube", SourcePlatformResolver.resolve("https://youtu.be/abc").id)
        assertEquals("youtube", SourcePlatformResolver.resolve("https://www.youtube-nocookie.com/embed/abc").id)
        assertEquals("xiaohongshu", SourcePlatformResolver.resolve("https://xhslink.com/a").id)
        assertEquals("reddit", SourcePlatformResolver.resolve("https://www.reddit.com/r/test").id)
        assertEquals("bilibili", SourcePlatformResolver.resolve("https://b23.tv/abc").id)
        assertEquals("web", SourcePlatformResolver.resolve("https://notyoutube.com/watch?v=abc").id)
        assertEquals("web", SourcePlatformResolver.resolve("https://myreddit.com/r/test").id)
    }

    @Test fun markdownImagesOnlyReturnsLocalFilesAndCanRemoveAllImages() {
        val markdown = "Before\n![](file:///tmp/a.jpg)\n![web](https://example.com/a.jpg)\nAfter"
        assertEquals(listOf("file:///tmp/a.jpg"), MarkdownImages.urls(markdown))
        assertEquals("Before\n\n\nAfter", MarkdownImages.removingImages(markdown))
    }

    @Test fun sourceMetadataIncludesCreatorIdentity() {
        val metadata = sourceNote(
            sourceAuthorName = "Creator Name",
            sourceAuthorHandle = "@creator",
        ).sourceMetadata()

        assertEquals("Creator Name", metadata?.authorDisplayName)
        assertEquals("@creator", metadata?.authorHandle)
    }

    @Test fun sourceMetadataFallsBackToNormalizedCreatorHandle() {
        val metadata = sourceNote(
            sourceAuthorName = " ",
            sourceAuthorHandle = "@@creator",
        ).sourceMetadata()

        assertEquals("@creator", metadata?.authorDisplayName)
    }

    private fun sourceNote(
        sourceAuthorName: String?,
        sourceAuthorHandle: String?,
    ) = NoteEntity(
        id = "note-1",
        userId = "user-1",
        content = "Imported transcript",
        createdAt = "2026-01-01T00:00:00Z",
        updatedAt = "2026-01-01T00:00:00Z",
        sourceUrl = "https://www.youtube.com/watch?v=abc",
        sourceTitle = "Video title",
        sourceAuthorName = sourceAuthorName,
        sourceAuthorHandle = sourceAuthorHandle,
    )
}
