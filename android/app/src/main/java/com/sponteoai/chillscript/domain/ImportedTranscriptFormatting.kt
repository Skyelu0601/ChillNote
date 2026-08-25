package com.sponteoai.chillscript.domain

private val CREATOR_MEDIA_PLATFORM_IDS = setOf("tiktok", "youtube", "instagram")

/**
 * Matches the iOS transcript-only Markdown contract: a heading followed by transcript
 * paragraphs separated by one newline, with no empty lines stored in the note body.
 */
internal fun normalizeImportedTranscriptMarkdown(
    content: String,
    sourceUrl: String?,
    sourcePlatformId: String?,
): String {
    val resolvedPlatformId = sourcePlatformId?.trim()?.lowercase().orEmpty().ifBlank {
        sourceUrl?.let(SourcePlatformResolver::resolve)?.id.orEmpty()
    }
    if (resolvedPlatformId !in CREATOR_MEDIA_PLATFORM_IDS) return content

    val normalizedLineEndings = content
        .replace("\r\n", "\n")
        .replace('\r', '\n')
        .replace('\u2028', '\n')
        .replace('\u2029', '\n')
    val lines = normalizedLineEndings.lines()
    val headingIndexes = lines.indices.filter { lines[it].trimStart().startsWith("## ") }

    // Legacy multi-section imports intentionally remain untouched. This formatter is
    // only for the current transcript-only document shape, in every supported language.
    if (headingIndexes.size != 1 || lines.take(headingIndexes.single()).any(String::isNotBlank)) {
        return content
    }

    return lines
        .drop(headingIndexes.single())
        .filterNot(String::isBlank)
        .joinToString("\n") { it.trimEnd() }
}
