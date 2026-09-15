package com.sponteoai.chillscript.domain

import com.sponteoai.chillscript.data.local.NoteEntity

internal enum class NoteEditorCloseAction {
    None,
    Save,
    DiscardEmptyDraft,
}

/** Cleanup permission belongs to one newly created draft, never to a blank autosave. */
internal class NoteEditorDraftSession(
    note: NoteEntity? = null,
    isNewBlankDraft: Boolean = false,
) {
    private val noteId = note?.id
    private var canDiscardEmptyDraft = isNewBlankDraft && note != null && note.content.isBlank()
        && !note.hasSourceOrImport()

    fun recordContent(content: String) {
        // Once meaningful text has existed, clearing it must not restore cleanup permission.
        if (content.isNotBlank()) canDiscardEmptyDraft = false
    }

    fun closeAction(
        note: NoteEntity?,
        currentContent: String,
        persistedContent: String,
        hasVoiceState: Boolean = false,
        isVoiceProcessing: Boolean = false,
    ): NoteEditorCloseAction {
        recordContent(persistedContent)
        recordContent(currentContent)
        if (note != null) recordContent(note.content)
        return when {
            note?.deletedAt != null -> NoteEditorCloseAction.None
            isVoiceProcessing || (currentContent.isBlank() && hasVoiceState) -> NoteEditorCloseAction.None
            note != null && note.id == noteId && canDiscardEmptyDraft && currentContent.isBlank()
                && !note.hasSourceOrImport() -> NoteEditorCloseAction.DiscardEmptyDraft
            (note != null || currentContent.isNotBlank()) && shouldPersistEditorContentOnClose(
                hasExistingNote = note != null,
                currentContent = currentContent,
                persistedContent = persistedContent,
                isVoiceProcessing = isVoiceProcessing,
            ) -> NoteEditorCloseAction.Save
            else -> NoteEditorCloseAction.None
        }
    }

    private fun NoteEntity.hasSourceOrImport(): Boolean =
        sourceUrl != null || importJobId != null || !importStatus.isNullOrBlank() || pinnedAt != null
}

internal fun shouldPersistEditorContentOnClose(
    hasExistingNote: Boolean,
    currentContent: String,
    persistedContent: String,
    isVoiceProcessing: Boolean,
): Boolean {
    if (isVoiceProcessing) return false
    return !hasExistingNote || currentContent != persistedContent
}
