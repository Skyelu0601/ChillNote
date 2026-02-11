import Foundation
import SwiftData

struct SyncEngine {
    private let mapper = SyncMapper()

    func makePayload(context: ModelContext, since: Date?, userId: String, cursor: String?, deviceId: String?) -> SyncPayload {
        let start = CFAbsoluteTimeGetCurrent()
        
        // 1. Notes (Incremental) - filtered by userId
        var noteDescriptor = FetchDescriptor<Note>()
        if let since {
            noteDescriptor.predicate = #Predicate<Note> { note in
                note.userId == userId && (note.updatedAt >= since || (note.deletedAt != nil && note.deletedAt! >= since))
            }
        } else {
            noteDescriptor.predicate = #Predicate<Note> { note in
                note.userId == userId
            }
        }
        let notes: [Note]
        do {
            notes = try context.fetch(noteDescriptor)
        } catch {
            notes = []
        }
        
        // 2. Tags (Incremental) - filtered by userId
        var tagDescriptor = FetchDescriptor<Tag>()
        if let since {
            tagDescriptor.predicate = #Predicate<Tag> { tag in
                tag.userId == userId && (tag.updatedAt >= since || (tag.deletedAt != nil && tag.deletedAt! >= since))
            }
        } else {
            tagDescriptor.predicate = #Predicate<Tag> { tag in
                tag.userId == userId
            }
        }
        let tags = (try? context.fetch(tagDescriptor)) ?? []
        

        
        // 4. Preferences (User Defaults) - now user-specific
        WelcomeNoteFlagStore.syncGlobalFlag(for: userId)
        let hasSeenWelcome = WelcomeNoteFlagStore.hasSeenWelcome(for: userId)
        let prefs: [String: String] = [
            "hasSeededWelcomeNote": String(hasSeenWelcome)
        ]

        let payload = SyncPayload(
            cursor: cursor,
            deviceId: deviceId,
            notes: notes.map { mapper.noteDTO(from: $0) },
            tags: tags.map { mapper.tagDTO(from: $0) },
            preferences: prefs
        )
        print("[TIME] SyncEngine.makePayload total: \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - start))s")
        return payload
    }

    func apply(remote: SyncResponse, context: ModelContext, userId: String) {
        let start = CFAbsoluteTimeGetCurrent()
        
        let remoteNotesCount = remote.changes.notes.count
        let remoteTagsCount = remote.changes.tags?.count ?? 0
        print("[TIME] SyncEngine.apply: remote notes=\(remoteNotesCount), tags=\(remoteTagsCount)")
        func shouldApply(remoteVersion: Int?, remoteUpdatedAt: Date?, localVersion: Int, localUpdatedAt: Date?) -> Bool {
            if let remoteVersion, remoteVersion > localVersion { return true }
            if let remoteVersion, remoteVersion < localVersion { return false }
            guard let remoteUpdatedAt else { return false }
            guard let localUpdatedAt else { return true }
            return remoteUpdatedAt > localUpdatedAt
        }

        // 1. Preferences - now user-specific
        if let prefs = remote.changes.preferences {
            if let val = prefs["hasSeededWelcomeNote"] {
                let hasSeenWelcome = (val == "true")
                WelcomeNoteFlagStore.setHasSeenWelcome(hasSeenWelcome, for: userId)
            }
        }
        
        // 2. Tags & Actions (Pre-fetch for relationships) - filtered by userId
        let remoteTags = remote.changes.tags ?? []
        var tagIdSet = Set<UUID>()
        for dto in remoteTags {
            if let id = UUID(uuidString: dto.id) {
                tagIdSet.insert(id)
            }
            if let parentIdStr = dto.parentId, let parentId = UUID(uuidString: parentIdStr) {
                tagIdSet.insert(parentId)
            }
        }
        for noteDto in remote.changes.notes {
            noteDto.tagIds?.forEach { tagIdStr in
                if let id = UUID(uuidString: tagIdStr) {
                    tagIdSet.insert(id)
                }
            }
        }

        var localTags: [Tag] = []
        if !tagIdSet.isEmpty {
            let tagIds = Array(tagIdSet)
            var tagDescriptor = FetchDescriptor<Tag>()
            tagDescriptor.predicate = #Predicate<Tag> { tag in
                tag.userId == userId && tagIds.contains(tag.id)
            }
            localTags = (try? context.fetch(tagDescriptor)) ?? []
        }
        print("[TIME] SyncEngine.apply: local tags=\(localTags.count)")
        var tagMap = Dictionary(uniqueKeysWithValues: localTags.map { ($0.id, $0) })
        
        // Apply Tags
        if !remoteTags.isEmpty {
            for dto in remoteTags {
                guard let tagId = UUID(uuidString: dto.id) else { continue }
                let remoteUpdatedAt = dto.updatedAt.flatMap { mapper.parseDate($0) }
                if let existing = tagMap[tagId] {
                    if shouldApply(remoteVersion: dto.version, remoteUpdatedAt: remoteUpdatedAt, localVersion: existing.version, localUpdatedAt: existing.serverUpdatedAt) {
                        mapper.apply(dto, to: existing)
                    }
                } else {
                    let newTag = Tag(name: dto.name, userId: userId)
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
            let cutoff = TrashPolicy.cutoffDate()
            for tag in tagMap.values where (tag.deletedAt ?? Date.distantPast) < cutoff && tag.deletedAt != nil {
                context.delete(tag)
            }
        }



        // 3. Notes - filtered by userId
        let remoteNoteIds = remote.changes.notes.compactMap { UUID(uuidString: $0.id) }
        var localNotes: [Note] = []
        if !remoteNoteIds.isEmpty {
            var noteDescriptor = FetchDescriptor<Note>()
            noteDescriptor.predicate = #Predicate<Note> { note in
                note.userId == userId && remoteNoteIds.contains(note.id)
            }
            localNotes = (try? context.fetch(noteDescriptor)) ?? []
        }
        print("[TIME] SyncEngine.apply: local notes=\(localNotes.count)")
        var notesById: [UUID: Note] = Dictionary(uniqueKeysWithValues: localNotes.map { ($0.id, $0) })

        for dto in remote.changes.notes {
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
                let remoteUpdatedAt = dto.updatedAt.flatMap { mapper.parseDate($0) }
                if shouldApply(remoteVersion: dto.version, remoteUpdatedAt: remoteUpdatedAt, localVersion: existing.version, localUpdatedAt: existing.serverUpdatedAt) {
                    mapper.apply(dto, to: existing)
                    existing.syncContentStructure(with: context)
                    resolveTags(for: existing)
                }
            } else {
                let note = Note(content: dto.content, userId: userId)
                note.id = id
                mapper.apply(dto, to: note)
                note.syncContentStructure(with: context)
                resolveTags(for: note)
                context.insert(note)
                notesById[id] = note
            }
        }

        purgeDeletedNotes(olderThan: TrashPolicy.cutoffDate(), context: context, userId: userId)
        print("[TIME] SyncEngine.apply total: \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - start))s")
        applyConflicts(remote.conflicts, context: context, userId: userId)
    }

    private func applyConflicts(_ conflicts: [ConflictDTO], context: ModelContext, userId: String) {
        guard !conflicts.isEmpty else { return }
        let now = Date()
        for conflict in conflicts where conflict.entityType == "note" {
            let combinedContent = """
            ## Conflict Copy
            - Server version: \(conflict.serverVersion)
            - Notes: \(conflict.message)

            ### Server Content
            \(conflict.serverContent ?? "")

            ### Local Content
            \(conflict.clientContent ?? "")
            """
            let note = Note(content: combinedContent, userId: userId)
            note.updatedAt = now
            note.version = 1
            context.insert(note)
        }
    }

    private func purgeDeletedNotes(olderThan cutoff: Date, context: ModelContext, userId: String) {
        var descriptor = FetchDescriptor<Note>()
        descriptor.predicate = #Predicate<Note> { note in
            note.userId == userId && note.deletedAt != nil && note.deletedAt! < cutoff
        }

        guard let staleNotes = try? context.fetch(descriptor) else { return }
        for note in staleNotes {
            context.delete(note)
        }
    }
}
