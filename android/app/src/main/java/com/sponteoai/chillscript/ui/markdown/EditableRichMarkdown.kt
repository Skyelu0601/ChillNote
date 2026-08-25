package com.sponteoai.chillscript.ui.markdown

import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.ParagraphStyle
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.OffsetMapping
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.input.TransformedText
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextIndent
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sponteoai.chillscript.ui.theme.ChillColors

/**
 * Editable Markdown surface with the same WYSIWYG contract as iOS RichTextEditorView.
 *
 * The displayed string always has exactly the same UTF-16 length as the saved Markdown:
 * syntax characters are replaced by zero-width characters instead of being removed. That
 * lets Compose keep its identity cursor mapping while the repository continues to persist
 * ordinary Markdown.
 */
@Composable
fun EditableRichMarkdown(
    value: TextFieldValue,
    enabled: Boolean,
    placeholder: String,
    onValueChange: (TextFieldValue) -> Unit,
    onOpenLink: (String) -> Unit,
    modifier: Modifier = Modifier,
    textStyle: TextStyle = TextStyle(
        color = ChillColors.TextMain,
        fontSize = 17.sp,
        lineHeight = 25.sp,
        fontWeight = FontWeight.Normal,
    ),
) {
    val palette = remember {
        EditableMarkdownPalette(
            text = ChillColors.TextMain,
            secondary = ChillColors.TextSub,
            tertiary = ChillColors.TextTertiary,
            accent = ChillColors.BrandBlue,
        )
    }
    val document = remember(value.text, palette) {
        renderEditableMarkdown(value.text, palette)
    }
    val visualTransformation = remember(palette) {
        EditableMarkdownVisualTransformation(palette)
    }
    var textLayout by remember { mutableStateOf<TextLayoutResult?>(null) }
    val density = LocalDensity.current
    val checkboxHitWidthPx = with(density) { 44.dp.toPx() }
    val checkboxHorizontalLeadingSlopPx = with(density) { 6.dp.toPx() }
    val checkboxVerticalHitSlopPx = with(density) { 6.dp.toPx() }

    val currentTapHandler: (Offset) -> Unit = tapHandler@ { position ->
        val layout = textLayout ?: return@tapHandler
        if (layout.layoutInput.text.text.isEmpty()) return@tapHandler

        val hitOffset = layout.getOffsetForPosition(position)
            .coerceIn(0, value.text.lastIndex.coerceAtLeast(0))
        val checklistMarker = document.checklistMarkers.firstOrNull { markerOffset ->
            val line = layout.getLineForOffset(markerOffset.coerceAtMost(layout.layoutInput.text.length - 1))
            val left = layout.getLineLeft(line)
            val top = layout.getLineTop(line) - checkboxVerticalHitSlopPx
            val bottom = layout.getLineBottom(line) + checkboxVerticalHitSlopPx
            position.x >= left - checkboxHorizontalLeadingSlopPx &&
                position.x <= left + checkboxHitWidthPx &&
                position.y in top..bottom
        }

        if (enabled && checklistMarker != null) {
            val updated = toggleChecklistAt(value.text, checklistMarker)
            if (updated != value.text) {
                onValueChange(value.copy(text = updated, composition = null))
            }
            return@tapHandler
        }

        document.links.firstOrNull { hitOffset in it.start until it.end }
            ?.let { onOpenLink(it.url) }
    }
    val latestTapHandler by rememberUpdatedState(currentTapHandler)

    val passiveTapObserver = Modifier.pointerInput(Unit) {
        awaitEachGesture {
            val down = awaitFirstDown(
                requireUnconsumed = false,
                pass = PointerEventPass.Final,
            )
            var lastPosition = down.position
            var moved = false
            while (true) {
                val event = awaitPointerEvent(PointerEventPass.Final)
                val change = event.changes.firstOrNull { it.id == down.id } ?: break
                lastPosition = change.position
                val delta = lastPosition - down.position
                if ((delta.x * delta.x) + (delta.y * delta.y) > viewConfiguration.touchSlop * viewConfiguration.touchSlop) {
                    moved = true
                }
                if (!change.pressed) {
                    if (!moved) latestTapHandler(lastPosition)
                    break
                }
            }
        }
    }

    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        enabled = enabled,
        modifier = modifier.fillMaxWidth().then(passiveTapObserver),
        textStyle = textStyle,
        cursorBrush = SolidColor(ChillColors.BrandBlue),
        visualTransformation = visualTransformation,
        onTextLayout = { textLayout = it },
        decorationBox = { innerTextField ->
            if (value.text.isBlank()) {
                Text(
                    text = placeholder,
                    color = ChillColors.TextTertiary,
                    fontSize = 17.sp,
                )
            }
            innerTextField()
        },
    )
}

