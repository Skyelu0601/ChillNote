package com.sponteoai.chillscript.domain

import com.sponteoai.chillscript.data.local.NoteEntity
import java.net.URI

data class SourcePlatform(val id: String, val displayName: String)

object SourcePlatformResolver {
    fun resolve(rawUrl: String): SourcePlatform {
        val host = runCatching { URI(rawUrl).host?.removePrefix("www.")?.lowercase() }.getOrNull().orEmpty()
        return when {
            host.endsWith("xiaohongshu.com") || host == "xhslink.com" -> SourcePlatform("xiaohongshu", "小红书")
            host.endsWith("tiktok.com") -> SourcePlatform("tiktok", "TikTok")
            host == "youtu.be" || host.endsWith("youtube.com") -> SourcePlatform("youtube", "YouTube")
            host.endsWith("instagram.com") -> SourcePlatform("instagram", "Instagram")
            host.endsWith("threads.net") -> SourcePlatform("threads", "Threads")
            host == "x.com" || host.endsWith("twitter.com") -> SourcePlatform("x", "X")
            host.endsWith("reddit.com") -> SourcePlatform("reddit", "Reddit")
            host.endsWith("pinterest.com") || host == "pin.it" -> SourcePlatform("pinterest", "Pinterest")
            host.endsWith("linkedin.com") -> SourcePlatform("linkedin", "LinkedIn")
            host.endsWith("facebook.com") || host == "fb.watch" -> SourcePlatform("facebook", "Facebook")
            host.endsWith("vimeo.com") -> SourcePlatform("vimeo", "Vimeo")
            host.endsWith("twitch.tv") -> SourcePlatform("twitch", "Twitch")
            host.endsWith("producthunt.com") -> SourcePlatform("product_hunt", "Product Hunt")
            host.endsWith("news.ycombinator.com") -> SourcePlatform("hacker_news", "Hacker News")
            host.endsWith("bilibili.com") || host == "b23.tv" -> SourcePlatform("bilibili", "Bilibili")
            host.endsWith("spotify.com") -> SourcePlatform("spotify", "Spotify")
            else -> SourcePlatform("web", host.ifBlank { rawUrl })
        }
    }
}

data class NoteSourceMetadata(
    val url: String,
    val title: String,
    val platformId: String,
    val platformName: String,
    val host: String,
)

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
    )
}

object MarkdownImages {
    private val markdownImage = Regex("!\\[[^]]*]\\(([^)]+)\\)")

    fun urls(markdown: String): List<String> = markdownImage.findAll(markdown)
        .map { it.groupValues[1].trim() }
        .filter { it.startsWith("file://") }
        .toList()

    fun removingImages(markdown: String): String = markdown.replace(markdownImage, "")
}
