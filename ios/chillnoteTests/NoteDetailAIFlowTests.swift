import XCTest
@testable import chillnote

@MainActor
final class NoteDetailAIFlowTests: XCTestCase {
    private let recipe = AgentRecipe(id: "test", systemIcon: "sparkles", name: "Test",
                                     description: "Test", prompt: "Test", category: .shape)

    func testDeclineThenRetryPromptsAndOnlyAcceptedActionGenerates() async {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let consent = AIConsentManager(userDefaults: defaults, capture: { _, _ in })
        var generations = 0
        var events: [String] = []
        var deps = NoteDetailViewModel.Dependencies()
        deps.ensureAIConsent = { await consent.ensureConsentIfNeeded(for: .text) }
        deps.generateAISkill = { _, _, _ in generations += 1; return "Result" }
        deps.refreshCredits = {}
        deps.capture = { events.append($0); _ = $1 }
        let model = NoteDetailViewModel(note: Note(content: "Source", userId: "test"), dependencies: deps)

        let first = Task { await model.generateAISkillPreview(recipe: recipe) }
        await Task.yield()
        XCTAssertNotNil(consent.activePrompt)
        XCTAssertTrue(model.isAwaitingAIConsent)
        XCTAssertFalse(model.isProcessing)
        // A repeated tap while waiting must not start a second request later.
        await model.generateAISkillPreview(recipe: recipe)
        consent.declineAIDataConsent()
        await first.value
        XCTAssertEqual(generations, 0)
        XCTAssertTrue(events.isEmpty)
        XCTAssertNil(model.aiSkillErrorMessage)

        let retry = Task { await model.generateAISkillPreview(recipe: recipe) }
        await Task.yield()
        XCTAssertNotNil(consent.activePrompt)
        consent.acceptAIDataConsent()
        await retry.value
        XCTAssertEqual(generations, 1)
        XCTAssertEqual(events, ["skill_run_started", "skill_run_completed"])
        XCTAssertEqual(model.aiSkillPreview?.result, "Result")
        XCTAssertFalse(model.isAwaitingAIConsent)
        XCTAssertFalse(model.isProcessing)
    }

    func testAcceptedNetworkFailureIsNotReportedAsConsentFailure() async {
        var events: [(String, [String: Any])] = []
        var deps = NoteDetailViewModel.Dependencies()
        deps.ensureAIConsent = { true }
        deps.generateAISkill = { _, _, _ in throw GeminiError.networkError(URLError(.timedOut)) }
        deps.capture = { events.append(($0, $1)) }
        let model = NoteDetailViewModel(note: Note(content: "Source", userId: "test"), dependencies: deps)
        await model.generateAISkillPreview(recipe: recipe)
        XCTAssertEqual(events.map(\.0), ["skill_run_started", "skill_run_failed"])
        XCTAssertEqual(events.last?.1["error_code"] as? String, "network_timeout")
        XCTAssertNotNil(model.aiSkillErrorMessage)
        XCTAssertFalse(model.isProcessing)
    }

    func testCreditsAndCancellationHaveSeparateTerminalEvents() async {
        for (error, expectedEvent) in [(GeminiError.insufficientCredits as Error, "skill_run_blocked"),
                                       (CancellationError() as Error, "skill_run_cancelled")] {
            var events: [String] = []
            var deps = NoteDetailViewModel.Dependencies()
            deps.ensureAIConsent = { true }
            deps.generateAISkill = { _, _, _ in throw error }
            deps.capture = { events.append($0); _ = $1 }
            let model = NoteDetailViewModel(note: Note(content: "Source", userId: "test"), dependencies: deps)
            await model.generateAISkillPreview(recipe: recipe)
            XCTAssertEqual(events, ["skill_run_started", expectedEvent])
            XCTAssertNil(model.aiSkillErrorMessage)
            XCTAssertEqual(model.showSubscription, expectedEvent == "skill_run_blocked")
            XCTAssertFalse(model.isProcessing)
        }
    }

    func testFailedRetryPreservesCurrentText() async {
        var deps = NoteDetailViewModel.Dependencies()
        deps.ensureAIConsent = { true }
        deps.generateAISkill = { _, _, _ in throw GeminiError.invalidResponse }
        deps.capture = { _, _ in }
        let note = Note(content: "User edits after applying AI", userId: "test")
        let model = NoteDetailViewModel(note: note, dependencies: deps)
        let preview = NoteAISkillPreview(analyticsRunID: "old", recipe: recipe, result: "Old result",
                                        sourceContent: "Original", sourceSelection: .init(), instruction: nil)
        model.lastAITransformation = .aiSkill(preview, .replaceAll)
        await model.retryLastAITransformation()
        XCTAssertEqual(note.content, "User edits after applying AI")
        XCTAssertNotNil(model.aiSkillErrorMessage)
    }

    func testTranslateWaitsForLanguageSheetDismissalBeforeConsent() async {
        var requests = 0
        var deps = NoteDetailViewModel.Dependencies()
        deps.ensureAIConsent = { requests += 1; return false }
        let model = NoteDetailViewModel(note: Note(content: "Source", userId: "test"), dependencies: deps)
        model.pendingAISkillRecipe = recipe
        model.showAISkillTranslateSheet = true
        model.startPendingTranslateAISkill(targetLanguage: "English")
        await Task.yield()
        XCTAssertEqual(requests, 0)
        XCTAssertFalse(model.showAISkillTranslateSheet)
        model.aiSkillTranslateSheetDidDismiss()
        await Task.yield()
        XCTAssertEqual(requests, 1)
        model.runQueuedAISkill()
        await Task.yield()
        XCTAssertEqual(requests, 1)
    }

    func testDismissingLanguageWithoutSelectionClearsPendingRecipe() {
        let model = NoteDetailViewModel(note: Note(content: "Source", userId: "test"))
        model.pendingAISkillRecipe = recipe
        model.aiSkillTranslateSheetDidDismiss()
        XCTAssertNil(model.pendingAISkillRecipe)
        XCTAssertNil(model.queuedAISkill)
    }

    func testEmptyResultCannotBecomeAnApplicablePreview() async {
        var terminalCode: String?
        var deps = NoteDetailViewModel.Dependencies()
        deps.ensureAIConsent = { true }
        deps.generateAISkill = { _, _, _ in "  \n" }
        deps.capture = { event, properties in
            if event == "skill_run_failed" { terminalCode = properties["error_code"] as? String }
        }
        let note = Note(content: "Keep this note", userId: "test")
        let model = NoteDetailViewModel(note: note, dependencies: deps)
        await model.generateAISkillPreview(recipe: recipe)
        XCTAssertNil(model.aiSkillPreview)
        XCTAssertEqual(note.content, "Keep this note")
        XCTAssertEqual(terminalCode, "invalid_response")
    }
}
