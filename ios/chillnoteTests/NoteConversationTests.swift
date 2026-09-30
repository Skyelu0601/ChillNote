import XCTest
import SwiftData
@testable import chillnote

@MainActor
final class NoteConversationTests: XCTestCase {
    private var directory: URL!
    override func setUp() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }
    override func tearDown() { try? FileManager.default.removeItem(at: directory) }

    private func dependencies(_ generate: @escaping (String, String, Bool) async throws -> String = { _, _, _ in "New script" }) -> NoteConversationStore.Dependencies {
        var deps = NoteConversationStore.Dependencies()
        deps.consent = { true }; deps.authorized = { _ in true }
        deps.generate = generate; deps.refreshCredits = {}
        return deps
    }
    private func finish(_ store: NoteConversationStore) async {
        for _ in 0..<300 {
            if !store.busy { return }
            await Task.yield()
        }
        XCTFail("Conversation did not finish")
    }

    func testSkillThenFollowUpCarriesConversationAndLatestNote() async throws {
        let note = Note(content: "Original transcript", userId: "account")
        var prompts: [String] = []
        var usage: [Bool] = []
        let store = NoteConversationStore(note: note, directory: directory, dependencies: dependencies { prompt, _, skill in
            prompts.append(prompt); usage.append(skill); return "Generated draft \(prompts.count)"
        })
        let recipe = try XCTUnwrap(AgentRecipe.allRecipes.first { $0.id == "rewrite" })
        store.send(recipe: recipe)
        await finish(store)
        XCTAssertEqual(store.turns.first?.recipe?.id, "rewrite")
        XCTAssertEqual(note.content, "Original transcript")
        store.input = "Make the opening shorter"
        store.send()
        await finish(store)
        XCTAssertEqual(store.turns.count, 2)
        XCTAssertEqual(usage, [true, false])
        XCTAssertTrue(prompts[1].contains("Generated draft 1"))
        XCTAssertTrue(prompts[1].contains("Make the opening shorter"))
        note.updateContent("Manually revised note")
        store.send(recipe: recipe)
        await finish(store)
        let payload = try JSONSerialization.jsonObject(with: Data(prompts[2].utf8)) as! [String: Any]
        XCTAssertEqual(payload["currentNote"] as? String, "Manually revised note")
        XCTAssertEqual(payload["currentNoteChanged"] as? Bool, true)
        XCTAssertNil(payload["workingDraft"])
    }

    func testAnalysisIsHistoryNotAutomaticallyPromotedToDraft() throws {
        let rewrite = try XCTUnwrap(AgentRecipe.allRecipes.first { $0.id == "rewrite" })
        let analysis = try XCTUnwrap(AgentRecipe.allRecipes.first { $0.id == "why_viral" })
        let fingerprint = NoteConversationPrompt.fingerprint("Original")
        let history = [
            NoteConversationTurn(message: "Rewrite", recipe: rewrite, answer: "Draft", noteFingerprint: fingerprint),
            NoteConversationTurn(message: "Why Viral", recipe: analysis, answer: "Analysis", noteFingerprint: fingerprint)
        ]
        let result = NoteConversationPrompt.build(content: "Original", history: history, message: "Rewrite", recipe: rewrite)
        let payload = try JSONSerialization.jsonObject(with: Data(result.prompt.utf8)) as! [String: Any]
        XCTAssertNil(payload["workingDraft"])
        XCTAssertEqual(payload["request"] as? String, NoteConversationPrompt.instruction(for: rewrite))
        let turns = try XCTUnwrap(payload["recentConversation"] as? [[String: Any]])
        XCTAssertEqual(turns.map { $0["assistant"] as? String }, ["Draft", "Analysis"])
        XCTAssertEqual(turns.last?["skillID"] as? String, "why_viral")
        XCTAssertFalse(result.system.contains("not a chat message"))
    }

    func testCustomInstructionsAndSavedDefaultsSurviveFollowUpAndArchive() throws {
        let custom = AgentRecipe(id: "rewrite", systemIcon: "star", name: "Custom", description: "", prompt: "Only write haiku", category: .shape, isCustom: true)
        XCTAssertEqual(NoteConversationPrompt.instruction(for: custom), custom.prompt)
        XCTAssertEqual(NoteConversationPrompt.defaults(for: custom), "")
        let recipe = try XCTUnwrap(AgentRecipe.allRecipes.first { $0.id == "timed_script" })
        let turn = NoteConversationTurn(message: "Script", recipe: recipe, answer: "Draft", noteFingerprint: NoteConversationPrompt.fingerprint("Source"), savedDefaults: "Duration: 60 seconds.")
        let archive = NoteConversationArchive(userID: "A", noteID: UUID(), directory: directory)
        try archive.save([turn])
        let loaded = try archive.load()
        XCTAssertEqual(loaded.first?.savedDefaults, turn.savedDefaults)
        let result = NoteConversationPrompt.build(content: "Source", history: loaded, message: "Shorter sentences", recipe: nil)
        XCTAssertTrue(result.prompt.contains("Duration: 60 seconds."))
        XCTAssertFalse(result.system.contains("105-130"))
        let legacy = try JSONEncoder().encode(turn)
        var object = try JSONSerialization.jsonObject(with: legacy) as! [String: Any]
        object.removeValue(forKey: "savedDefaults")
        let decoded = try JSONDecoder().decode(NoteConversationTurn.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(decoded.savedDefaults)
    }

    func testChatSkillsDoNotReuseStandaloneTemplates() throws {
        let hook = try XCTUnwrap(AgentRecipe.allRecipes.first { $0.id == "hook_generator" })
        XCTAssertTrue(hook.generationRequest(from: "Source").prompt.contains("8 distinct"))
        let chat = NoteConversationPrompt.build(content: "Source", history: [], message: "Hook", recipe: hook)
        XCTAssertFalse(chat.prompt.contains("8 distinct"))
        let translate = try XCTUnwrap(AgentRecipe.allRecipes.first { $0.id == "translate" })
        let request = NoteConversationPrompt.build(content: "Source", history: [], message: "Translate", recipe: translate)
        XCTAssertTrue(request.prompt.contains("ask which language"))
        XCTAssertFalse(request.system.contains("Translate into English"))
    }

    func testRepeatedTapsDuringConsentCannotQueueExtraRequestsAndDeclinePreservesInput() async {
        let note = Note(content: "Source", userId: "account")
        var consent: CheckedContinuation<Bool, Never>?
        var generations = 0
        var deps = dependencies { _, _, _ in generations += 1; return "Result" }
        deps.consent = { await withCheckedContinuation { consent = $0 } }
        let store = NoteConversationStore(note: note, directory: directory, dependencies: deps)
        store.input = "Rewrite this"
        store.send()
        while consent == nil { await Task.yield() }
        store.send()
        consent?.resume(returning: false)
        await finish(store)
        XCTAssertEqual(generations, 0)
        XCTAssertTrue(store.turns.isEmpty)
        XCTAssertEqual(store.input, "Rewrite this")
    }

    func testReplaceAndUndoPreserveConversationAndDoNotOverwriteNewEdits() async throws {
        let note = Note(content: "Original", userId: "account")
        let store = NoteConversationStore(note: note, directory: directory, dependencies: dependencies())
        store.input = "Rewrite"; store.send(); await finish(store)
        let reply = try XCTUnwrap(store.turns.first)
        let save: (String) -> Bool = { note.updateContent($0); return true }
        store.replace(with: reply, save: save)
        XCTAssertEqual(note.content, "New script")
        XCTAssertTrue(store.canUndo(currentContent: note.content))
        XCTAssertEqual(store.turns.count, 1)
        store.undo(save: save)
        XCTAssertEqual(note.content, "Original")
        store.replace(with: reply, save: save)
        note.updateContent("New manual edits")
        store.undo(save: save)
        XCTAssertEqual(note.content, "New manual edits")
        store.replace(with: reply, save: { _ in false })
        XCTAssertEqual(note.content, "New manual edits")
        XCTAssertNotNil(store.error)
    }

    func testEmptyResponseFailsAndRetryUpdatesSameTurn() async {
        let note = Note(content: "Keep this", userId: "account")
        var requests = 0
        let store = NoteConversationStore(note: note, directory: directory, dependencies: dependencies { _, _, _ in
            requests += 1; return requests == 1 ? " \n" : "Recovered"
        })
        store.input = "Rewrite"; store.send(); await finish(store)
        XCTAssertTrue(store.turns[0].failed)
        XCTAssertNil(store.turns[0].answer)
        let id = store.turns[0].id
        store.retry(store.turns[0]); await finish(store)
        XCTAssertEqual(store.turns.count, 1)
        XCTAssertEqual(store.turns[0].id, id)
        XCTAssertEqual(store.turns[0].answer, "Recovered")
        XCTAssertEqual(note.content, "Keep this")
    }

    func testCancelledLateAnswerAndAccountChangeCannotBeApplied() async {
        let note = Note(content: "Original", userId: "account")
        var response: CheckedContinuation<String, Never>?
        var allowed = true
        var deps = dependencies { _, _, _ in await withCheckedContinuation { response = $0 } }
        deps.authorized = { _ in allowed }
        let store = NoteConversationStore(note: note, directory: directory, dependencies: deps)
        store.input = "Rewrite"; store.send()
        while response == nil { await Task.yield() }
        store.cancel()
        response?.resume(returning: "Late result")
        for _ in 0..<10 { await Task.yield() }
        XCTAssertNil(store.turns.first?.answer)
        XCTAssertTrue(store.turns.first?.failed == true)
        allowed = false
        store.send()
        XCTAssertFalse(store.busy)
        XCTAssertEqual(store.turns.count, 1)
    }

    func testHistorySurvivesReopeningAndIsIsolatedByNoteAndAccount() throws {
        let noteID = UUID()
        let archive = NoteConversationArchive(userID: "A", noteID: noteID, directory: directory)
        let pending = NoteConversationTurn(message: "Rewrite", noteFingerprint: "hash")
        try archive.save([pending])
        XCTAssertTrue(try archive.load()[0].failed)
        XCTAssertTrue(try NoteConversationArchive(userID: "B", noteID: noteID, directory: directory).load().isEmpty)
        XCTAssertTrue(try NoteConversationArchive(userID: "A", noteID: UUID(), directory: directory).load().isEmpty)
    }

    func testReplacePersistsBodyWithoutChangingSourceAndCanBeUndone() async throws {
        let container = try ModelContainer(for: Note.self, Tag.self, ChecklistItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let note = Note(content: "Original transcript", userId: "account")
        note.sourceURL = "https://example.com/video"
        note.sourceTitle = "Source video"
        container.mainContext.insert(note)
        try container.mainContext.save()
        let model = NoteDetailViewModel(note: note)
        model.configureForTesting(modelContext: container.mainContext)
        let store = NoteConversationStore(note: note, directory: directory, dependencies: dependencies())
        store.input = "Rewrite"; store.send(); await finish(store)
        store.replace(with: try XCTUnwrap(store.turns.first), save: model.replaceConversationContent)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Note>()).first?.content, "New script")
        XCTAssertEqual(note.sourceURL, "https://example.com/video")
        XCTAssertEqual(note.sourceTitle, "Source video")
        store.undo(save: model.replaceConversationContent)
        XCTAssertEqual(note.content, "Original transcript")
    }
}
