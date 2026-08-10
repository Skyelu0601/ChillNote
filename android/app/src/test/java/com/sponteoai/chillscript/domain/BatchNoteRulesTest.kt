package com.sponteoai.chillscript.domain

import com.sponteoai.chillscript.data.local.NoteEntity
import org.junit.Assert.assertEquals
import org.junit.Test

class BatchNoteRulesTest {
    @Test fun blankNotesAreHardDeletedAndExistingTrashIsIgnored() {
        val normal = note("normal", "Keep this")
        val blank = note("blank", "  \n")
        val alreadyDeleted = note("trash", "Already deleted", deletedAt = "2026-07-13T00:00:00Z")

        val plan = BatchNoteRules.deletionPlan(listOf(normal, blank, alreadyDeleted))

        assertEquals(listOf("normal"), plan.softDelete.map { it.id })
        assertEquals(listOf("blank"), plan.hardDeleteIds)
    }

    private fun note(id: String, content: String, deletedAt: String? = null) = NoteEntity(
        id = id,
        userId = "user",
        content = content,
        createdAt = "2026-07-13T00:00:00Z",
        updatedAt = "2026-07-13T00:00:00Z",
        deletedAt = deletedAt,
    )
}
