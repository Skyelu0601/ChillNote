package com.sponteoai.chillscript.domain

import org.junit.Assert.assertEquals
import org.junit.Test

class MarkdownParserTest {
    @Test fun `recognizes every block rendered by iOS preview`() {
        val blocks = MarkdownParser.parse("# H1\n## H2\n### H3\n- [ ] Open\n- [x] Done\n- Bullet\n2. Number\n> Quote\n---")
        assertEquals(
            listOf(
                MarkdownBlockType.Heading1, MarkdownBlockType.Heading2, MarkdownBlockType.Heading3,
                MarkdownBlockType.ChecklistOpen, MarkdownBlockType.ChecklistDone, MarkdownBlockType.Bullet,
                MarkdownBlockType.Numbered, MarkdownBlockType.Quote, MarkdownBlockType.Separator,
            ),
            blocks.map { it.type },
        )
    }

    @Test fun `bold wraps and unwraps selected text`() {
        val wrapped = MarkdownEditing.toggleBold("hello world", 6, 11)
        assertEquals("hello **world**", wrapped.text)
        assertEquals("hello world", MarkdownEditing.toggleBold(wrapped.text, 8, 13).text)
    }

    @Test fun `heading toggles selected lines and replaces other heading levels`() {
        assertEquals("# one\n# two", MarkdownEditing.toggleHeading("one\ntwo", 0, 7, 1).text)
        assertEquals("## one", MarkdownEditing.toggleHeading("# one", 0, 5, 2).text)
        assertEquals("one", MarkdownEditing.toggleHeading("## one", 0, 6, 2).text)
    }

    @Test fun `checklist toggles selected lines`() {
        val checked = MarkdownEditing.toggleChecklist("one\ntwo", 0, 7)
        assertEquals("- [ ] one\n- [ ] two", checked.text)
        assertEquals("one\ntwo", MarkdownEditing.toggleChecklist(checked.text, 0, checked.text.length).text)
    }

    @Test fun `smart enter continues every supported list and resets checked items`() {
        assertSmartInput("- item", "- item\n", "- item\n- ")
        assertSmartInput("- [x] done", "- [x] done\n", "- [x] done\n- [ ] ")
        assertSmartInput("  7. item", "  7. item\n", "  7. item\n  8. ")
    }

    @Test fun `smart enter exits an empty list without leaving a hidden prefix`() {
        assertSmartInput("- [ ] ", "- [ ] \n", "\n")
        assertSmartInput("- \nnext", "- \n\nnext", "\nnext", previousCursor = 2, proposedCursor = 3)
    }

    @Test fun `backspace inside list prefix converts it to ordinary text`() {
        val result = MarkdownEditing.smartListInput(
            previousText = "- [ ] task",
            previousSelectionStart = 6,
            previousSelectionEnd = 6,
            proposedText = "- [ ]task",
            proposedSelectionStart = 5,
            proposedSelectionEnd = 5,
            hasActiveComposition = false,
        )

        assertEquals("task", result?.text)
        assertEquals(0, result?.selectionStart)
    }

    @Test fun `smart formatting normalizes checklist trigger but preserves active composition`() {
        assertSmartInput("[]", "[] ", "- [ ] ")

        val composing = MarkdownEditing.smartListInput(
            previousText = "[]",
            previousSelectionStart = 2,
            previousSelectionEnd = 2,
            proposedText = "[] ",
            proposedSelectionStart = 3,
            proposedSelectionEnd = 3,
            hasActiveComposition = true,
        )
        assertEquals(null, composing)
    }

    private fun assertSmartInput(
        previous: String,
        proposed: String,
        expected: String,
        previousCursor: Int = previous.length,
        proposedCursor: Int = previousCursor + 1,
    ) {
        val result = MarkdownEditing.smartListInput(
            previousText = previous,
            previousSelectionStart = previousCursor,
            previousSelectionEnd = previousCursor,
            proposedText = proposed,
            proposedSelectionStart = proposedCursor,
            proposedSelectionEnd = proposedCursor,
            hasActiveComposition = false,
        )
        assertEquals(expected, result?.text)
    }
}
