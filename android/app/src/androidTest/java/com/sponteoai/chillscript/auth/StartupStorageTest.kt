package com.sponteoai.chillscript.auth

import android.content.Context
import android.content.ContextWrapper
import android.content.SharedPreferences
import android.os.Looper
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.sponteoai.chillscript.voice.RecordingFileManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean

@RunWith(AndroidJUnit4::class)
class StartupStorageTest {
    private val base = InstrumentationRegistry.getInstrumentation().targetContext
    private val prefix = "startup-storage-test-${UUID.randomUUID()}-"
    private val directory = File(base.cacheDir, prefix).apply { mkdirs() }
    private val readsOnMain = AtomicBoolean(false)
    private val readsOnBackground = AtomicBoolean(false)
    private var failLegacyRead = false
    private val context = object : ContextWrapper(base) {
        override fun getApplicationContext(): Context = this
        override fun getFilesDir(): File = directory
        override fun getSharedPreferences(name: String, mode: Int): SharedPreferences {
            val delegate = base.getSharedPreferences(prefix + name, mode)
            return object : SharedPreferences by delegate {
                override fun contains(key: String): Boolean {
                    recordRead()
                    return delegate.contains(key)
                }

                override fun getString(key: String, defValue: String?): String? {
                    recordRead()
                    if (failLegacyRead && name == "auth_session" && key == "session") {
                        throw IllegalStateException("Simulated unavailable startup storage")
                    }
                    return delegate.getString(key, defValue)
                }

                override fun getLong(key: String, defValue: Long): Long {
                    recordRead()
                    return delegate.getLong(key, defValue)
                }
            }
        }
    }

    @After
    fun cleanUp() {
        listOf("auth_session", "auth_session_secure", "pending_recording_note_links", "pending_recording_media_metadata")
            .forEach { base.deleteSharedPreferences(prefix + it) }
        directory.deleteRecursively()
    }

    @Test
    fun legacySessionIsMigratedAndRestoredOffMainThread() = runBlocking {
        val session = AuthSession("test-access", "test-refresh", 3600, user = AuthUser("test-user"))
        val legacy = base.getSharedPreferences(prefix + "auth_session", Context.MODE_PRIVATE)
        assertTrue(legacy.edit().putString("session", Json.encodeToString(session)).commit())
        val repository = AuthRepository(context)

        val restored = withContext(Dispatchers.Main) { repository.restoreSession() }

        assertEquals(session, restored)
        assertFalse(legacy.contains("session"))
        assertTrue(base.getSharedPreferences(prefix + "auth_session_secure", Context.MODE_PRIVATE)
            .contains("session_ciphertext"))
        assertTrue(readsOnBackground.get())
        assertFalse(readsOnMain.get())
    }

    @Test
    fun unavailableLegacyStorageDoesNotCrashOrDeleteTheSession() = runBlocking {
        val legacy = base.getSharedPreferences(prefix + "auth_session", Context.MODE_PRIVATE)
        assertTrue(legacy.edit().putString("session", "original-session").commit())
        failLegacyRead = true
        val repository = AuthRepository(context)

        assertNull(withContext(Dispatchers.Main) { repository.restoreSession() })

        assertEquals("original-session", legacy.getString("session", null))
        assertTrue(readsOnBackground.get())
        assertFalse(readsOnMain.get())
    }

    @Test
    fun pendingRecordingScanAndDurationReadRunOffMainThread() = runBlocking {
        val recordings = File(directory, "PendingRecordings").apply { mkdirs() }
        val pending = File(recordings, "incomplete.m4a").apply { writeText("incomplete recording") }
        val manager = RecordingFileManager(context)

        val result = withContext(Dispatchers.Main) { manager.pendingRecordings() }

        assertEquals(listOf(pending), result.map { it.file })
        assertEquals(0L, result.single().durationMillis)
        assertTrue(pending.isFile)
        assertTrue(readsOnBackground.get())
        assertFalse(readsOnMain.get())
    }

    private fun recordRead() {
        if (Looper.myLooper() == Looper.getMainLooper()) readsOnMain.set(true)
        else readsOnBackground.set(true)
    }
}
