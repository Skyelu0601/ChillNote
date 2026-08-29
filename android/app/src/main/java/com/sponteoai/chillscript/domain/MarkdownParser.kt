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
    private val checklistLine = Regex("^([ \\t]*)- \\[([ xX])] (.*)$")
    private val bulletLine = Regex("^([ \\t]*)[-*•] (.*)$")
    private val numberedLine = Regex("^([ \\t]*)(\\d+)\\. (.*)$")

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

    /**
     * Mirrors the list-editing behavior of the iOS note editor without touching an
     * active IME composition. A null result means Compose should accept the input
     * method's proposed value unchanged, including its composition range.
     */
    fun smartListInput(
        previousText: String,
        previousSelectionStart: Int,
        previousSelectionEnd: Int,
        proposedText: String,
        proposedSelectionStart: Int,
        proposedSelectionEnd: Int,
        hasActiveComposition: Boolean,
    ): MarkdownEditResult? {
        if (hasActiveComposition || previousSelectionStart != previousSelectionEnd) return null
        if (proposedSelectionStart != proposedSelectionEnd) return null

        val previousCursor = previousSelectionEnd.coerceIn(0, previousText.length)
        val proposedCursor = proposedSelectionEnd.coerceIn(0, proposedText.length)

        if (isSingleBackspace(previousText, previousCursor, proposedText, proposedCursor)) {
            val lineStart = previousText.lastIndexOf('\n', (previousCursor - 1).coerceAtLeast(0))
                .let { if (it < 0) 0 else it + 1 }
            val lineEnd = previousText.indexOf('\n', previousCursor)
                .let { if (it < 0) previousText.length else it }
            val listLine = parseListLine(previousText.substring(lineStart, lineEnd)) ?: return null
            val deletedOffset = previousCursor - 1
            if (deletedOffset in lineStart until (lineStart + listLine.prefix.length)) {
                val updated = previousText.removeRange(lineStart, lineStart + listLine.prefix.length)
                return MarkdownEditResult(updated, lineStart, lineStart)
            }
            return null
        }

        val inserted = simpleInsertion(
            previousText = previousText,
            previousCursor = previousCursor,
            proposedText = proposedText,
            proposedCursor = proposedCursor,
        ) ?: return null

        if (inserted == " ") {
            return autoFormatListPrefix(previousText, previousCursor, proposedText, proposedCursor)
        }
        if (inserted != "\n") return null

        val lineStart = previousText.lastIndexOf('\n', (previousCursor - 1).coerceAtLeast(0))
            .let { if (it < 0) 0 else it + 1 }
        val newline = previousText.indexOf('\n', previousCursor)
        val lineEnd = if (newline < 0) previousText.length else newline
        val listLine = parseListLine(previousText.substring(lineStart, lineEnd)) ?: return null
        if (previousCursor < lineStart + listLine.prefix.length) return null

        if (listLine.content.isBlank()) {
            val replaceEnd = if (newline < 0) lineEnd else newline + 1
            val updated = previousText.replaceRange(lineStart, replaceEnd, "\n")
            return MarkdownEditResult(updated, lineStart + 1, lineStart + 1)
        }

        val updated = proposedText.substring(0, proposedCursor) +
            listLine.nextPrefix +
            proposedText.substring(proposedCursor)
        val nextCursor = proposedCursor + listLine.nextPrefix.length
        return MarkdownEditResult(updated, nextCursor, nextCursor)
    }

    private fun simpleInsertion(
        previousText: String,
        previousCursor: Int,
        proposedText: String,
        proposedCursor: Int,
    ): String? {
        if (proposedCursor < previousCursor) return null
        val prefix = previousText.substring(0, previousCursor)
        val suffix = previousText.substring(previousCursor)
        if (!proposedText.startsWith(prefix) || !proposedText.endsWith(suffix)) return null
        val insertedEnd = proposedText.length - suffix.length
        if (insertedEnd < previousCursor || proposedCursor != insertedEnd) return null
        return proposedText.substring(previousCursor, insertedEnd)
    }

    private fun isSingleBackspace(
        previousText: String,
        previousCursor: Int,
        proposedText: String,
        proposedCursor: Int,
    ): Boolean = previousCursor > 0 &&
        proposedCursor == previousCursor - 1 &&
        proposedText == previousText.removeRange(previousCursor - 1, previousCursor)

    private fun autoFormatListPrefix(
        previousText: String,
        previousCursor: Int,
        proposedText: String,
        proposedCursor: Int,
    ): MarkdownEditResult? {
        val lineStart = previousText.lastIndexOf('\n', (previousCursor - 1).coerceAtLeast(0))
            .let { if (it < 0) 0 else it + 1 }
        val typedPrefix = previousText.substring(lineStart, previousCursor)
        val indentation = typedPrefix.takeWhile { it == ' ' || it == '\t' }
        val trigger = typedPrefix.drop(indentation.length)
        val replacement = when {
            trigger == "*" || trigger == "-" -> "$indentation- "
            trigger in setOf("[]", "[ ]", "- [ ]", "* [ ]") -> "$indentation- [ ] "
            trigger.lowercase() in setOf("- [x]", "* [x]") -> "$indentation- [x] "
            trigger.matches(Regex("^\\d+\\.$")) -> "$indentation$trigger "
            else -> return null
        }
        if (proposedText.substring(lineStart, proposedCursor) == replacement) return null
        val updated = proposedText.replaceRange(lineStart, proposedCursor, replacement)
        val nextCursor = lineStart + replacement.length
        return MarkdownEditResult(updated, nextCursor, nextCursor)
    }

    private fun parseListLine(line: String): SmartListLine? {
        checklistLine.matchEntire(line)?.let { match ->
            val indentation = match.groupValues[1]
            val content = match.groupValues[3]
            val prefix = line.dropLast(content.length)
            return SmartListLine(prefix, "$indentation- [ ] ", content)
        }
        bulletLine.matchEntire(line)?.let { match ->
            val indentation = match.groupValues[1]
            val content = match.groupValues[2]
            val prefix = line.dropLast(content.length)
            return SmartListLine(prefix, "$indentation- ", content)
        }
        numberedLine.matchEntire(line)?.let { match ->
            val indentation = match.groupValues[1]
            val number = match.groupValues[2].toIntOrNull() ?: return null
            val content = match.groupValues[3]
            val prefix = line.dropLast(content.length)
            return SmartListLine(prefix, "$indentation${number + 1}. ", content)
        }
        return null
    }

    private data class SmartListLine(
        val prefix: String,
        val nextPrefix: String,
        val content: String,
    )

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
