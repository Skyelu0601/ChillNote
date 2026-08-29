package com.sponteoai.chillscript.data

import com.sponteoai.chillscript.data.local.NoteEntity
import com.sponteoai.chillscript.data.local.TagEntity
import java.security.MessageDigest

/**
 * Stable hashes for the fields sent through sync.
 *
 * Local revision counters and server acknowledgement metadata are deliberately
 * excluded: retrying the same user-visible mutation must reuse its mutation ID.
 */
internal fun noteMutationFingerprint(note: NoteEntity, tagIds: List<String>): String = fingerprint(
    "id" to canonicalSyncIdentity(note.id),
    "content" to note.content,
    "createdAt" to note.createdAt,
    "updatedAt" to note.updatedAt,
    "deletedAt" to note.deletedAt,
    "pinnedAt" to note.pinnedAt,
    "tagIds" to tagIds.map(::canonicalSyncIdentity).sorted().joinToString("\u001f"),
    "sourceUrl" to note.sourceUrl,
    "sourceTitle" to note.sourceTitle,
    "sourcePlatformId" to note.sourcePlatformId,
    "sourcePlatformName" to note.sourcePlatformName,
    "sourceHost" to note.sourceHost,
    "sourceAuthorName" to note.sourceAuthorName,
    "sourceAuthorHandle" to note.sourceAuthorHandle,
    "sourceCapturedAt" to note.sourceCapturedAt,
    "section" to note.section,
    "importStatus" to note.importStatus,
    "importJobId" to note.importJobId,
    "importErrorCode" to note.importErrorCode,
    "importStartedAt" to note.importStartedAt,
    "importCompletedAt" to note.importCompletedAt,
)

internal fun tagMutationFingerprint(tag: TagEntity): String = fingerprint(
    "id" to canonicalSyncIdentity(tag.id),
    "name" to tag.name,
    "colorHex" to tag.colorHex,
    "createdAt" to tag.createdAt,
    "updatedAt" to tag.updatedAt,
    "lastUsedAt" to tag.lastUsedAt,
    "parentId" to tag.parentId?.let(::canonicalSyncIdentity),
    "sortOrder" to tag.sortOrder.toString(),
    "deletedAt" to tag.deletedAt,
)

private fun fingerprint(vararg fields: Pair<String, String?>): String {
    val canonical = buildString {
        fields.forEach { (name, value) ->
            append(name.length).append(':').append(name).append('=')
            if (value == null) {
                append("-1:")
            } else {
                append(value.length).append(':').append(value)
            }
            append('\n')
        }
    }
    return MessageDigest.getInstance("SHA-256")
        .digest(canonical.toByteArray(Charsets.UTF_8))
        .joinToString("") { byte -> "%02x".format(byte.toInt() and 0xff) }
}
