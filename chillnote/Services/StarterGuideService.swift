import Foundation
import OSLog
import SwiftData
import Supabase

@MainActor
final class StarterGuideService {
    static let shared = StarterGuideService()
    private static let logger = Logger(subsystem: "com.chillnote.app", category: "starter-guide")
    private let newAccountWindow: TimeInterval = 10 * 60

    private init() {}

    @discardableResult
    func seedWelcomeContentIfNeeded(context: ModelContext, user: User) -> Bool {
        let userId = user.id.uuidString
        if WelcomeNoteFlagStore.hasSeenWelcome(for: userId) {
            Self.logger.debug("Skipping welcome content; already handled for user \(userId, privacy: .private)")
            return false
        }

        guard isFreshAccount(user) else {
            WelcomeNoteFlagStore.setHasSeenWelcome(true, for: userId)
            Self.logger.debug("Skipping welcome content; user is outside new account window \(userId, privacy: .private)")
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
            Self.logger.info("Seeded welcome content for new user \(userId, privacy: .private)")
            return true
        } catch {
            context.delete(welcomeNote)
            context.delete(welcomeTag)
            Self.logger.error("Welcome content seed failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func isFreshAccount(_ user: User, now: Date = Date()) -> Bool {
        let accountAge = now.timeIntervalSince(user.createdAt)
        return accountAge >= 0 && accountAge <= newAccountWindow
    }
}
