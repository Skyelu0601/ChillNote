package com.sponteoai.chillscript.ai

import kotlinx.coroutines.*
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test

class NoteConversationTest {
    private fun controller(
        scope: CoroutineScope,
        consent: suspend () -> Boolean = { true },
        authorized: () -> Boolean = { true },
        generate: suspend (String, String, Boolean) -> String = { _, _, _ -> "New script" },
    ) = NoteConversationController(scope, { emptyList() }, {}, authorized, consent, generate, {}, {}, { _, _ -> })

    private suspend fun finish(controller: NoteConversationController) {
        withTimeout(2000) { while (controller.state.value.busy) yield() }
    }

    @Test fun skillAndFollowUpShareHistoryAndManualEditsWin() = runBlocking {
        val prompts = mutableListOf<String>()
        val usage = mutableListOf<Boolean>()
        val chat = controller(this, generate = { prompt, _, skill -> prompts += prompt; usage += skill; "Draft ${prompts.size}" })
        val recipe = BuiltInRecipes.all.first { it.id == "rewrite" }
        chat.send("Original", "Rewrite", recipe); finish(chat)
        chat.send("Original", "Shorten the opening"); finish(chat)
        assertEquals(listOf(true, false), usage)
        assertTrue(prompts[1].contains("Draft 1"))
        assertTrue(prompts[1].contains("Shorten the opening"))
        chat.send("Manual edits", "Rewrite", recipe); finish(chat)
        val payload = Json.parseToJsonElement(prompts[2]).jsonObject
        assertEquals("Manual edits", payload["currentNote"]!!.jsonPrimitive.content)
        assertTrue(payload["currentNoteChanged"]!!.jsonPrimitive.boolean)
        assertFalse(payload.containsKey("workingDraft"))
    }

    @Test fun analysisStaysInHistoryAndIsNotPromotedToDraft() {
        val rewrite = BuiltInRecipes.all.first { it.id == "rewrite" }
        val analysis = BuiltInRecipes.all.first { it.id == "why_viral" }
        val fingerprint = NoteConversationPrompt.fingerprint("Original")
        val history = listOf(
            NoteConversationTurn(message = "Rewrite", recipe = rewrite, answer = "Draft", noteFingerprint = fingerprint),
            NoteConversationTurn(message = "Why Viral", recipe = analysis, answer = "Analysis", noteFingerprint = fingerprint),
        )
        val (prompt, system) = NoteConversationPrompt.build("Original", history, "Rewrite", rewrite)
        val payload = Json.parseToJsonElement(prompt).jsonObject
        assertFalse(payload.containsKey("workingDraft"))
        assertEquals(NoteConversationPrompt.instruction(rewrite), payload["request"]!!.jsonPrimitive.content)
        val turns = payload["recentConversation"]!!.jsonArray
        assertEquals(listOf("Draft", "Analysis"), turns.map { it.jsonObject["assistant"]!!.jsonPrimitive.content })
        assertEquals("why_viral", turns.last().jsonObject["skillID"]!!.jsonPrimitive.content)
        assertFalse(system.contains("not a chat message"))
    }

    @Test fun customInstructionsAndDefaultsSurviveFollowUpAndArchive() {
        val custom = BuiltInRecipes.all.first { it.id == "rewrite" }.copy(isCustom = true, prompt = "Only write haiku")
        assertEquals(custom.prompt, NoteConversationPrompt.instruction(custom))
        assertEquals("", NoteConversationPrompt.defaults(custom))
        val root = kotlin.io.path.createTempDirectory().toFile()
        try {
            val recipe = BuiltInRecipes.all.first { it.id == "timed_script" }
            val turn = NoteConversationTurn(message = "Script", recipe = recipe, answer = "Draft", noteFingerprint = NoteConversationPrompt.fingerprint("Source"), savedDefaults = "Duration: 60 seconds.")
            val archive = NoteConversationArchive(root, "A", "note")
            archive.save(listOf(turn))
            val loaded = archive.load()
            assertEquals(turn.savedDefaults, loaded.single().savedDefaults)
            val (prompt, system) = NoteConversationPrompt.build("Source", loaded, "Shorter sentences", null)
            assertTrue(prompt.contains("Duration: 60 seconds."))
            assertFalse(system.contains("105-130"))
            val old = """{"message":"Old request","noteFingerprint":"hash"}"""
            assertNull(Json.decodeFromString<NoteConversationTurn>(old).savedDefaults)
        } finally { root.deleteRecursively() }
    }

