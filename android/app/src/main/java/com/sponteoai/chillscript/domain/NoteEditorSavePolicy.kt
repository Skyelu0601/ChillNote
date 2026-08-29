package com.sponteoai.chillscript.domain

internal fun shouldPersistEditorContentOnClose(
    hasExistingNote: Boolean,
    currentContent: String,
    persistedContent: String,
    isVoiceProcessing: Boolean,
): Boolean {
    if (isVoiceProcessing) return false
    return !hasExistingNote || currentContent != persistedContent
}
