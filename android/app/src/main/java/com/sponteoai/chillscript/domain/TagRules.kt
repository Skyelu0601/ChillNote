package com.sponteoai.chillscript.domain

import com.sponteoai.chillscript.data.local.TagEntity

object TagColors {
    const val Default = "#2F86FF"

    val Palette = listOf(
        "#2F86FF", "#5B8CFF", "#7A5CFF", "#B14DFF", "#00A3FF",
        "#00B8A9", "#2ECC71", "#A3A3AE", "#6B7280", "#111114",
    )

    fun normalize(raw: String): String {
        val hex = raw.trim().removePrefix("#").uppercase()
        return if (hex.matches(Regex("[0-9A-F]{6}"))) "#$hex" else Default
    }

    fun automatic(existingTags: List<TagEntity>): String =
        Palette[existingTags.count { it.deletedAt == null } % Palette.size]
}

object TagHierarchy {
    fun validParents(tagId: String, tags: List<TagEntity>): List<TagEntity> {
        val descendants = descendantsOf(tagId, tags)
        return tags.filter { it.deletedAt == null && it.id != tagId && it.id !in descendants }
    }

    private fun descendantsOf(tagId: String, tags: List<TagEntity>): Set<String> {
        val result = mutableSetOf<String>()
        var frontier = setOf(tagId)
        while (frontier.isNotEmpty()) {
            val children = tags.filter { it.parentId in frontier }.map { it.id }.filter(result::add).toSet()
            frontier = children
        }
        return result
    }
}
