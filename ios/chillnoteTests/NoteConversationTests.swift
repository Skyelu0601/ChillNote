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

    func testLegacySkillCategoriesAreIgnoredAndNotSavedAgain() throws {
        for category in ["Think", "Shape", "Publish"] {
            let legacy: [String: Any] = [
                "id": "custom_legacy", "systemIcon": "star", "name": "My skill",
                "description": "My description", "prompt": "Keep my instructions",
                "category": category, "isCustom": true
            ]
            let data = try JSONSerialization.data(withJSONObject: [legacy])
            let recipe = try XCTUnwrap(JSONDecoder().decode([AgentRecipe].self, from: data).first)
            XCTAssertTrue(recipe.isCustom)
            XCTAssertEqual(recipe.prompt, "Keep my instructions")
            let encoded = try JSONEncoder().encode(recipe)
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
            XCTAssertNil(object["category"])
            XCTAssertEqual(try JSONDecoder().decode(AgentRecipe.self, from: encoded), recipe)

            let turn = NoteConversationTurn(message: "My skill", recipe: recipe, answer: "Saved result", noteFingerprint: "old")
            var oldTurn = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(turn)) as? [String: Any])
            oldTurn["recipe"] = legacy
            let archive = NoteConversationArchive(userID: "account", noteID: UUID(), directory: directory)
            try FileManager.default.createDirectory(at: archive.url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: [oldTurn]).write(to: archive.url)
            let loaded = try archive.load()
            XCTAssertEqual(loaded.first?.recipe, recipe)
            XCTAssertEqual(loaded.first?.answer, "Saved result")
            try archive.save(loaded)
            XCTAssertFalse(try String(contentsOf: archive.url, encoding: .utf8).contains("\"category\""))
        }
    }

    func testTitleThumbnailUsesApprovedPromptInStandaloneAndConversation() throws {
        let recipe = try XCTUnwrap(AgentRecipe.allRecipes.first { $0.id == "title_thumbnail" })
        let source = "A tutorial about organizing saved ideas"
        let standalone = recipe.generationRequest(from: source)
        XCTAssertTrue(standalone.prompt.contains(recipe.prompt))
        XCTAssertTrue(standalone.prompt.contains(source))
        let history = [NoteConversationTurn(message: "Use a calm tone for beginners", answer: "Agreed", noteFingerprint: NoteConversationPrompt.fingerprint(source))]
        let result = NoteConversationPrompt.build(content: source, history: history, message: recipe.name, recipe: recipe)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(result.prompt.utf8)) as? [String: Any])
        XCTAssertEqual(payload["request"] as? String, recipe.prompt)
        XCTAssertEqual(payload["currentNote"] as? String, source)
        XCTAssertTrue(result.prompt.contains("Use a calm tone for beginners"))
        XCTAssertTrue(result.system.contains("Follow the latest user request"))
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

    func testTimedScriptIsRetiredFromLibrary() {
        XCTAssertFalse(AgentRecipe.allRecipes.contains { $0.id == "timed_script" })
        XCTAssertTrue(RecipeManager.retiredRecipeIds.contains("timed_script"))
    }

    func testCustomInstructionsAndSavedDefaultsSurviveFollowUpAndArchive() throws {
        let custom = AgentRecipe(id: "rewrite", systemIcon: "star", name: "Custom", description: "", prompt: "Only write haiku", isCustom: true)
        XCTAssertEqual(NoteConversationPrompt.instruction(for: custom), custom.prompt)
        XCTAssertEqual(NoteConversationPrompt.defaults(for: custom), "")
        let recipe = try XCTUnwrap(AgentRecipe.allRecipes.first { $0.id == "caption_pack" })
        let turn = NoteConversationTurn(message: "Script", recipe: recipe, answer: "Draft", noteFingerprint: NoteConversationPrompt.fingerprint("Source"), savedDefaults: "Platforms: TikTok.")
        let archive = NoteConversationArchive(userID: "A", noteID: UUID(), directory: directory)
        try archive.save([turn])
        let loaded = try archive.load()
        XCTAssertEqual(loaded.first?.savedDefaults, turn.savedDefaults)
        let result = NoteConversationPrompt.build(content: "Source", history: loaded, message: "Shorter sentences", recipe: nil)
        XCTAssertTrue(result.prompt.contains("Platforms: TikTok."))
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
        XCTAssertTrue(request.prompt.contains("default target language in savedDefaults"))
        XCTAssertFalse(request.system.contains("Translate into English"))
    }

    func testTranslateDefaultIsSharedByStandaloneAndConversationAndCanBeOverridden() throws {
        let defaults = UserDefaults.standard
        let key = TranslatePreferences.targetLanguageKey
        let previous = defaults.object(forKey: key)
        defer {
            if let previous { defaults.set(previous, forKey: key) }
            else { defaults.removeObject(forKey: key) }
        }
        defaults.set("fr", forKey: key)
        let translate = try XCTUnwrap(AgentRecipe.allRecipes.first { $0.id == "translate" })
        XCTAssertTrue(translate.generationRequest(from: "Hello").prompt.contains("into French"))
        XCTAssertTrue(translate.generationRequest(from: "Hello", userInstruction: "Japanese").prompt.contains("into Japanese"))
        let request = NoteConversationPrompt.build(content: "Hello", history: [], message: "Translate", recipe: translate)
        let payload = try JSONSerialization.jsonObject(with: Data(request.prompt.utf8)) as! [String: Any]
        XCTAssertEqual(payload["savedDefaults"] as? String, "Default target language: French.")
        defaults.set("pt-PT", forKey: key)
        XCTAssertEqual(TranslatePreferences.currentLanguage.name, "Portuguese")
        XCTAssertEqual(TranslatePreferences.currentLanguage.displayName, "Português")
        defaults.set("pt-BR", forKey: key)
        XCTAssertEqual(TranslatePreferences.currentLanguage.name, "Portuguese")
        XCTAssertEqual(TranslateLanguage.defaultLanguages.filter { $0.name == "Portuguese" }.count, 1)
        defaults.set("invalid", forKey: key)
        XCTAssertEqual(TranslatePreferences.currentLanguage.id, "en")
    }

    func testBrandVoiceExamplesMigrationAndDeletion() throws {
        let suite = "brand-voice-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("Legacy writing", forKey: BrandVoicePreferences.sampleKey)
        defaults.set("Old tone", forKey: "brandVoiceTone")
        XCTAssertEqual(BrandVoicePreferences.load(from: defaults).samples, ["Legacy writing"])
        var preferences = BrandVoicePreferences(samples: ["First example", "  ", "Second example"])
        preferences.save(to: defaults)
        XCTAssertEqual(BrandVoicePreferences.load(from: defaults).samples, ["First example", "Second example"])
        XCTAssertTrue(preferences.promptProfile.contains("Writing example 2:\nSecond example"))
        XCTAssertFalse(preferences.promptProfile.contains("Old tone"))
        preferences.samples = []
        preferences.save(to: defaults)
        XCTAssertFalse(BrandVoicePreferences.load(from: defaults).isConfigured)
        XCTAssertEqual(BrandVoicePreferences.load(from: defaults).samples, [])
    }

    func testRepurposeDefaultsAndLegacySelections() throws {
        let suite = "repurpose-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(RepurposePackPreferences.load(from: defaults).selectedFormats, [.tiktok, .instagramReels])
        defaults.set(true, forKey: "repurposePackFormatInstagramCarousel")
        XCTAssertEqual(RepurposePackPreferences.load(from: defaults).selectedFormats, [.tiktok, .instagramReels])
        defaults.set(true, forKey: "repurposePackFormatXPost")
        XCTAssertEqual(RepurposePackPreferences.load(from: defaults).selectedFormats, [.xPost])
        var preferences = RepurposePackPreferences(formats: [.youtubeShorts, .newsletter])
        preferences.longVideoMinutes = 8
        defaults.set(90, forKey: "repurposePackShortVideoSeconds")
        defaults.set("bold", forKey: "repurposePackTone")
        defaults.set(true, forKey: "repurposePackIncludeCTA")
        preferences.save(to: defaults)
        let reopened = RepurposePackPreferences.load(from: defaults)
        XCTAssertEqual(reopened.selectedFormats, [.youtubeShorts, .newsletter])
        XCTAssertEqual(reopened.longVideoMinutes, 8)
        XCTAssertEqual(reopened.lengthInstruction, "")
    }

    func testRepurposeNativeFormatRulesReachBothEntrypoints() throws {
        let defaults = UserDefaults.standard
        let keys = RepurposeFormat.allCases.map(\.rawValue) + [RepurposePackPreferences.threadLengthKey,
            "repurposePackTone", "repurposePackIncludeCTA",
            "repurposePackShortVideoSeconds", RepurposePackPreferences.longVideoMinutesKey]
        let previous = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, previous) {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
        }
        defaults.set("bold", forKey: "repurposePackTone")
        defaults.set(true, forKey: "repurposePackIncludeCTA")
        defaults.set(90, forKey: "repurposePackShortVideoSeconds")
        RepurposePackPreferences(formats: [.youtubeVideo, .newsletter], longVideoMinutes: 8).save()
        let recipe = try XCTUnwrap(AgentRecipe.allRecipes.first { $0.id == "repurpose_pack" })
        let standalone = recipe.generationRequest(from: "My edited draft")
        XCTAssertTrue(standalone.prompt.contains("My edited draft"))
        XCTAssertTrue(standalone.prompt.contains("8 minutes"))
        XCTAssertFalse(standalone.prompt.contains("Tone:"))
        XCTAssertFalse(standalone.system.contains("call to action"))
        XCTAssertTrue(standalone.system.contains("complete email with a subject line"))
        let chat = NoteConversationPrompt.build(content: "My edited draft", history: [], message: "Repurpose", recipe: recipe)
        let payload = try JSONSerialization.jsonObject(with: Data(chat.prompt.utf8)) as! [String: Any]
        let saved = try XCTUnwrap(payload["savedDefaults"] as? String)
        XCTAssertTrue(saved.contains("8 minutes"))
        XCTAssertFalse(saved.contains("Tone:"))
        XCTAssertFalse(saved.contains("Include CTA"))
        XCTAssertFalse(saved.contains("Short video target:"))
        XCTAssertTrue(saved.contains("complete email with a subject line"))
        XCTAssertTrue(saved.contains("## YouTube Video"))
        XCTAssertFalse(saved.contains("## TikTok"))
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

    func testUseThisCompactsAISeparatorsAndUndoRestoresExactOriginal() async throws {
        let original = "Original\n\n\nKeep my blank lines\n"
        let answer = "\n# Heading\r\n\r\nFirst paragraph\n \n\n- Item one\n\n- Item two\n\n```swift\nlet value = 1\n\nprint(value)\n```\n\n"
        let expected = "# Heading\nFirst paragraph\n- Item one\n- Item two\n```swift\nlet value = 1\n\nprint(value)\n```"
        let note = Note(content: original, userId: "account")
        let store = NoteConversationStore(note: note, directory: directory, dependencies: dependencies { _, _, _ in answer })
        store.input = "Rewrite"; store.send(); await finish(store)
        let turn = try XCTUnwrap(store.turns.first)
        let save: (String) -> Bool = { note.updateContent($0); return true }
        store.replace(with: turn, save: save)
        XCTAssertEqual(note.content, expected)
        XCTAssertEqual(store.appliedTurnID, turn.id)
        XCTAssertEqual(store.turns.first?.answer, answer)
        XCTAssertTrue(store.canUndo(currentContent: note.content))
        store.replace(with: turn, save: save)
        store.undo(save: save)
        XCTAssertEqual(note.content, original)
        XCTAssertNil(store.appliedTurnID)
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

    func testClearRemovesArchiveButKeepsNoteDraftAndOtherNoteHistory() async throws {
        let note = Note(content: "Original", userId: "account")
        let other = Note(content: "Other note", userId: "account")
        let otherArchive = NoteConversationArchive(userID: other.userId, noteID: other.id, directory: directory)
        try otherArchive.save([NoteConversationTurn(message: "Keep", answer: "Other answer", noteFingerprint: "hash")])
        let store = NoteConversationStore(note: note, directory: directory, dependencies: dependencies())
        store.input = "Rewrite"; store.send(); await finish(store)
        store.input = "Unsent draft"
        store.clearConversation()
        XCTAssertTrue(store.turns.isEmpty)
        XCTAssertEqual(note.content, "Original")
        XCTAssertEqual(store.input, "Unsent draft")
        let reopened = NoteConversationStore(note: note, directory: directory, dependencies: dependencies())
        XCTAssertTrue(reopened.turns.isEmpty)
        XCTAssertEqual(try otherArchive.load().count, 1)
    }

    func testClearCancelsGenerationAndRejectsLateAnswer() async {
        let note = Note(content: "Original", userId: "account")
        var response: CheckedContinuation<String, Never>?
        let store = NoteConversationStore(note: note, directory: directory, dependencies: dependencies { _, _, _ in
            await withCheckedContinuation { response = $0 }
        })
        store.input = "Rewrite"; store.send()
        while response == nil { await Task.yield() }
        store.clearConversation()
        response?.resume(returning: "Late answer")
        for _ in 0..<10 { await Task.yield() }
        XCTAssertFalse(store.busy)
        XCTAssertTrue(store.turns.isEmpty)
        XCTAssertEqual(note.content, "Original")
        XCTAssertTrue(NoteConversationStore(note: note, directory: directory, dependencies: dependencies()).turns.isEmpty)
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
