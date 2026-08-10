package com.sponteoai.chillscript.domain

data class ChecklistDraftItem(val text: String, val isDone: Boolean = false)

data class ChecklistDraft(val notes: String, val items: List<ChecklistDraftItem>)

object ChecklistMarkdown {
    private val checkboxRegex = Regex("^\\s*[-*]\\s*\\[( |x|X)]\\s*(.*?)\\s*$")

    fun parse(content: String): ChecklistDraft? {
        val items = mutableListOf<ChecklistDraftItem>()
        val notesLines = mutableListOf<String>()
        var currentItemIndex: Int? = null

        content.split('\n').forEach { line ->
            val match = checkboxRegex.matchEntire(line)
            if (match != null) {
                items += ChecklistDraftItem(
                    text = match.groupValues[2].trim(),
                    isDone = match.groupValues[1].equals("x", ignoreCase = true),
                )
                currentItemIndex = items.lastIndex
            } else {
                val trimmed = line.trim()
                if (trimmed.isNotEmpty()) {
                    val itemIndex = currentItemIndex
                    if (itemIndex == null) {
                        notesLines += line
                    } else {
                        val existing = items[itemIndex]
                        items[itemIndex] = existing.copy(
                            text = if (existing.text.isEmpty()) trimmed else "${existing.text}\n$trimmed",
                        )
                    }
                }
            }
        }

        if (items.isEmpty()) return null
        return ChecklistDraft(notesLines.joinToString("\n").trim(), items)
    }

    fun serialize(notes: String, items: List<ChecklistDraftItem>): String {
        val parts = mutableListOf<String>()
        notes.trim().takeIf { it.isNotEmpty() }?.let {
            parts += it
            parts += ""
        }
        items.forEach { item ->
            val mark = if (item.isDone) "x" else " "
            val lines = item.text.split('\n').map(String::trim).filter(String::isNotEmpty)
            if (lines.isEmpty()) {
                parts += "- [$mark]"
            } else {
                parts += "- [$mark] ${lines.first()}"
                lines.drop(1).forEach { parts += "    $it" }
            }
        }
        return parts.joinToString("\n").trim()
    }

    fun serializePlainText(notes: String, items: List<ChecklistDraftItem>): String = buildList {
        notes.trim().takeIf(String::isNotEmpty)?.let {
            add(it)
            add("")
        }
        items.map { it.text.trim() }.filter(String::isNotEmpty).forEach(::add)
    }.joinToString("\n").trim()
}
