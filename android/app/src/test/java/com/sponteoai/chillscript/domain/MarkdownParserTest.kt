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
}
