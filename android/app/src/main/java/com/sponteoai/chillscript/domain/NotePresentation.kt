package com.sponteoai.chillscript.domain

import com.sponteoai.chillscript.data.local.NoteEntity
import java.net.URI

data class SourcePlatform(val id: String, val displayName: String)

object SourcePlatformResolver {
    fun resolve(rawUrl: String): SourcePlatform {
        val host = runCatching { URI(rawUrl).host?.removePrefix("www.")?.lowercase() }.getOrNull().orEmpty()
        return when {
            host.matchesDomain("xiaohongshu.com") || host == "xhslink.com" -> SourcePlatform("xiaohongshu", "小红书")
            host.matchesDomain("tiktok.com") -> SourcePlatform("tiktok", "TikTok")
            host == "youtu.be" || host.matchesDomain("youtube.com") ||
                host.matchesDomain("youtube-nocookie.com") -> SourcePlatform("youtube", "YouTube")
            host.matchesDomain("instagram.com") -> SourcePlatform("instagram", "Instagram")
            host.matchesDomain("threads.net") -> SourcePlatform("threads", "Threads")
            host == "x.com" || host.matchesDomain("twitter.com") -> SourcePlatform("x", "X")
            host.matchesDomain("reddit.com") -> SourcePlatform("reddit", "Reddit")
            host.matchesDomain("pinterest.com") || host == "pin.it" -> SourcePlatform("pinterest", "Pinterest")
            host.matchesDomain("linkedin.com") -> SourcePlatform("linkedin", "LinkedIn")
            host.matchesDomain("facebook.com") || host == "fb.watch" -> SourcePlatform("facebook", "Facebook")
            host.matchesDomain("vimeo.com") -> SourcePlatform("vimeo", "Vimeo")
            host.matchesDomain("twitch.tv") -> SourcePlatform("twitch", "Twitch")
            host.matchesDomain("producthunt.com") -> SourcePlatform("product_hunt", "Product Hunt")
            host.matchesDomain("news.ycombinator.com") -> SourcePlatform("hacker_news", "Hacker News")
            host.matchesDomain("bilibili.com") || host == "b23.tv" -> SourcePlatform("bilibili", "Bilibili")
            host.matchesDomain("spotify.com") -> SourcePlatform("spotify", "Spotify")
            else -> SourcePlatform("web", host.ifBlank { rawUrl })
        }
    }
}

private fun String.matchesDomain(domain: String): Boolean =
    this == domain || endsWith(".$domain")

data class NoteSourceMetadata(
    val url: String,
    val title: String,
    val platformId: String,
    val platformName: String,
    val host: String,
    val authorName: String?,
    val authorHandle: String?,
)

val NoteSourceMetadata.authorDisplayName: String?
    get() {
        val name = authorName?.trim().orEmpty()
        if (name.isNotEmpty()) return name
        val handle = authorHandle?.trim()?.trimStart('@').orEmpty()
        return handle.takeIf(String::isNotEmpty)?.let { "@$it" }
    }

fun NoteEntity.sourceMetadata(): NoteSourceMetadata? {
    val rawUrl = sourceUrl?.trim().orEmpty()
    val uri = runCatching { URI(rawUrl) }.getOrNull() ?: return null
    if (uri.scheme?.lowercase() !in setOf("http", "https") || uri.host.isNullOrBlank()) return null
    val host = sourceHost?.trim().takeUnless { it.isNullOrEmpty() } ?: uri.host.removePrefix("www.")
    val resolved = SourcePlatformResolver.resolve(rawUrl)
    return NoteSourceMetadata(
        url = rawUrl,
        title = sourceTitle?.trim().takeUnless { it.isNullOrEmpty() } ?: host,
        platformId = sourcePlatformId?.trim().takeUnless { it.isNullOrEmpty() } ?: resolved.id,
        platformName = sourcePlatformName?.trim().takeUnless { it.isNullOrEmpty() } ?: resolved.displayName,
        host = host,
        authorName = sourceAuthorName?.trim().takeUnless { it.isNullOrEmpty() },
        authorHandle = sourceAuthorHandle?.trim().takeUnless { it.isNullOrEmpty() },
    )
}

object MarkdownImages {
    data class ImageReference(val url: String, val altText: String)

    private val markdownImage = Regex("!\\[([^]]*)]\\(([^)]+)\\)")

    fun images(markdown: String): List<ImageReference> = markdownImage.findAll(markdown)
        .map { ImageReference(url = it.groupValues[2].trim(), altText = it.groupValues[1].trim()) }
        .filter { it.url.startsWith("file://") }
        .toList()

    fun urls(markdown: String): List<String> = images(markdown).map(ImageReference::url)

    fun removingImages(markdown: String): String = markdown.replace(markdownImage, "")
}
