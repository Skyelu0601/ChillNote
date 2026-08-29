package com.sponteoai.chillscript.data

import java.time.Instant
import java.util.UUID

private val uuidSyncIdentityPattern =
    Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")

internal fun isUuidSyncIdentity(id: String): Boolean = uuidSyncIdentityPattern.matches(id)

/** UUID text casing must not change the identity of a synced entity. */
internal fun canonicalSyncIdentity(id: String): String =
    if (isUuidSyncIdentity(id)) UUID.fromString(id).toString() else id

internal fun compareSyncTimestamps(left: String, right: String): Int =
    runCatching { Instant.parse(left).compareTo(Instant.parse(right)) }
        .getOrElse { left.compareTo(right) }
