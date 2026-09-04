import Foundation
import OSLog
import SwiftData

struct TrashPolicy {
    static let retentionDays: Int = 30
    private static let logger = Logger(subsystem: "com.chillnote.app", category: "trash-policy")

    static func daysRemaining(from deletedAt: Date) -> Int {
        let expiration = Calendar.current.date(byAdding: .day, value: retentionDays, to: deletedAt) ?? deletedAt
        let remaining = Calendar.current.dateComponents([.day], from: Date(), to: expiration).day ?? 0
        return max(0, remaining)
    }

    static func cutoffDate(from date: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .day, value: -retentionDays, to: date) ?? date
    }

    @MainActor
    static func purgeExpiredNotes(context: ModelContext) {
        let cutoff = cutoffDate()
        let descriptor = FetchDescriptor<Note>(predicate: #Predicate { note in
            note.deletedAt != nil && note.deletedAt! < cutoff
        })
        do {
            let notes = try context.fetch(descriptor)
            guard !notes.isEmpty else { return }
            let noteIDsByUser = Dictionary(grouping: notes, by: \Note.userId)
                .mapValues { $0.map(\.id) }
            for note in notes {
                context.delete(note)
            }
            try context.save()
            for (userId, noteIDs) in noteIDsByUser {
                HardDeleteQueueStore.enqueue(noteIDs: noteIDs, for: userId)
            }
            scheduleSearchIndexRemoval(noteIDsByUser.values.flatMap { $0 })
            logger.info("Purged \(notes.count, privacy: .public) expired notes")
        } catch {
            logger.error("Failed to purge expired notes: \(error.localizedDescription, privacy: .public)")
        }
    }

    @MainActor
    static func purgeExpiredTags(context: ModelContext, userId: String) {
        let cutoff = cutoffDate()
        let descriptor = FetchDescriptor<Tag>(predicate: #Predicate { tag in
            tag.userId == userId
        })
        do {
            // SwiftData can fail to match optional dates reliably when a
            // predicate combines a nil check, force unwrap, and comparison.
            // Keep the persistent query simple and evaluate expiry in Swift.
            let tags = try context.fetch(descriptor).filter { tag in
                guard let deletedAt = tag.deletedAt else { return false }
                return deletedAt < cutoff
            }
            guard !tags.isEmpty else { return }
            let ids = tags.map(\.id)
            for tag in tags {
                context.delete(tag)
            }
            try context.save()
            HardDeleteQueueStore.enqueue(tagIDs: ids, for: userId)
            logger.info("Purged \(tags.count, privacy: .public) expired tags")
        } catch {
            logger.error("Failed to purge expired tags: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func scheduleSearchIndexRemoval(_ noteIDs: [UUID]) {
        Task {
            await NotesSearchIndexer.shared.remove(noteIDs: noteIDs)
        }
    }
}
