import Foundation
import OSLog
import SwiftData

class TagService {
    static let shared = TagService()
    private static let logger = Logger(subsystem: "com.chillnote.app", category: "tags")

    private init() {}
    
    /// Marks tags that are no longer associated with any active notes as deleted (soft-delete for sync).
    /// If candidates are provided, only those tags are checked.
    func cleanupEmptyTags(context: ModelContext, candidates: [Tag]? = nil, shouldSave: Bool = true) {
        let tagsToCheck: [Tag]
        if let candidates, !candidates.isEmpty {
            var seen = Set<UUID>()
            tagsToCheck = candidates.filter { tag in
                guard !seen.contains(tag.id) else { return false }
                seen.insert(tag.id)
                return true
            }
        } else {
            let fetchDescriptor = FetchDescriptor<Tag>()
            do {
                tagsToCheck = try context.fetch(fetchDescriptor)
            } catch {
                Self.logger.error("Failed to fetch tags for cleanup: \(error.localizedDescription, privacy: .public)")
                return
            }
        }
        for tag in tagsToCheck {
            let activeNotes = tag.notes.filter { $0.deletedAt == nil }
            if activeNotes.isEmpty && tag.deletedAt == nil {
                let now = Date()
                tag.deletedAt = now
                tag.updatedAt = now
            }
        }
        guard shouldSave else { return }
        do {
            try context.save()
        } catch {
            Self.logger.error("Tag cleanup failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
