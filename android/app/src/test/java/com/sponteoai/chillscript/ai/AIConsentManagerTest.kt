package com.sponteoai.chillscript.ai

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class AIConsentManagerTest {
    private class Store(var version: String? = null) : AIConsentStore {
        override fun acceptedVersion() = version
        override fun accept(version: String) { this.version = version }
    }

    @Test fun declineThenRetryPromptsAndAcceptanceSurvivesNewManager() = runTest {
        val store = Store()
        val events = mutableListOf<String>()
        val manager = AIConsentManager(store) { event, _ -> events += event }
        val first = async { manager.ensureConsent(AIConsentTrigger.Text) }
        runCurrent()
        val firstId = manager.prompt.value!!.id
        manager.decline(firstId)
        assertFalse(first.await())
        val second = async { manager.ensureConsent(AIConsentTrigger.Text) }
        runCurrent()
        val secondId = manager.prompt.value!!.id
        assertNotEquals(firstId, secondId)
        manager.decline(firstId)
        assertEquals(secondId, manager.prompt.value!!.id)
        manager.accept(secondId)
        assertTrue(second.await())
        assertTrue(AIConsentManager(store) { _, _ -> }.ensureConsent(AIConsentTrigger.Audio))
        assertEquals(listOf("ai_consent_prompted", "ai_consent_declined", "ai_consent_prompted", "ai_consent_accepted"), events)
    }

    @Test fun concurrentRequestsSharePromptAndCancellationDoesNotAccept() = runTest {
        val store = Store()
        val manager = AIConsentManager(store) { _, _ -> }
        val first = async { manager.ensureConsent(AIConsentTrigger.Text) }
        runCurrent()
        val id = manager.prompt.value!!.id
        val second = async { manager.ensureConsent(AIConsentTrigger.Audio) }
        runCurrent()
        assertEquals(id, manager.prompt.value!!.id)
        first.cancel()
        runCurrent()
        assertEquals(id, manager.prompt.value!!.id)
        manager.accept(id)
        assertTrue(second.await())
        assertTrue(first.isCancelled)
    }

    @Test fun cancellingLastRequestDismissesWithoutSavingConsent() = runTest {
        val store = Store("old-version")
        val manager = AIConsentManager(store) { _, _ -> }
        val request = async { manager.ensureConsent(AIConsentTrigger.Text) }
        runCurrent()
        assertNotNull(manager.prompt.value)
        request.cancel()
        runCurrent()
        assertNull(manager.prompt.value)
        manager.accept()
        assertFalse(manager.hasAcceptedCurrentVersion())
    }
}
