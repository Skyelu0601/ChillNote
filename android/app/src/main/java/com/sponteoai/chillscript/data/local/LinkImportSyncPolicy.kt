package com.sponteoai.chillscript.data.local

/** Enqueue and local adoption can persist the same placeholder at different versions. */
internal fun isSamePendingImport(local: NoteEntity, remote: NoteEntity): Boolean =
    local.importStatus in setOf("queued", "processing") &&
        remote.importStatus in setOf("queued", "processing") &&
        !remote.importJobId.isNullOrBlank() &&
        (local.importJobId.isNullOrBlank() || local.importJobId == remote.importJobId) &&
        !local.sourceUrl.isNullOrBlank() &&
        local.content == remote.content && local.sourceUrl == remote.sourceUrl &&
        local.section == remote.section &&
        local.deletedAt == null && remote.deletedAt == null &&
        local.pinnedAt == null && remote.pinnedAt == null
