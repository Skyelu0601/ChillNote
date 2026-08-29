package com.sponteoai.chillscript.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class SyncIdentityTest {
    @Test
    fun uuidIdentityIgnoresLetterCasing() {
        val lower = "123e4567-e89b-42d3-a456-426614174000"
        assertEquals(lower, canonicalSyncIdentity(lower.uppercase()))
    }

    @Test
    fun legacyNonUuidIdentityRemainsCaseSensitive() {
        assertNotEquals(canonicalSyncIdentity("Note-A"), canonicalSyncIdentity("note-a"))
        assertEquals("1-1-1-1-1", canonicalSyncIdentity("1-1-1-1-1"))
    }
}
