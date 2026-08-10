package com.sponteoai.chillscript.domain

enum class MarkdownBlockType {
    Paragraph, Heading1, Heading2, Heading3, ChecklistOpen, ChecklistDone,
    Bullet, Numbered, Quote, Separator, Image,
}

data class MarkdownBlock(
    val type: MarkdownBlockType,
    val text: String,
    val prefix: String = "",
    val imageUrl: String? = null,
)

object MarkdownParser {
    private val numbered = Regex("^(\\d+\\.\\s)(.*)$")
    private val image = Regex("^!\\[[^]]*]\\(([^)]+)\\)$")

    fun parse(markdown: String): List<MarkdownBlock> = markdown.split('\n').map { line ->
        val trimmed = line.trim()
        when {
            trimmed.startsWith("### ") -> MarkdownBlock(MarkdownBlockType.Heading3, trimmed.drop(4))
            trimmed.startsWith("## ") -> MarkdownBlock(MarkdownBlockType.Heading2, trimmed.drop(3))
            trimmed.startsWith("# ") -> MarkdownBlock(MarkdownBlockType.Heading1, trimmed.drop(2))
            trimmed.startsWith("- [ ] ") -> MarkdownBlock(MarkdownBlockType.ChecklistOpen, trimmed.drop(6), "○ ")
            trimmed.startsWith("- [x] ", true) -> MarkdownBlock(MarkdownBlockType.ChecklistDone, trimmed.drop(6), "◉ ")
            trimmed.startsWith("- ") || trimmed.startsWith("• ") -> MarkdownBlock(MarkdownBlockType.Bullet, trimmed.drop(2), "• ")
            numbered.matches(trimmed) -> numbered.matchEntire(trimmed)!!.let {
                MarkdownBlock(MarkdownBlockType.Numbered, it.groupValues[2], it.groupValues[1])
            }
            trimmed.startsWith("> ") -> MarkdownBlock(MarkdownBlockType.Quote, trimmed.drop(2), "│ ")
            trimmed == "---" || trimmed.startsWith("═") -> MarkdownBlock(MarkdownBlockType.Separator, "───")
            image.matches(trimmed) -> MarkdownBlock(MarkdownBlockType.Image, "", imageUrl = image.matchEntire(trimmed)!!.groupValues[1])
            else -> MarkdownBlock(MarkdownBlockType.Paragraph, line)
        }
    }
}

data class MarkdownEditResult(val text: String, val selectionStart: Int, val selectionEnd: Int)

object MarkdownEditing {
    fun toggleBold(text: String, selectionStart: Int, selectionEnd: Int): MarkdownEditResult {
        val start = selectionStart.coerceIn(0, text.length)
        val end = selectionEnd.coerceIn(start, text.length)
        if (start == end) {
            val updated = text.substring(0, start) + "****" + text.substring(end)
            return MarkdownEditResult(updated, start + 2, start + 2)
        }
        val selected = text.substring(start, end)
        val alreadyWrapped = start >= 2 && end + 2 <= text.length &&
            text.substring(start - 2, start) == "**" && text.substring(end, end + 2) == "**"
        return if (alreadyWrapped) {
            val updated = text.removeRange(end, end + 2).removeRange(start - 2, start)
            MarkdownEditResult(updated, start - 2, end - 2)
        } else {
            val updated = text.substring(0, start) + "**" + selected + "**" + text.substring(end)
            MarkdownEditResult(updated, start + 2, end + 2)
        }
    }

    fun toggleHeading(text: String, selectionStart: Int, selectionEnd: Int, level: Int): MarkdownEditResult =
        transformSelectedLines(text, selectionStart, selectionEnd) { line ->
            val content = line.replaceFirst(Regex("^#{1,3}\\s+"), "")
            val target = "#".repeat(level) + " "
            if (line.startsWith(target)) content else target + content
        }

    fun toggleChecklist(text: String, selectionStart: Int, selectionEnd: Int): MarkdownEditResult =
        transformSelectedLines(text, selectionStart, selectionEnd) { line ->
            if (Regex("^\\s*[-*]\\s*\\[( |x|X)]\\s*").containsMatchIn(line)) {
                line.replaceFirst(Regex("^\\s*[-*]\\s*\\[( |x|X)]\\s*"), "")
            } else "- [ ] $line"
        }

    private fun transformSelectedLines(
        text: String,
        selectionStart: Int,
        selectionEnd: Int,
        transform: (String) -> String,
    ): MarkdownEditResult {
        val start = selectionStart.coerceIn(0, text.length)
        val end = selectionEnd.coerceIn(start, text.length)
        val lineStart = if (start == 0) 0 else text.lastIndexOf('\n', start - 1).let { if (it < 0) 0 else it + 1 }
        val nextBreak = text.indexOf('\n', end)
        val lineEnd = if (nextBreak < 0) text.length else nextBreak
        val replacement = text.substring(lineStart, lineEnd).split('\n').joinToString("\n", transform = transform)
        val updated = text.replaceRange(lineStart, lineEnd, replacement)
        return MarkdownEditResult(updated, lineStart, lineStart + replacement.length)
    }
}
