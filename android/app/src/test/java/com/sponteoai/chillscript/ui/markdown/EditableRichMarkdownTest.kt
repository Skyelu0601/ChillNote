package com.sponteoai.chillscript.ui.markdown

import androidx.compose.ui.graphics.Color
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EditableRichMarkdownTest {
    private val palette = EditableMarkdownPalette(
        text = Color.Black,
        secondary = Color.Gray,
        tertiary = Color.LightGray,
        accent = Color.Blue,
    )

    @Test
    fun renderedEditorHidesMarkdownWithoutChangingCursorOffsets() {
        val markdown = "# Heading\n**Bold**\n- item\n> quote\n- [ ] task\n[Site](https://example.com)"
        val rendered = renderEditableMarkdown(markdown, palette)
        val display = rendered.displayText.text

        assertEquals(markdown.length, display.length)
        assertFalse(display.contains("# "))
        assertFalse(display.contains("**"))
        assertFalse(display.contains("- [ ]"))
        assertFalse(display.contains("https://example.com"))
        assertTrue(display.contains("•"))
        assertTrue(display.contains("│"))
        assertTrue(display.contains("☐"))
        assertEquals(listOf("https://example.com"), rendered.links.map { it.url })
        assertEquals(1, rendered.checklistMarkers.size)
    }

    @Test
    fun tappingChecklistMarkerOnlyChangesItsMarkdownState() {
        val markdown = "Before\n- [ ] task\nAfter"
        val marker = markdown.indexOf("- [ ]")

        val checked = toggleChecklistAt(markdown, marker)
        assertEquals("Before\n- [x] task\nAfter", checked)
        assertEquals(markdown, toggleChecklistAt(checked, marker))
    }

    @Test
    fun regularTextUsesTheSameBaseParagraphLayoutBeforeAndAfterTyping() {
        val emptySecondLine = renderEditableMarkdown("A\n", palette)
        val filledSecondLine = renderEditableMarkdown("A\nB", palette)

        assertTrue(emptySecondLine.displayText.paragraphStyles.isEmpty())
        assertTrue(filledSecondLine.displayText.paragraphStyles.isEmpty())
    }
}
