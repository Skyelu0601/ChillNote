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
        
        // 2. Tags (Full Sync)
        // Since Tag doesn't have updatedAt, we sync all tags to ensure consistency.
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
                if let existing = tagMap[tagId] {
                    mapper.apply(dto, to: existing)
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
        }



        // 3. Notes
        let localNotes = (try? context.fetch(FetchDescriptor<Note>())) ?? []
        var notesById: [UUID: Note] = Dictionary(uniqueKeysWithValues: localNotes.map { ($0.id, $0) })

        for dto in remote.notes {
            guard let id = UUID(uuidString: dto.id) else { continue }
            
            // Helper to resolve tags
            func resolveTags(for note: Note) {
                if let tagIds = dto.tagIds {
                    note.tags = tagIds.compactMap { UUID(uuidString: $0) }.compactMap { tagMap[$0] }
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
