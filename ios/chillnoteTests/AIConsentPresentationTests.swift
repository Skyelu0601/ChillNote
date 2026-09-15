import XCTest
import SwiftUI
@testable import chillnote

@MainActor
final class AIConsentPresentationTests: XCTestCase {
    func testTranslateDismissesBeforeConsentAndDeclineAllowsAnotherVisiblePrompt() async throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let manager = AIConsentManager(userDefaults: defaults, capture: { _, _ in })
        var deps = NoteDetailViewModel.Dependencies()
        deps.ensureAIConsent = { await manager.ensureConsentIfNeeded(for: .text) }
        deps.generateAISkill = { _, _, _ in XCTFail("Decline must not send data"); return "" }
        let model = NoteDetailViewModel(note: Note(content: "Source", userId: "test"), dependencies: deps)
        let recipe = AgentRecipe(id: "translate", systemIcon: "globe", name: "Test",
                                 description: "Test", prompt: "Test", category: .shape)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previousWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        let host = UIHostingController(rootView:
            Color.clear
                .modifier(NoteDetailAlertsAndSheets(viewModel: model, onAISkillApplied: {}))
                .modifier(AIConsentPresentation(manager: manager))
        )
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            manager.declineAIDataConsent()
            window.isHidden = true
            window.rootViewController = nil
            previousWindow?.makeKeyAndVisible()
        }
        model.pendingAISkillRecipe = recipe
        model.showAISkillTranslateSheet = true
        let languageShown = await waitUntil { host.presentedViewController != nil && host.presentedViewController?.isBeingPresented == false }
        XCTAssertTrue(languageShown)
        let languageSheet = try XCTUnwrap(host.presentedViewController)
        model.startPendingTranslateAISkill(targetLanguage: "English")
        let consentShown = await waitUntil {
            manager.activePrompt != nil && host.presentedViewController != nil
                && host.presentedViewController !== languageSheet
                && host.presentedViewController?.isBeingPresented == false
        }
        XCTAssertTrue(consentShown, "Consent must be presented after the language sheet actually dismisses")
        manager.declineAIDataConsent()
        let dismissed = await waitUntil { host.presentedViewController == nil && !model.isAwaitingAIConsent }
        XCTAssertTrue(dismissed)
        XCTAssertNil(model.aiSkillErrorMessage)

        let retry = Task { await model.generateAISkillPreview(recipe: recipe) }
        defer { retry.cancel() }
        let retryShown = await waitUntil { manager.activePrompt != nil && host.presentedViewController != nil }
        XCTAssertTrue(retryShown, "A declined first request must not suppress the next consent prompt")
        manager.declineAIDataConsent()
        await retry.value
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<100 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return false
    }
}