internal data class EditableMarkdownPalette(
    val text: Color,
    val secondary: Color,
    val tertiary: Color,
    val accent: Color,
)

internal data class EditableMarkdownLink(
    val start: Int,
    val end: Int,
    val url: String,
)

internal data class EditableMarkdownDocument(
    val displayText: AnnotatedString,
    val checklistMarkers: List<Int>,
    val links: List<EditableMarkdownLink>,
)

private class EditableMarkdownVisualTransformation(
    private val palette: EditableMarkdownPalette,
) : VisualTransformation {
    override fun filter(text: AnnotatedString): TransformedText = TransformedText(
        text = renderEditableMarkdown(text.text, palette).displayText,
        offsetMapping = OffsetMapping.Identity,
    )
}

internal fun renderEditableMarkdown(
    markdown: String,
    palette: EditableMarkdownPalette,
): EditableMarkdownDocument = EditableMarkdownRenderer(markdown, palette).render()

internal fun toggleChecklistAt(markdown: String, markerOffset: Int): String {
    if (markerOffset !in markdown.indices) return markdown
    val lineEnd = markdown.indexOf('\n', markerOffset).let { if (it < 0) markdown.length else it }
    val line = markdown.substring(markerOffset, lineEnd)
    val match = CHECKLIST_PREFIX.find(line) ?: return markdown
    if (match.range.first != 0) return markdown
    val stateIndex = markerOffset + match.groups[1]!!.range.first
    val nextState = if (markdown[stateIndex].equals('x', ignoreCase = true)) ' ' else 'x'
    return markdown.replaceRange(stateIndex, stateIndex + 1, nextState.toString())
}

