package com.sponteoai.chillscript.chillo

import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test

class ChilloControllerTest {
    private class FakeApi(var consent: Int = 1) : ChilloDataSource {
        override val json = Json { ignoreUnknownKeys = true }
        var failFirstSend = false
        val sent = mutableListOf<JsonObject>()
        override suspend fun request(path: String, method: String, body: JsonObject?): JsonObject = when {
            path == "/library" -> json.parseToJsonElement("""{"total":1,"available":1,"indexed":0,"pending":0,"consentVersion":$consent}""").jsonObject
            path == "/conversations" && method == "GET" -> buildJsonObject { put("conversations", JsonArray(emptyList())) }
            path == "/conversations" -> buildJsonObject { put("id", body!!.getValue("id")); put("title", "") }
            path.endsWith("/turns") -> {
                sent += body!!
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