    @Test fun chatSkillsDoNotReuseStandaloneTemplates() {
        val hook = BuiltInRecipes.all.first { it.id == "hook_generator" }
        assertTrue(hook.requestPrompts("Source").first.contains("8 distinct"))
        val (prompt, _) = NoteConversationPrompt.build("Source", emptyList(), "Hook", hook)
        assertFalse(prompt.contains("8 distinct"))
    }

    @Test fun consentDeclineAndRepeatedTapsNeverGenerate() = runBlocking {
        val gate = CompletableDeferred<Boolean>()
        var requests = 0
        val chat = controller(this, consent = { gate.await() }, generate = { _, _, _ -> requests++; "Result" })
        chat.send("Original", "Rewrite"); yield()
        chat.send("Original", "Rewrite")
        gate.complete(false); finish(chat)
        assertEquals(0, requests)
        assertTrue(chat.state.value.turns.isEmpty())
    }

    @Test fun emptyAnswerFailsAndRetryUsesSameTurn() = runBlocking {
        var requests = 0
        val chat = controller(this, generate = { _, _, _ -> requests++; if (requests == 1) " \n" else "Recovered" })
        chat.send("Original", "Rewrite"); finish(chat)
        val turn = chat.state.value.turns.single()
        assertTrue(turn.failed); assertNull(turn.answer)
        chat.retry("Original", turn); finish(chat)
        assertEquals(turn.id, chat.state.value.turns.single().id)
        assertEquals("Recovered", chat.state.value.turns.single().answer)
    }

    @Test fun cancelAndAccountChangeCannotAcceptLateReply() = runBlocking {
        val gate = CompletableDeferred<String>()
        var allowed = true
        val chat = controller(this, authorized = { allowed }, generate = { _, _, _ -> gate.await() })
        chat.send("Original", "Rewrite"); yield()
        chat.cancel(); gate.complete("Late result"); yield()
        assertNull(chat.state.value.turns.single().answer)
        assertTrue(chat.state.value.turns.single().failed)
        allowed = false; chat.send("Original", "Again")
        assertEquals(1, chat.state.value.turns.size)
    }

    @Test fun historyIsIsolatedAndInterruptedTurnsRecoverAsFailed() {
        val root = kotlin.io.path.createTempDirectory().toFile()
        try {
            val archive = NoteConversationArchive(root, "A", "note")
            archive.save(listOf(NoteConversationTurn(message = "Rewrite", noteFingerprint = "hash")))
            assertTrue(archive.load().single().failed)
            assertTrue(NoteConversationArchive(root, "B", "note").load().isEmpty())
            assertTrue(NoteConversationArchive(root, "A", "another").load().isEmpty())
        } finally { root.deleteRecursively() }
    }

    @Test fun replacementAndUndoPreserveManualEditsAndReportSaveFailure() = runBlocking {
        val chat = controller(this)
        chat.send("Original", "Rewrite"); finish(chat)
        val turn = chat.state.value.turns.single()
        var content = "Original"
        val apply: suspend (String) -> Boolean = { content = it; true }
        chat.replace(turn, content, apply)
        assertEquals("New script", content)
        assertEquals("Original", chat.state.value.undoContent)
        chat.replace(turn, content, apply)
        assertEquals("Original", chat.state.value.undoContent)
        chat.undo(content, apply)
        assertEquals("Original", content)
        chat.replace(turn, content, apply)
        content = "Manual changes"
        chat.undo(content, apply)
        assertEquals("Manual changes", content)
        chat.replace(turn, content) { false }
        assertEquals("Manual changes", content)
        assertTrue(chat.state.value.saveError)
    }

    @Test fun translateAsksForMissingLanguageWithoutChoosingEnglish() {
        val recipe = BuiltInRecipes.all.first { it.id == "translate" }
        val (prompt, system) = NoteConversationPrompt.build("Source", emptyList(), "Translate", recipe)
        assertTrue(prompt.contains("ask which language"))
        assertFalse(system.contains("Translate into English"))
    }

    @Test fun finishingSkillReleasesOnboardingAndRetryPreservesUnsentMessage() = runBlocking {
        var finished = 0
        var requests = 0
        val chat = NoteConversationController(this, { emptyList() }, {}, { true }, { true },
            { _, _, _ -> requests++; if (requests == 1) "" else "Result" }, {}, {}, { _, _ -> }, { finished++ })
        chat.send("Original", "Rewrite", BuiltInRecipes.all.first { it.id == "rewrite" }); finish(chat)
        assertEquals(1, finished)
        chat.input("An unsent follow-up")
        chat.retry("Original", chat.state.value.turns.single()); finish(chat)
        assertEquals(2, finished)
        assertEquals("An unsent follow-up", chat.state.value.input)
    }
}