private class EditableMarkdownRenderer(
    private val markdown: String,
    private val palette: EditableMarkdownPalette,
) {
    private val output = markdown.toCharArray()
    private val spanStyles = mutableListOf<StyleRange<SpanStyle>>()
    private val paragraphStyles = mutableListOf<StyleRange<ParagraphStyle>>()
    private val checklistMarkers = mutableListOf<Int>()
    private val links = mutableListOf<EditableMarkdownLink>()

    fun render(): EditableMarkdownDocument {
        var lineStart = 0
        while (lineStart <= markdown.length) {
            val newline = markdown.indexOf('\n', lineStart)
            val lineEnd = if (newline < 0) markdown.length else newline
            renderLine(lineStart, lineEnd)
            if (newline < 0) break
            lineStart = newline + 1
        }

        val annotated = buildAnnotatedString {
            append(output.concatToString())
            paragraphStyles.forEach { range ->
                if (range.start < range.end) addStyle(range.style, range.start, range.end)
            }
            spanStyles.forEach { range ->
                if (range.start < range.end) addStyle(range.style, range.start, range.end)
            }
        }
        return EditableMarkdownDocument(
            displayText = annotated,
            checklistMarkers = checklistMarkers,
            links = links,
        )
    }

    private fun renderLine(lineStart: Int, lineEnd: Int) {
        if (lineStart >= lineEnd) return
        // ParagraphStyle ranges must include their terminating newline. Leaving the
        // newline outside every range makes Compose lay it out as a separate default
        // paragraph, so one Enter looks like an extra blank line and the caret jumps.
        val paragraphEnd = if (lineEnd < markdown.length && markdown[lineEnd] == '\n') {
            lineEnd + 1
        } else {
            lineEnd
        }
        val line = markdown.substring(lineStart, lineEnd)
        val leadingCount = line.indexOfFirst { !it.isWhitespace() }.let { if (it < 0) line.length else it }
        val trailingIndex = line.indexOfLast { !it.isWhitespace() }
        if (trailingIndex < 0) return

        val structuralStart = lineStart + leadingCount
        val visibleEnd = lineStart + trailingIndex + 1
        val trimmed = markdown.substring(structuralStart, visibleEnd)

        headingLevel(trimmed)?.let { (level, prefixLength) ->
            hide(lineStart, structuralStart + prefixLength)
            hide(visibleEnd, lineEnd)
            val contentStart = structuralStart + prefixLength
            spanStyles += StyleRange(
                contentStart,
                visibleEnd,
                SpanStyle(
                    fontSize = when (level) {
                        1 -> 24.sp
                        2 -> 20.sp
                        else -> 17.sp
                    },
                    fontWeight = if (level == 1) FontWeight.Bold else FontWeight.SemiBold,
                ),
            )
            paragraphStyles += StyleRange(
                lineStart,
                paragraphEnd,
                ParagraphStyle(lineHeight = if (level == 1) 32.sp else if (level == 2) 28.sp else 25.sp),
            )
            renderInline(contentStart, visibleEnd)
            return
        }

        CHECKLIST_PREFIX.find(trimmed)?.takeIf { it.range.first == 0 }?.let { match ->
            val prefixStart = structuralStart
            val prefixEnd = structuralStart + match.range.last + 1
            val isChecked = match.groupValues[1].equals("x", ignoreCase = true)
            hide(lineStart, prefixEnd)
            output[prefixStart] = if (isChecked) CHECKBOX_CHECKED else CHECKBOX_UNCHECKED
            if (prefixEnd < visibleEnd) output[prefixEnd - 1] = ' '
            hide(visibleEnd, lineEnd)

            checklistMarkers += prefixStart
            spanStyles += StyleRange(
                prefixStart,
                prefixStart + 1,
                SpanStyle(
                    color = if (isChecked) palette.accent else palette.tertiary,
                    fontSize = 21.sp,
                    fontWeight = FontWeight.Medium,
                ),
            )
            paragraphStyles += StyleRange(
                lineStart,
                paragraphEnd,
                ParagraphStyle(
                    lineHeight = 25.sp,
                    textIndent = TextIndent(firstLine = 0.sp, restLine = 24.sp),
                ),
            )
            if (prefixEnd < visibleEnd) {
                if (isChecked) {
                    spanStyles += StyleRange(
                        prefixEnd,
                        visibleEnd,
                        SpanStyle(
                            color = palette.secondary,
                            textDecoration = TextDecoration.LineThrough,
                        ),
                    )
                }
                renderInline(prefixEnd, visibleEnd)
            }
            return
        }

        BULLET_PREFIX.find(trimmed)?.takeIf { it.range.first == 0 }?.let { match ->
            val prefixStart = structuralStart
            val prefixEnd = structuralStart + match.range.last + 1
            hide(lineStart, prefixEnd)
            output[prefixStart] = BULLET
            if (prefixEnd < visibleEnd) output[prefixEnd - 1] = ' '
            hide(visibleEnd, lineEnd)
            spanStyles += StyleRange(prefixStart, prefixStart + 1, SpanStyle(color = palette.secondary))
            paragraphStyles += StyleRange(
                lineStart,
                paragraphEnd,
                ParagraphStyle(lineHeight = 25.sp, textIndent = TextIndent(0.sp, 20.sp)),
            )
            renderInline(prefixEnd, visibleEnd)
            return
        }

        ORDERED_PREFIX.find(trimmed)?.takeIf { it.range.first == 0 }?.let { match ->
            val prefixStart = structuralStart
            val prefixEnd = structuralStart + match.range.last + 1
            hide(lineStart, structuralStart)
            hide(visibleEnd, lineEnd)
            spanStyles += StyleRange(
                prefixStart,
                prefixEnd,
                SpanStyle(
                    color = palette.secondary,
                    fontFamily = FontFamily.Monospace,
                    fontWeight = FontWeight.Medium,
                ),
            )
            paragraphStyles += StyleRange(
                lineStart,
                paragraphEnd,
                ParagraphStyle(lineHeight = 25.sp, textIndent = TextIndent(0.sp, 24.sp)),
            )
            renderInline(prefixEnd, visibleEnd)
            return
        }

        QUOTE_PREFIX.find(trimmed)?.takeIf { it.range.first == 0 }?.let { match ->
            val prefixStart = structuralStart
            val prefixEnd = structuralStart + match.range.last + 1
            hide(lineStart, prefixEnd)
            output[prefixStart] = QUOTE_BAR
            if (prefixEnd < visibleEnd) output[prefixEnd - 1] = ' '
            hide(visibleEnd, lineEnd)
            spanStyles += StyleRange(prefixStart, prefixStart + 1, SpanStyle(color = palette.accent))
            spanStyles += StyleRange(
                prefixEnd,
                visibleEnd,
                SpanStyle(color = palette.secondary, background = IOS_SYSTEM_GRAY_6),
            )
            paragraphStyles += StyleRange(
                lineStart,
                paragraphEnd,
                ParagraphStyle(lineHeight = 25.sp, textIndent = TextIndent(16.sp, 16.sp)),
            )
            renderInline(prefixEnd, visibleEnd)
            return
        }

        if (trimmed in DIVIDERS) {
            hide(lineStart, lineEnd)
            repeat(trimmed.length) { index -> output[structuralStart + index] = DIVIDER_GLYPH }
            spanStyles += StyleRange(
                structuralStart,
                structuralStart + trimmed.length,
                SpanStyle(color = palette.tertiary, fontSize = 10.sp),
            )
            paragraphStyles += StyleRange(lineStart, paragraphEnd, ParagraphStyle(lineHeight = 20.sp))
            return
        }

        if (trimmed.startsWith("![](") && trimmed.endsWith(")") && trimmed.length > 5) {
            val urlStart = structuralStart + 4
            val urlEnd = visibleEnd - 1
            hide(lineStart, urlStart)
            hide(urlEnd, lineEnd)
            spanStyles += StyleRange(
                urlStart,
                urlEnd,
                SpanStyle(color = palette.secondary, fontStyle = FontStyle.Italic),
            )
            return
        }

        // Regular paragraphs already inherit the BasicTextField's 25sp line height.
        // Adding an explicit ParagraphStyle only after a character exists makes a
        // trailing empty-line caret use one layout and then jump when text is typed.
        renderInline(lineStart, lineEnd)
    }

    private fun renderInline(start: Int, end: Int) {
        var index = start
        while (index < end) {
            if (markdown[index] == '\\' && index + 1 < end) {
                hide(index, index + 1)
                index += 2
                continue
            }

            if (markdown[index] == '[') {
                val labelEnd = markdown.indexOf("](", index + 1)
                if (labelEnd in (index + 1)..<end) {
                    val urlEnd = markdown.indexOf(')', labelEnd + 2)
                    if (urlEnd in (labelEnd + 3)..<end) {
                        val url = markdown.substring(labelEnd + 2, urlEnd)
                        if (isWebUrl(url)) {
                            hide(index, index + 1)
                            hide(labelEnd, labelEnd + 2)
                            hide(labelEnd + 2, urlEnd + 1)
                            val labelStart = index + 1
                            spanStyles += StyleRange(
                                labelStart,
                                labelEnd,
                                SpanStyle(color = palette.accent, textDecoration = TextDecoration.Underline),
                            )
                            links += EditableMarkdownLink(labelStart, labelEnd, url)
                            index = urlEnd + 1
                            continue
                        }
                    }
                }
            }

            if (markdown.startsWith("**", index)) {
                val close = markdown.indexOf("**", index + 2)
                if (close in (index + 2)..<end) {
                    hide(index, index + 2)
                    hide(close, close + 2)
                    spanStyles += StyleRange(index + 2, close, SpanStyle(fontWeight = FontWeight.Bold))
                    index = close + 2
                    continue
                }
            }

            if (markdown[index] == '*' && (index + 1 >= end || markdown[index + 1] != '*')) {
                val close = markdown.indexOf('*', index + 1)
                if (close in (index + 1)..<end) {
                    hide(index, index + 1)
                    hide(close, close + 1)
                    index = close + 1
                    continue
                }
            }

            if (markdown[index] == '`') {
                val close = markdown.indexOf('`', index + 1)
                if (close in (index + 1)..<end) {
                    hide(index, index + 1)
                    hide(close, close + 1)
                    spanStyles += StyleRange(
                        index + 1,
                        close,
                        SpanStyle(
                            color = IOS_SYSTEM_PURPLE,
                            background = IOS_SYSTEM_GRAY_6,
                            fontFamily = FontFamily.Monospace,
                            fontSize = 16.sp,
                        ),
                    )
                    index = close + 1
                    continue
                }
            }

            val rawUrlMatch = RAW_WEB_URL.find(markdown, index)
                ?.takeIf { it.range.first == index && it.range.last < end }
            if (rawUrlMatch != null) {
                var urlEnd = rawUrlMatch.range.last + 1
                while (urlEnd > index && markdown[urlEnd - 1] in URL_TRAILING_PUNCTUATION) urlEnd--
                if (urlEnd > index) {
                    val url = markdown.substring(index, urlEnd)
                    spanStyles += StyleRange(
                        index,
                        urlEnd,
                        SpanStyle(color = palette.accent, textDecoration = TextDecoration.Underline),
                    )
                    links += EditableMarkdownLink(index, urlEnd, url)
                    index = urlEnd
                    continue
                }
            }
            index++
        }
    }

    private fun hide(start: Int, end: Int) {
        for (index in start.coerceAtLeast(0) until end.coerceAtMost(output.size)) {
            output[index] = ZERO_WIDTH_SPACE
        }
    }
}

