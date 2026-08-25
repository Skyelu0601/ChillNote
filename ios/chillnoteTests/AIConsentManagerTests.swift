import XCTest
@testable import chillnote

@MainActor
final class AIConsentManagerTests: XCTestCase {
    func testConsentAcceptedForCurrentVersion() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let manager = AIConsentManager(userDefaults: defaults)
        XCTAssertFalse(manager.hasAcceptedAIDataConsent)

        manager.acceptAIDataConsent()

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
}
