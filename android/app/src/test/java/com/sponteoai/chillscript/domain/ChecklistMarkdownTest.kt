package com.sponteoai.chillscript.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ChecklistMarkdownTest {
    @Test fun `plain text is not treated as checklist`() {
        assertNull(ChecklistMarkdown.parse("A normal note\n- a bullet"))
    }

    @Test fun `parses notes checked state stars and continuation lines like iOS`() {
        val parsed = ChecklistMarkdown.parse(
            "Context line\n\n- [ ] First task\n  continued detail\n* [X] Finished task\n",
        )!!
        assertEquals("Context line", parsed.notes)
        assertEquals(
            listOf(
                ChecklistDraftItem("First task\ncontinued detail", false),
                ChecklistDraftItem("Finished task", true),
            ),
            parsed.items,
        )
    }

    @Test fun `serialize matches iOS canonical markdown`() {
        val result = ChecklistMarkdown.serialize(
            "Context",
            listOf(ChecklistDraftItem("First\nDetail"), ChecklistDraftItem("Done", true)),
        )
        assertEquals("Context\n\n- [ ] First\n    Detail\n- [x] Done", result)
    }

    @Test fun `parse serialize round trip preserves canonical structure`() {
        val source = "Notes\n\n- [ ] One\n- [x] Two"
        val parsed = ChecklistMarkdown.parse(source)!!
        assertEquals(source, ChecklistMarkdown.serialize(parsed.notes, parsed.items))
        assertEquals("Notes\n\nOne\nTwo", ChecklistMarkdown.serializePlainText(parsed.notes, parsed.items))
    }
}
