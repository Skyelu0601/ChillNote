package com.sponteoai.chillscript.ui.editor

import org.junit.Assert.assertEquals
import org.junit.Test

class TeleprompterPreviewTest {
    @Test fun `record workspace preview shows heading and formatted body as plain text`() {
        assertEquals(
            listOf("Opening Say hello and welcome everyone"),
            teleprompterPages("## Opening\nSay **hello** and *welcome* `everyone`", "Empty"),
        )
    }

    @Test fun `headings are removed before preview pagination`() {
        val script = (1..150).joinToString("\n") { "## word$it" }
        val pages = teleprompterPages(script, "Empty")
        assertEquals(3, pages.size)
        assertEquals((1..150).joinToString(" ") { "word$it" }, pages.joinToString(" "))
    }

    @Test fun `empty preview uses its placeholder`() {
        assertEquals(listOf("Empty"), teleprompterPages(" \n ", "Empty"))
    }
}
