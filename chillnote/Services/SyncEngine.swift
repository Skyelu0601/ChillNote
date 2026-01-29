import Foundation
import SwiftData

struct SyncEngine {
    private let mapper = SyncMapper()

    func makePayload(context: ModelContext, since: Date?) -> SyncPayload {
        // 1. Notes (Incremental)
        var noteDescriptor = FetchDescriptor<Note>()
        if let since {
            noteDescriptor.predicate = #Predicate<Note> { note in
                note.updatedAt >= since
            }
        }
        let notes: [Note]
        do {
            notes = try context.fetch(noteDescriptor)
        } catch {
            notes = []
        }
        
        // 2. Tags (Full Sync with tombstones)
        let tags = (try? context.fetch(FetchDescriptor<Tag>())) ?? []
        

        
        // 4. Preferences (User Defaults)
        let prefs: [String: String] = [
            "hasSeededWelcomeNote": String(UserDefaults.standard.bool(forKey: "hasSeededWelcomeNote"))
        ]

        return SyncPayload(
            notes: notes.map { mapper.noteDTO(from: $0) },
            tags: tags.map { mapper.tagDTO(from: $0) },
            preferences: prefs
        )
    }

    func apply(remote: SyncPayload, context: ModelContext) {
        func shouldApply(remoteUpdatedAt: Date?, remoteDeletedAt: Date?, localUpdatedAt: Date?, localDeletedAt: Date?) -> Bool {
            if let remoteDeletedAt {
                if let localDeletedAt, localDeletedAt >= remoteDeletedAt { return false }
                if let localUpdatedAt, localUpdatedAt > remoteDeletedAt { return false }
                return true
            }
            guard let remoteUpdatedAt else { return false }
            if let localDeletedAt, localDeletedAt >= remoteUpdatedAt { return false }
            guard let localUpdatedAt else { return true }
            return remoteUpdatedAt > localUpdatedAt
        }

        // 1. Preferences
        if let prefs = remote.preferences {
            if let val = prefs["hasSeededWelcomeNote"] {
                UserDefaults.standard.set(val == "true", forKey: "hasSeededWelcomeNote")
            }
        }
        
        // 2. Tags & Actions (Pre-fetch for relationships)
        let localTags = (try? context.fetch(FetchDescriptor<Tag>())) ?? []
        var tagMap = Dictionary(uniqueKeysWithValues: localTags.map { ($0.id, $0) })
        
        // Apply Tags
        if let remoteTags = remote.tags {
            for dto in remoteTags {
                guard let tagId = UUID(uuidString: dto.id) else { continue }
                let remoteUpdatedAt = mapper.parseDate(dto.updatedAt)
                let remoteDeletedAt = dto.deletedAt.flatMap { mapper.parseDate($0) }
                if let existing = tagMap[tagId] {
                    if shouldApply(remoteUpdatedAt: remoteUpdatedAt, remoteDeletedAt: remoteDeletedAt, localUpdatedAt: existing.updatedAt, localDeletedAt: existing.deletedAt) {
                        mapper.apply(dto, to: existing)
                    }
                } else {
                    let newTag = Tag(name: dto.name)
                    newTag.id = tagId
                    mapper.apply(dto, to: newTag)
                    context.insert(newTag)
                    tagMap[tagId] = newTag
                }
            }
            
            // Second pass for Tag hierarchy
            for dto in remoteTags {
                guard let tagId = UUID(uuidString: dto.id), let tag = tagMap[tagId] else { continue }
                if let parentIdStr = dto.parentId, let parentId = UUID(uuidString: parentIdStr) {
                    tag.parent = tagMap[parentId]
                } else {
                    tag.parent = nil
                }
            }
            
            // Purge soft-deleted tags older than 30 days
            let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date.distantPast
            for tag in tagMap.values where (tag.deletedAt ?? Date.distantPast) < cutoff && tag.deletedAt != nil {
                context.delete(tag)
            }
        }



        // 3. Notes
        let localNotes = (try? context.fetch(FetchDescriptor<Note>())) ?? []
        var notesById: [UUID: Note] = Dictionary(uniqueKeysWithValues: localNotes.map { ($0.id, $0) })

        for dto in remote.notes {
            guard let id = UUID(uuidString: dto.id) else { continue }
            
            // Helper to resolve tags
            func resolveTags(for note: Note) {
                if let tagIds = dto.tagIds {
                    note.tags = tagIds
                        .compactMap { UUID(uuidString: $0) }
                        .compactMap { tagMap[$0] }
                        .filter { $0.deletedAt == nil }
                }
            }

            if let existing = notesById[id] {
                let localUpdatedAt = existing.updatedAt
                let remoteUpdatedAt = mapper.parseDate(dto.updatedAt) ?? localUpdatedAt

                // Delete wins if it's newer than local updates.
                if let remoteDeletedAt = dto.deletedAt, let remoteDeletedDate = mapper.parseDate(remoteDeletedAt) {
                    if remoteDeletedDate >= localUpdatedAt {
                        existing.deletedAt = remoteDeletedDate
                        existing.updatedAt = remoteDeletedDate
                    }
                    continue
                }

                if remoteUpdatedAt > localUpdatedAt {
                    mapper.apply(dto, to: existing)
                    existing.syncContentStructure(with: context)
                    resolveTags(for: existing)
                }
            } else {
                let note = Note(content: dto.content)
                note.id = id
                mapper.apply(dto, to: note)
                note.syncContentStructure(with: context)
                resolveTags(for: note)
                context.insert(note)
                notesById[id] = note
            }
        }

        purgeDeletedNotes(olderThan: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date.distantPast, context: context)
    }

    private func purgeDeletedNotes(olderThan cutoff: Date, context: ModelContext) {
        var descriptor = FetchDescriptor<Note>()
        descriptor.predicate = #Predicate<Note> { note in
            note.deletedAt != nil && note.deletedAt! < cutoff
        }

        guard let staleNotes = try? context.fetch(descriptor) else { return }
        for note in staleNotes {
            context.delete(note)
        }
    }
}
