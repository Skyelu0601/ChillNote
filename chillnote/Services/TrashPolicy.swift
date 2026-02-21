import Foundation
import SwiftData

struct TrashPolicy {
    static let retentionDays: Int = 30

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
        if let notes = try? context.fetch(descriptor) {
            for note in notes {
                context.delete(note)
            }
            try? context.save()
        }
    }

    @MainActor
    static func purgeExpiredTags(context: ModelContext, userId: String) {
        let cutoff = cutoffDate()
        let descriptor = FetchDescriptor<Tag>(predicate: #Predicate { tag in
            tag.userId == userId && tag.deletedAt != nil && tag.deletedAt! < cutoff
        })
        guard let tags = try? context.fetch(descriptor), !tags.isEmpty else { return }
        let ids = tags.map(\.id)
        for tag in tags {
            context.delete(tag)
        }
        HardDeleteQueueStore.enqueue(tagIDs: ids, for: userId)
        try? context.save()
    }
}
