import Foundation
import SwiftData

struct SyncEngine {
    private let mapper = SyncMapper()

    func makePayload(
        context: ModelContext,
        since: Date?,
        userId: String,
        cursor: String?,
        deviceId: String?,
        hardDeletedNoteIds: [String],
        hardDeletedTagIds: [String]
    ) -> SyncPayload {
        let start = CFAbsoluteTimeGetCurrent()
        let sinceText = since.map { ISO8601DateFormatter().string(from: $0) } ?? "nil"
        
        // 1. Notes (Incremental) - filtered by userId
        var noteDescriptor = FetchDescriptor<Note>()
        if let since {
            noteDescriptor.predicate = #Predicate<Note> { note in
                note.userId == userId && note.updatedAt > since
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
            print("⚠️ SyncEngine.makePayload notes fetch failed: \(error.localizedDescription)")
            notes = []
        }
        
        // 2. Tags (Incremental) - filtered by userId
        var tagDescriptor = FetchDescriptor<Tag>()
        if let since {
            tagDescriptor.predicate = #Predicate<Tag> { tag in
                tag.userId == userId && tag.updatedAt > since
            }
        } else {
            tagDescriptor.predicate = #Predicate<Tag> { tag in
                tag.userId == userId
            }
        }
        let tags: [Tag]
        do {
            tags = try context.fetch(tagDescriptor)
        } catch {
            print("⚠️ SyncEngine.makePayload tags fetch failed: \(error.localizedDescription)")
            tags = []
        }
        

        
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
            hardDeletedNoteIds: hardDeletedNoteIds.isEmpty ? nil : hardDeletedNoteIds,
            hardDeletedTagIds: hardDeletedTagIds.isEmpty ? nil : hardDeletedTagIds,
            preferences: prefs
        )
        print("[SYNC] makePayload since=\(sinceText) notes=\(notes.count) tags=\(tags.count) hardDeletedNotes=\(hardDeletedNoteIds.count) hardDeletedTags=\(hardDeletedTagIds.count)")
        print("[TIME] SyncEngine.makePayload total: \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - start))s")
        return payload
    }

    func apply(remote: SyncResponse, context: ModelContext, userId: String, localSyncAnchor: Date = Date()) {
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

        // 1.5 Hard deletes - remove local records immediately.
        let hardDeletedTagIds = (remote.changes.hardDeletedTagIds ?? []).compactMap(UUID.init(uuidString:))
        if !hardDeletedTagIds.isEmpty {
            var descriptor = FetchDescriptor<Tag>()
            descriptor.predicate = #Predicate<Tag> { tag in
                tag.userId == userId && hardDeletedTagIds.contains(tag.id)
            }
            if let tagsToDelete = try? context.fetch(descriptor) {
                for tag in tagsToDelete {
                    context.delete(tag)
                }
            }
        }

        let hardDeletedNoteIds = (remote.changes.hardDeletedNoteIds ?? []).compactMap(UUID.init(uuidString:))
        if !hardDeletedNoteIds.isEmpty {
            var descriptor = FetchDescriptor<Note>()
            descriptor.predicate = #Predicate<Note> { note in
                note.userId == userId && hardDeletedNoteIds.contains(note.id)
            }
            if let notesToDelete = try? context.fetch(descriptor) {
                for note in notesToDelete {
                    context.delete(note)
                }
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
        print("[TIME] SyncEngine.apply: matched local tags=\(localTags.count)/\(tagIdSet.count)")
        var tagMap = Dictionary(uniqueKeysWithValues: localTags.map { ($0.id, $0) })
        
        // Apply Tags
        if !remoteTags.isEmpty {
            for dto in remoteTags {
                guard let tagId = UUID(uuidString: dto.id) else { continue }
                let remoteUpdatedAt = dto.updatedAt.flatMap { mapper.parseDate($0) }
                if let existing = tagMap[tagId] {
                    if shouldApply(remoteVersion: dto.version, remoteUpdatedAt: remoteUpdatedAt, localVersion: existing.version, localUpdatedAt: existing.updatedAt) {
                        mapper.apply(dto, to: existing)
                        existing.updatedAt = normalizeSyncedUpdatedAt(existing.updatedAt, localSyncAnchor: localSyncAnchor)
                    }
                } else {
                    let newTag = Tag(name: dto.name, userId: userId)
                    newTag.id = tagId
                    mapper.apply(dto, to: newTag)
                    newTag.updatedAt = normalizeSyncedUpdatedAt(newTag.updatedAt, localSyncAnchor: localSyncAnchor)
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
        print("[TIME] SyncEngine.apply: matched local notes=\(localNotes.count)/\(remoteNoteIds.count)")
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
                if shouldApply(remoteVersion: dto.version, remoteUpdatedAt: remoteUpdatedAt, localVersion: existing.version, localUpdatedAt: existing.updatedAt) {
                    mapper.apply(dto, to: existing)
                    existing.updatedAt = normalizeSyncedUpdatedAt(existing.updatedAt, localSyncAnchor: localSyncAnchor)
                    existing.syncContentStructure(with: context)
                    resolveTags(for: existing)
                }
            } else {
                let note = Note(content: dto.content, userId: userId)
                note.id = id
                mapper.apply(dto, to: note)
                note.updatedAt = normalizeSyncedUpdatedAt(note.updatedAt, localSyncAnchor: localSyncAnchor)
                note.syncContentStructure(with: context)
                resolveTags(for: note)
                context.insert(note)
                notesById[id] = note
            }
        }

        print("[TIME] SyncEngine.apply total: \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - start))s")
        applyConflicts(remote.conflicts, context: context, userId: userId)
    }

    private func applyConflicts(_ conflicts: [ConflictDTO], context: ModelContext, userId: String) {
        guard !conflicts.isEmpty else { return }
        let now = Date()
        for conflict in conflicts where conflict.entityType == "note" || conflict.entityType == "tag" {
            // Ignore idempotent replay conflicts (same content on both sides),
            // which can happen when duplicate sync requests overlap.
            let serverText = conflict.serverContent?.trimmingCharacters(in: .whitespacesAndNewlines)
            let clientText = conflict.clientContent?.trimmingCharacters(in: .whitespacesAndNewlines)
            if serverText == clientText {
                continue
            }
            let combinedContent = """
            ## Conflict Copy (\(conflict.entityType.uppercased()))
            - Entity ID: \(conflict.id)
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

    private func normalizeSyncedUpdatedAt(_ updatedAt: Date, localSyncAnchor: Date) -> Date {
        min(updatedAt, localSyncAnchor)
    }
}
