package com.sponteoai.chillscript.domain

data class SearchQuery(val match: String, val like: String)

object SearchQueryBuilder {
    fun build(raw: String): SearchQuery {
        val trimmed = raw.trim()
        val tokens = Regex("[\\p{L}\\p{N}_]+").findAll(trimmed.lowercase()).map { it.value }.toList()
        return SearchQuery(
            match = tokens.takeIf { it.isNotEmpty() }?.joinToString(" AND ") { "$it*" } ?: "__no_match__",
            like = "%${trimmed.replace("%", "\\%").replace("_", "\\_")}%",
        )
    }
}
