import XCTest
@testable import chillnote

@MainActor
final class AIConsentManagerTests: XCTestCase {
    func testConsentAcceptedForCurrentVersion() async {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let manager = AIConsentManager(userDefaults: defaults)
        XCTAssertFalse(manager.hasAcceptedAIDataConsent)

        let request = Task { await manager.ensureConsentIfNeeded(for: .text) }
        await Task.yield()
        manager.acceptAIDataConsent()
        _ = await request.value

        XCTAssertTrue(manager.hasAcceptedAIDataConsent)
        XCTAssertEqual(
            defaults.string(forKey: AIConsentManager.acceptedVersionKey),
            AIConsentManager.currentConsentVersion
        )
        XCTAssertNotNil(defaults.object(forKey: AIConsentManager.acceptedAtKey))
    }

    func testEnsureConsentWaitsUntilAccepted() async {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let manager = AIConsentManager(userDefaults: defaults)
        let task = Task { await manager.ensureConsentIfNeeded(for: .text) }

        await Task.yield()
        XCTAssertNotNil(manager.activePrompt)

        manager.acceptAIDataConsent()
        let result = await task.value

        XCTAssertTrue(result)
        XCTAssertNil(manager.activePrompt)
    }

    func testEnsureConsentReturnsFalseWhenDeclined() async {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let manager = AIConsentManager(userDefaults: defaults)
        let task = Task { await manager.ensureConsentIfNeeded(for: .audio) }

        await Task.yield()
        manager.declineAIDataConsent()

        let result = await task.value
        XCTAssertFalse(result)
        XCTAssertFalse(manager.hasAcceptedAIDataConsent)
    }

    func testDeclinePromptsAgainAndStaleDismissalCannotDeclineNewPrompt() async throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        var events: [String] = []
        let manager = AIConsentManager(userDefaults: defaults, capture: { events.append($0); _ = $1 })
        let first = Task { await manager.ensureConsentIfNeeded(for: .text) }
        await Task.yield()
        let firstID = try XCTUnwrap(manager.activePrompt?.id)
        manager.declineAIDataConsent(promptID: firstID)
        let firstResult = await first.value
        XCTAssertFalse(firstResult)
        let second = Task { await manager.ensureConsentIfNeeded(for: .text) }
        await Task.yield()
        let secondID = try XCTUnwrap(manager.activePrompt?.id)
        XCTAssertNotEqual(firstID, secondID)
        manager.declineAIDataConsent(promptID: firstID)
        XCTAssertEqual(manager.activePrompt?.id, secondID)
        manager.acceptAIDataConsent(promptID: secondID)
        let secondResult = await second.value
        XCTAssertTrue(secondResult)
        let recreated = AIConsentManager(userDefaults: defaults)
        let persistedResult = await recreated.ensureConsentIfNeeded(for: .audio)
        XCTAssertTrue(persistedResult)
        XCTAssertNil(recreated.activePrompt)
        XCTAssertEqual(events, ["ai_consent_prompted", "ai_consent_declined", "ai_consent_prompted", "ai_consent_accepted"])
    }

    func testConcurrentRequestsKeepSamePromptAndCancelledRequestDoesNotRun() async throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let manager = AIConsentManager(userDefaults: defaults)
        let first = Task { await manager.ensureConsentIfNeeded(for: .text) }
        await Task.yield()
        let id = try XCTUnwrap(manager.activePrompt?.id)
        let second = Task { await manager.ensureConsentIfNeeded(for: .audio) }
        await Task.yield()
        XCTAssertEqual(manager.activePrompt?.id, id)
        first.cancel()
        let firstResult = await first.value
        XCTAssertFalse(firstResult)
        XCTAssertEqual(manager.activePrompt?.id, id)
        manager.acceptAIDataConsent(promptID: id)
        let secondResult = await second.value
        XCTAssertTrue(secondResult)
    }

    func testCancelledLastRequestDismissesPromptWithoutSavingConsent() async {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set("old-version", forKey: AIConsentManager.acceptedVersionKey)
        let manager = AIConsentManager(userDefaults: defaults)
        let task = Task { await manager.ensureConsentIfNeeded(for: .text) }
        await Task.yield()
        XCTAssertNotNil(manager.activePrompt)
        task.cancel()
        _ = await task.value
        XCTAssertNil(manager.activePrompt)
        manager.acceptAIDataConsent()
        XCTAssertFalse(manager.hasAcceptedAIDataConsent)
    }
}
