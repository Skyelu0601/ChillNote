import Foundation
import SwiftData
import Supabase

@MainActor
final class StarterGuideService {
    static let shared = StarterGuideService()
    private let newAccountWindow: TimeInterval = 10 * 60

    private init() {}

    @discardableResult
    func seedWelcomeContentIfNeeded(context: ModelContext, user: User) -> Bool {
        let userId = user.id.uuidString
        if WelcomeNoteFlagStore.hasSeenWelcome(for: userId) {
            print("[StarterGuide] Skip: welcome already handled for user \(userId)")
            return false
        }

        guard isFreshAccount(user) else {
            WelcomeNoteFlagStore.setHasSeenWelcome(true, for: userId)
            print("[StarterGuide] Skip: user \(userId) is not a new account")
            return false
        }

        let welcomeTag = Tag(
            name: L10n.text("onboarding.welcome_note.tag.start_here"),
            userId: userId
        )
        let welcomeNote = Note(
            content: L10n.text("onboarding.welcome_note.content"),
            userId: userId
        )
        welcomeNote.tags.append(welcomeTag)

        context.insert(welcomeTag)
        context.insert(welcomeNote)

        do {
            try context.save()
            WelcomeNoteFlagStore.setHasSeenWelcome(true, for: userId)
            print("[StarterGuide] Seeded welcome note for new user \(userId)")
            return true
        } catch {
            context.delete(welcomeNote)
            context.delete(welcomeTag)
            print("⚠️ StarterGuideService seed failed: \(error.localizedDescription)")
            return false
        }
    }

    private func isFreshAccount(_ user: User, now: Date = Date()) -> Bool {
        let accountAge = now.timeIntervalSince(user.createdAt)
        return accountAge >= 0 && accountAge <= newAccountWindow
    }
}
