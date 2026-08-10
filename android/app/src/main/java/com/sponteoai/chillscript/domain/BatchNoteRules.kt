package com.sponteoai.chillscript.domain

import com.sponteoai.chillscript.data.local.NoteEntity

data class BatchDeletePlan(
    val softDelete: List<NoteEntity>,
    val hardDeleteIds: List<String>,
)

object BatchNoteRules {
    fun deletionPlan(notes: List<NoteEntity>): BatchDeletePlan {
        val active = notes.filter { it.deletedAt == null }
        return BatchDeletePlan(
            softDelete = active.filter { it.content.isNotBlank() },
            hardDeleteIds = active.filter { it.content.isBlank() }.map { it.id },
        )
    }
}