private data class StyleRange<T>(
    val start: Int,
    val end: Int,
    val style: T,
)

private fun headingLevel(trimmed: String): Pair<Int, Int>? = when {
    trimmed.startsWith("### ") -> 3 to 4
    trimmed.startsWith("## ") -> 2 to 3
    trimmed.startsWith("# ") -> 1 to 2
    else -> null
}

private fun isWebUrl(value: String): Boolean =
    value.startsWith("https://", ignoreCase = true) || value.startsWith("http://", ignoreCase = true)

private const val ZERO_WIDTH_SPACE = '\u200B'
private const val CHECKBOX_UNCHECKED = '\u2610'
private const val CHECKBOX_CHECKED = '\u2611'
private const val BULLET = '\u2022'
private const val QUOTE_BAR = '\u2502'
private const val DIVIDER_GLYPH = '\u2500'

private val CHECKLIST_PREFIX = Regex("^[-*]\\s*\\[( |x|X)](?:\\s+|$)")
private val BULLET_PREFIX = Regex("^[-*\u2022]\\s+")
private val ORDERED_PREFIX = Regex("^\\d+\\.\\s+")
private val QUOTE_PREFIX = Regex("^>\\s+")
private val RAW_WEB_URL = Regex("https?://[^\\s<>]+", RegexOption.IGNORE_CASE)
private val DIVIDERS = setOf("---", "***", "___")
private val URL_TRAILING_PUNCTUATION = setOf('.', ',', ';', ':', '!', '?', ')', ']', '}')

private val IOS_SYSTEM_PURPLE = Color(0xFFAF52DE)
private val IOS_SYSTEM_GRAY_6 = Color(0xFFF2F2F7)
