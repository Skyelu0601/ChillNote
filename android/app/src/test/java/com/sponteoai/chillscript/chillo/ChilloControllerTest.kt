package com.sponteoai.chillscript.chillo

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test

class ChilloControllerTest {
    private class FakeApi(var consent: Int = 1) : ChilloDataSource {
        override val json = Json { ignoreUnknownKeys = true }
        var failFirstSend = false
        var sendStarted: CompletableDeferred<Unit>? = null
        var sendGate: CompletableDeferred<Unit>? = null
        var historyStarted: CompletableDeferred<Unit>? = null
        var historyGate: CompletableDeferred<Unit>? = null
        val sent = mutableListOf<JsonObject>()
        override suspend fun request(path: String, method: String, body: JsonObject?): JsonObject = when {
            path == "/library" -> json.parseToJsonElement("""{"total":1,"available":1,"indexed":0,"pending":0,"consentVersion":$consent}""").jsonObject
            path == "/conversations" && method == "GET" -> {
                historyStarted?.complete(Unit)
                historyGate?.await()
                buildJsonObject { put("conversations", JsonArray(emptyList())) }
            }
            path == "/conversations" -> buildJsonObject { put("id", body!!.getValue("id")); put("title", "") }
            path.endsWith("/turns") -> {
                sent += body!!
                sendStarted?.complete(Unit)
                sendGate?.await()
                if (failFirstSend && sent.size == 1) throw ChilloApi.Failure("REQUEST_FAILED")
                buildJsonObject { put("id", body.getValue("id")); put("request", body.getValue("message")); put("answer", ""); put("status", "queued") }
            }
            else -> error("Unexpected test request: $path")
        }
    }

    @Test fun openingAndTypingNeverOptInOrSendAutomatically() = runBlocking {
        val api = FakeApi(consent = 0)
        val controller = ChilloController(api)
        controller.load(); controller.input("Create something"); controller.send()
        assertTrue(controller.state.value.needsConsent)
        assertTrue(api.sent.isEmpty())
    }

    @Test fun failedSubmissionRetriesWithSameIdAndPreservesInput() = runBlocking {
        val api = FakeApi().apply { failFirstSend = true }
        val controller = ChilloController(api)
        controller.load(); controller.input("  Write a script  "); controller.send()
        assertEquals("  Write a script  ", controller.state.value.input)
        assertFalse(controller.state.value.busy)
        controller.send()
        assertEquals(2, api.sent.size)
        assertEquals(api.sent[0]["id"], api.sent[1]["id"])
        assertEquals("Write a script", api.sent[1]["message"]!!.jsonPrimitive.content)
        assertEquals("", controller.state.value.input)
        assertTrue(controller.state.value.generating)
        controller.input("Follow-up"); controller.send()
        assertEquals(2, api.sent.size)
    }

    @Test fun sendingShowsMessageBeforeNetworkResponds() = runBlocking {
        val started = CompletableDeferred<Unit>()
        val gate = CompletableDeferred<Unit>()
        val api = FakeApi().apply { sendStarted = started; sendGate = gate }
        val controller = ChilloController(api)
        controller.load()
        controller.input("Write a script")
        val sending = launch { controller.send() }
        started.await()
        assertEquals("Write a script", controller.state.value.submittingMessage)
        assertEquals("", controller.state.value.input)
        assertTrue(controller.state.value.busy)
        gate.complete(Unit)
        sending.join()
        assertNull(controller.state.value.submittingMessage)
        assertEquals("Write a script", controller.state.value.turns.single().request)
    }

    @Test fun acceptedTurnReplacesSendingBubbleBeforeHistoryRefresh() = runBlocking {
        val historyStarted = CompletableDeferred<Unit>()
        val historyGate = CompletableDeferred<Unit>()
        val api = FakeApi()
        val controller = ChilloController(api)
        controller.load()
        api.historyStarted = historyStarted
        api.historyGate = historyGate
        controller.input("hi")
        val sending = launch { controller.send() }
        historyStarted.await()
        assertEquals("hi", controller.state.value.turns.single().request)
        assertNull(controller.state.value.submittingMessage)
        historyGate.complete(Unit)
        sending.join()
    }

    @Test fun failedSendKeepsTextTypedDuringSubmission() = runBlocking {
        val started = CompletableDeferred<Unit>()
        val gate = CompletableDeferred<Unit>()
        val api = FakeApi().apply { failFirstSend = true; sendStarted = started; sendGate = gate }
        val controller = ChilloController(api)
        controller.load()
        controller.input("First idea")
        val sending = launch { controller.send() }
        started.await()
        controller.input("Next idea")
        gate.complete(Unit)
        sending.join()
        assertEquals("First idea\nNext idea", controller.state.value.input)
        assertNull(controller.state.value.submittingMessage)
    }

    @Test fun aNewConversationResetsLocalScopeAndPendingMessage() = runBlocking {
        val api = FakeApi()
        val controller = ChilloController(api)
        controller.load(); controller.input("First"); controller.send()
        val first = controller.state.value.conversationId
        controller.newConversation()
        assertNull(controller.state.value.conversationId)
        assertTrue(controller.state.value.turns.isEmpty())
        controller.input("Second"); controller.send()
        assertNotEquals(first, controller.state.value.conversationId)
    }
}
