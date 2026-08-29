import Foundation
import OSLog
import SwiftData

struct SyncEngine {
    private static let logger = Logger(subsystem: "com.chillnote.app", category: "sync-engine")
    private let mapper = SyncMapper()

    func makePayload(
        context: ModelContext,
        since: Date?,
        userId: String,
        cursor: String?,
        deviceId: String?,
        hardDeletedNoteIds: [String],
        hardDeletedTagIds: [String]
    ) throws -> SyncPayload {
        let start = CFAbsoluteTimeGetCurrent()
        let sinceText = since.map { ISO8601DateFormatter().string(from: $0) } ?? "nil"
        
        // Protocol v4 determines pending uploads by a durable content
        // fingerprint. Always scan this account: wall-clock timestamps are not
        // safe dirty markers across devices and process restarts.
        var noteDescriptor = FetchDescriptor<Note>()
        noteDescriptor.predicate = #Predicate<Note> { note in
            note.userId == userId
        }
        let allNotes: [Note]
        do {
            allNotes = try context.fetch(noteDescriptor)
        } catch {
            Self.logger.error("makePayload notes fetch failed: \(error.localizedDescription, privacy: .public)")
            throw SyncError.localStoreUnavailable
        }
        
        // 2. Tags - same durable fingerprint rule as notes.
        var tagDescriptor = FetchDescriptor<Tag>()
        tagDescriptor.predicate = #Predicate<Tag> { tag in
            tag.userId == userId
        }
        let allTags: [Tag]
        do {
            allTags = try context.fetch(tagDescriptor)
        } catch {
            Self.logger.error("makePayload tags fetch failed: \(error.localizedDescription, privacy: .public)")
            throw SyncError.localStoreUnavailable
        }
        let notes = allNotes.filter { note in
            let fingerprint = SyncEntityFingerprint.note(note)
            guard fingerprint != note.acknowledgedFingerprint else { return false }
            prepareMutation(
                fingerprint: fingerprint,
                serverMutationId: &note.serverMutationId,
                lastSubmittedMutationId: &note.lastSubmittedMutationId,
                lastSubmittedFingerprint: &note.lastSubmittedFingerprint,
                acknowledgedFingerprint: &note.acknowledgedFingerprint
            )
            return true
        }
        let tags = allTags.filter { tag in
            let fingerprint = SyncEntityFingerprint.tag(tag)
            guard fingerprint != tag.acknowledgedFingerprint else { return false }
            prepareMutation(
                fingerprint: fingerprint,
                serverMutationId: &tag.serverMutationId,
                lastSubmittedMutationId: &tag.lastSubmittedMutationId,
                lastSubmittedFingerprint: &tag.lastSubmittedFingerprint,
                acknowledgedFingerprint: &tag.acknowledgedFingerprint
            )
            return true
        }

        // Mutation IDs must survive a process kill or a committed request whose
        // HTTP response never arrives. Persist them before any network work.
        do {
            try context.save()
        } catch {
            Self.logger.error("makePayload mutation state save failed: \(error.localizedDescription, privacy: .public)")
            throw SyncError.localStoreUnavailable
        }

        
        // 4. Preferences (User Defaults) - now user-specific
        WelcomeNoteFlagStore.syncGlobalFlag(for: userId)
        let hasSeenWelcome = WelcomeNoteFlagStore.hasSeenWelcome(for: userId)
        let prefs: [String: String] = [
            "hasSeededWelcomeNote": String(hasSeenWelcome)
        ]

        let payload = SyncPayload(
            protocolVersion: 4,
            cursor: cursor,
            deviceId: deviceId,
            notes: notes.map { mapper.noteDTO(from: $0) },
            tags: tags.map { mapper.tagDTO(from: $0) },
            hardDeletedNoteIds: hardDeletedNoteIds.isEmpty ? nil : hardDeletedNoteIds,
            hardDeletedTagIds: hardDeletedTagIds.isEmpty ? nil : hardDeletedTagIds,
            preferences: prefs
        )
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        Self.logger.debug("makePayload since=\(sinceText, privacy: .public) dirtyNotes=\(notes.count, privacy: .public)/\(allNotes.count, privacy: .public) dirtyTags=\(tags.count, privacy: .public)/\(allTags.count, privacy: .public) hardDeletedNotes=\(hardDeletedNoteIds.count, privacy: .public) hardDeletedTags=\(hardDeletedTagIds.count, privacy: .public) elapsed=\(elapsed, privacy: .public)s")
        return payload
    }

    private func prepareMutation(
        fingerprint: String,
        serverMutationId: inout String?,
        lastSubmittedMutationId: inout String?,
        lastSubmittedFingerprint: inout String?,
        acknowledgedFingerprint: inout String?
    ) {
        guard lastSubmittedMutationId == nil || lastSubmittedFingerprint != fingerprint else {
            return
        }

        // If a prior upload may have committed without an HTTP ACK, the next
        // changed snapshot names it as predecessor. This enables the server's
        // safe A1-ACK-loss -> A2 recovery rule. A request that never committed
        // may conservatively conflict, which is preferable to data loss.
        if let priorSubmittedMutationId = lastSubmittedMutationId {
            serverMutationId = priorSubmittedMutationId
        }
        lastSubmittedMutationId = UUID().uuidString
        lastSubmittedFingerprint = fingerprint

        // Once an upload is attempted, the older acknowledged content can no
        // longer prove what is on the server (the request may commit). Clearing
        // it also handles a user reverting to that older content after ACK loss.
        acknowledgedFingerprint = nil
    }

    func apply(remote: SyncResponse, context: ModelContext, userId: String, localSyncAnchor: Date = Date()) throws {
        let start = CFAbsoluteTimeGetCurrent()
        
        let remoteNotesCount = remote.changes.notes.count
        let remoteTagsCount = remote.changes.tags?.count ?? 0
        Self.logger.debug("apply remote notes=\(remoteNotesCount, privacy: .public) tags=\(remoteTagsCount, privacy: .public)")
        let forcedNoteIds = Set((remote.forcedNoteIds ?? []).compactMap(UUID.init(uuidString:)))
        let forcedTagIds = Set((remote.forcedTagIds ?? []).compactMap(UUID.init(uuidString:)))
        let versionConflictNoteIds = Set(remote.conflicts.compactMap { conflict -> UUID? in
            guard conflict.entityType.caseInsensitiveCompare("note") == .orderedSame,
                  conflict.message == "sync.conflict.version" else { return nil }
            return UUID(uuidString: conflict.id)
        })
        let versionConflictTagIds = Set(remote.conflicts.compactMap { conflict -> UUID? in
            guard conflict.entityType.caseInsensitiveCompare("tag") == .orderedSame,
                  conflict.message == "sync.conflict.version" else { return nil }
            return UUID(uuidString: conflict.id)
        })
        var preservedTagConflicts: [PreservedTagConflict] = []
        func sameMutation(_ left: String?, _ right: String?) -> Bool {
            guard let left, let right else { return false }
            return left.caseInsensitiveCompare(right) == .orderedSame
        }
        func shouldApply(remoteVersion: Int?, remoteUpdatedAt: Date?, localVersion: Int, localUpdatedAt: Date?) -> Bool {
            if let remoteVersion, remoteVersion > localVersion { return true }
            if let remoteVersion, remoteVersion < localVersion { return false }
            if remoteVersion != nil { return false }
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
            do {
                let tagsToDelete = try context.fetch(descriptor)
                for tag in tagsToDelete {
                    if tag.deletedAt == nil,
                       SyncEntityFingerprint.tag(tag) != tag.acknowledgedFingerprint {
                        // A tombstone can be downloaded for an entity that was
                        // clean when the request started but edited before the
                        // response arrived. Conflict metadata describes only the
                        // submitted snapshot, so local dirtiness itself is the
                        // data-preservation signal.
                        preservedTagConflicts.append(preserveLocalTagConflict(tag, context: context))
                    }
                    context.delete(tag)
                }
            } catch {
                Self.logger.error("apply hard-deleted tags fetch failed: \(error.localizedDescription, privacy: .public)")
                throw SyncError.localStoreUnavailable
            }
        }

        let hardDeletedNoteIds = (remote.changes.hardDeletedNoteIds ?? []).compactMap(UUID.init(uuidString:))
        if !hardDeletedNoteIds.isEmpty {
            var descriptor = FetchDescriptor<Note>()
            descriptor.predicate = #Predicate<Note> { note in
                note.userId == userId && hardDeletedNoteIds.contains(note.id)
            }
            do {
                let notesToDelete = try context.fetch(descriptor)
                for note in notesToDelete {
                    if note.deletedAt == nil,
                       SyncEntityFingerprint.note(note) != note.acknowledgedFingerprint {
                        preserveLocalNoteConflict(note, context: context)
                    }
                    context.delete(note)
                }
            } catch {
                Self.logger.error("apply hard-deleted notes fetch failed: \(error.localizedDescription, privacy: .public)")
                throw SyncError.localStoreUnavailable
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
            do {
                localTags = try context.fetch(tagDescriptor)
            } catch {
                Self.logger.error("apply local tags fetch failed: \(error.localizedDescription, privacy: .public)")
                throw SyncError.localStoreUnavailable
            }
        }
        Self.logger.debug("apply matched local tags=\(localTags.count, privacy: .public)/\(tagIdSet.count, privacy: .public)")
        var tagMap = Dictionary(uniqueKeysWithValues: localTags.map { ($0.id, $0) })
        var acceptedRemoteTagIds = Set<UUID>()
        var tagAcknowledgements: [(tag: Tag, keepSubmittedMutation: Bool)] = []
        
        // Apply Tags
        if !remoteTags.isEmpty {
            for dto in remoteTags {
                guard let tagId = UUID(uuidString: dto.id) else { continue }
                let remoteUpdatedAt = dto.updatedAt.flatMap { mapper.parseDate($0) }
                if let existing = tagMap[tagId] {
                    let currentFingerprint = SyncEntityFingerprint.tag(existing)
                    let isDirty = currentFingerprint != existing.acknowledgedFingerprint
                    let isOwnAcknowledgement = sameMutation(dto.mutationId, existing.lastSubmittedMutationId)

                    if isOwnAcknowledgement {
                        rebase(tag: existing, from: dto, remoteUpdatedAt: remoteUpdatedAt)
                        if currentFingerprint != existing.lastSubmittedFingerprint {
                            // The tag changed while this request was in flight.
                            // ACK only the submitted snapshot; the current one
                            // remains dirty for the next upload.
                            existing.acknowledgedFingerprint = existing.lastSubmittedFingerprint
                            continue
                        }
                        mapper.apply(dto, to: existing)
                        existing.updatedAt = normalizeSyncedUpdatedAt(existing.updatedAt, localSyncAnchor: localSyncAnchor)
                        acceptedRemoteTagIds.insert(tagId)
                        tagAcknowledgements.append((existing, true))
                        continue
                    }

                    if forcedTagIds.contains(tagId) {
                        if isDirty, versionConflictTagIds.contains(tagId) {
                            preservedTagConflicts.append(preserveLocalTagConflict(existing, context: context))
                        } else if isDirty, currentFingerprint != existing.lastSubmittedFingerprint {
                            // `forced` is also used for idempotent replay and
                            // server-side hierarchy repair. Without a real
                            // version conflict, keep an edit made during this
                            // request and rebase it for a clean next upload.
                            rebase(tag: existing, from: dto, remoteUpdatedAt: remoteUpdatedAt)
                            existing.lastSubmittedMutationId = nil
                            existing.lastSubmittedFingerprint = nil
                            continue
                        }
                        mapper.apply(dto, to: existing)
                        existing.serverMutationId = dto.mutationId
                        existing.updatedAt = normalizeSyncedUpdatedAt(existing.updatedAt, localSyncAnchor: localSyncAnchor)
                        acceptedRemoteTagIds.insert(tagId)
                        tagAcknowledgements.append((existing, false))
                        continue
                    }

                    if dto.mutationId != nil, isDirty {
                        // This is not a server-declared conflict: it is a later
                        // local edit racing a downloaded foreign state. Preserve
                        // local content and advance only its server baseline.
                        rebase(tag: existing, from: dto, remoteUpdatedAt: remoteUpdatedAt)
                        existing.lastSubmittedMutationId = nil
                        existing.lastSubmittedFingerprint = nil
                        continue
                    }

                    if dto.mutationId == nil, existing.updatedAt > localSyncAnchor {
                        // Protocol-v3 fallback for an editor save racing an old
                        // server response.
                        rebase(tag: existing, from: dto, remoteUpdatedAt: remoteUpdatedAt)
                        continue
                    }
                    if dto.mutationId != nil || shouldApply(remoteVersion: dto.version, remoteUpdatedAt: remoteUpdatedAt, localVersion: existing.version, localUpdatedAt: existing.updatedAt) {
                        mapper.apply(dto, to: existing)
                        existing.serverMutationId = dto.mutationId
                        existing.updatedAt = normalizeSyncedUpdatedAt(existing.updatedAt, localSyncAnchor: localSyncAnchor)
                        acceptedRemoteTagIds.insert(tagId)
                        tagAcknowledgements.append((existing, false))
                    }
                } else {
                    let newTag = Tag(name: dto.name, userId: userId)
                    newTag.id = tagId
                    mapper.apply(dto, to: newTag)
                    newTag.serverMutationId = dto.mutationId
                    newTag.updatedAt = normalizeSyncedUpdatedAt(newTag.updatedAt, localSyncAnchor: localSyncAnchor)
                    context.insert(newTag)
                    tagMap[tagId] = newTag
                    acceptedRemoteTagIds.insert(tagId)
                    tagAcknowledgements.append((newTag, false))
                }
            }
            
            // Second pass for Tag hierarchy
            for dto in remoteTags {
                guard let tagId = UUID(uuidString: dto.id),
                      acceptedRemoteTagIds.contains(tagId),
                      let tag = tagMap[tagId] else { continue }
                if let parentIdStr = dto.parentId, let parentId = UUID(uuidString: parentIdStr) {
                    tag.parent = tagMap[parentId]
                } else {
                    tag.parent = nil
                }
            }

            for acknowledgement in tagAcknowledgements {
                acknowledgement.tag.acknowledgedFingerprint = SyncEntityFingerprint.tag(acknowledgement.tag)
                if !acknowledgement.keepSubmittedMutation {
                    acknowledgement.tag.lastSubmittedMutationId = nil
                    acknowledgement.tag.lastSubmittedFingerprint = nil
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
            do {
                localNotes = try context.fetch(noteDescriptor)
            } catch {
                Self.logger.error("apply local notes fetch failed: \(error.localizedDescription, privacy: .public)")
                throw SyncError.localStoreUnavailable
            }
        }
        Self.logger.debug("apply matched local notes=\(localNotes.count, privacy: .public)/\(remoteNoteIds.count, privacy: .public)")
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
                let currentFingerprint = SyncEntityFingerprint.note(existing)
                let isDirty = currentFingerprint != existing.acknowledgedFingerprint
                let isOwnAcknowledgement = sameMutation(dto.mutationId, existing.lastSubmittedMutationId)

                if isOwnAcknowledgement {
                    rebase(note: existing, from: dto, remoteUpdatedAt: remoteUpdatedAt)
                    if currentFingerprint != existing.lastSubmittedFingerprint {
                        existing.acknowledgedFingerprint = existing.lastSubmittedFingerprint
                        continue
                    }
                    mapper.apply(dto, to: existing)
                    existing.updatedAt = normalizeSyncedUpdatedAt(existing.updatedAt, localSyncAnchor: localSyncAnchor)
                    existing.syncContentStructure(with: context)
                    resolveTags(for: existing)
                    existing.acknowledgedFingerprint = SyncEntityFingerprint.note(existing)
                    continue
                }

                if forcedNoteIds.contains(id) {
                    let isFinishedImportAuthority = shouldAcceptFinishedImportAuthority(local: existing, remote: dto)
                    if isDirty, versionConflictNoteIds.contains(id), !isFinishedImportAuthority {
                        preserveLocalNoteConflict(existing, context: context)
                    } else if isDirty,
                              currentFingerprint != existing.lastSubmittedFingerprint,
                              !isFinishedImportAuthority {
                        rebase(note: existing, from: dto, remoteUpdatedAt: remoteUpdatedAt)
                        existing.lastSubmittedMutationId = nil
                        existing.lastSubmittedFingerprint = nil
                        continue
                    }
                    mapper.apply(dto, to: existing)
                    existing.serverMutationId = dto.mutationId
                    existing.updatedAt = normalizeSyncedUpdatedAt(existing.updatedAt, localSyncAnchor: localSyncAnchor)
                    existing.syncContentStructure(with: context)
                    resolveTags(for: existing)
                    existing.acknowledgedFingerprint = SyncEntityFingerprint.note(existing)
                    existing.lastSubmittedMutationId = nil
                    existing.lastSubmittedFingerprint = nil
                    continue
                }

                if dto.mutationId != nil, isDirty {
                    rebase(note: existing, from: dto, remoteUpdatedAt: remoteUpdatedAt)
                    existing.lastSubmittedMutationId = nil
                    existing.lastSubmittedFingerprint = nil
                    continue
                }

                if dto.mutationId == nil, existing.updatedAt > localSyncAnchor {
                    // Protocol-v3 fallback.
                    rebase(note: existing, from: dto, remoteUpdatedAt: remoteUpdatedAt)
                    continue
                }
                if dto.mutationId != nil || shouldApply(remoteVersion: dto.version, remoteUpdatedAt: remoteUpdatedAt, localVersion: existing.version, localUpdatedAt: existing.updatedAt) {
                    mapper.apply(dto, to: existing)
                    existing.serverMutationId = dto.mutationId
                    existing.updatedAt = normalizeSyncedUpdatedAt(existing.updatedAt, localSyncAnchor: localSyncAnchor)
                    existing.syncContentStructure(with: context)
                    resolveTags(for: existing)
                    existing.acknowledgedFingerprint = SyncEntityFingerprint.note(existing)
                    existing.lastSubmittedMutationId = nil
                    existing.lastSubmittedFingerprint = nil
                }
            } else {
                let note = Note(content: dto.content, userId: userId)
                note.id = id
                mapper.apply(dto, to: note)
                note.serverMutationId = dto.mutationId
                note.updatedAt = normalizeSyncedUpdatedAt(note.updatedAt, localSyncAnchor: localSyncAnchor)
                note.syncContentStructure(with: context)
                resolveTags(for: note)
                note.acknowledgedFingerprint = SyncEntityFingerprint.note(note)
                context.insert(note)
                notesById[id] = note
            }
        }

        // Applying remote notes can replace their tag array, so restore every
        // relationship captured for a preserved local tag branch afterwards.
        for preserved in preservedTagConflicts {
            preserved.clone.parent = preserved.parent
            for child in preserved.children {
                child.parent = preserved.clone
            }
            for note in preserved.notes where !note.tags.contains(where: { $0.id == preserved.clone.id }) {
                note.tags.append(preserved.clone)
            }
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - start
        Self.logger.debug("apply elapsed=\(elapsed, privacy: .public)s")
    }

    private func normalizeSyncedUpdatedAt(_ updatedAt: Date, localSyncAnchor: Date) -> Date {
        min(updatedAt, localSyncAnchor)
    }

    private func rebase(tag: Tag, from dto: TagDTO, remoteUpdatedAt: Date?) {
        if let remoteVersion = dto.version {
            tag.version = remoteVersion
        }
        if let remoteUpdatedAt {
            tag.serverUpdatedAt = remoteUpdatedAt
        }
        if let mutationId = dto.mutationId {
            tag.serverMutationId = mutationId
        }
    }

    private func rebase(note: Note, from dto: NoteDTO, remoteUpdatedAt: Date?) {
        if let remoteVersion = dto.version {
            note.version = remoteVersion
        }
        if let remoteUpdatedAt {
            note.serverUpdatedAt = remoteUpdatedAt
        }
        if let mutationId = dto.mutationId {
            note.serverMutationId = mutationId
        }
    }

    private func shouldAcceptFinishedImportAuthority(local: Note, remote: NoteDTO) -> Bool {
        guard local.importStatus == .queued || local.importStatus == .processing,
              let localJobId = local.importJobId,
              !localJobId.isEmpty,
              localJobId == remote.importJobId,
              let remoteStatus = remote.importStatus else {
            return false
        }
        return remoteStatus == NoteImportStatus.completed.rawValue
            || remoteStatus == NoteImportStatus.failed.rawValue
    }

    @discardableResult
    private func preserveLocalNoteConflict(_ source: Note, context: ModelContext) -> Note {
        let clone = Note(content: source.content, userId: source.userId)
        clone.contentFormat = source.contentFormat
        clone.checklistNotes = source.checklistNotes
        clone.previewPlainText = source.previewPlainText
        clone.createdAt = source.createdAt
        clone.updatedAt = source.updatedAt
        clone.deletedAt = source.deletedAt
        clone.pinnedAt = source.pinnedAt
        clone.version = 0
        clone.serverUpdatedAt = source.serverUpdatedAt
        clone.serverDeletedAt = source.serverDeletedAt
        clone.lastModifiedByDeviceId = source.lastModifiedByDeviceId
        clone.contentParseBackup = source.contentParseBackup
        clone.sourceURL = source.sourceURL
        clone.sourceTitle = source.sourceTitle
        clone.sourcePlatformID = source.sourcePlatformID
        clone.sourcePlatformName = source.sourcePlatformName
        clone.sourceHost = source.sourceHost
        clone.sourceAuthorName = source.sourceAuthorName
        clone.sourceAuthorHandle = source.sourceAuthorHandle
        clone.sourceCapturedAt = source.sourceCapturedAt
        clone.section = .drafts
        clone.importStatusRaw = source.importStatusRaw
        clone.importJobId = source.importJobId
        clone.importErrorCode = source.importErrorCode
        clone.importStartedAt = source.importStartedAt
        clone.importCompletedAt = source.importCompletedAt
        clone.tags = source.tags
        clone.serverMutationId = nil
        clone.lastSubmittedMutationId = nil
        clone.lastSubmittedFingerprint = nil
        clone.acknowledgedFingerprint = nil
        clone.syncContentStructure(with: context)
        context.insert(clone)
        return clone
    }

    private func preserveLocalTagConflict(_ source: Tag, context: ModelContext) -> PreservedTagConflict {
        let clone = Tag(name: source.name, userId: source.userId, colorHex: source.colorHex)
        clone.createdAt = source.createdAt
        clone.updatedAt = source.updatedAt
        clone.lastUsedAt = source.lastUsedAt
        clone.deletedAt = source.deletedAt
        clone.version = 0
        clone.serverUpdatedAt = source.serverUpdatedAt
        clone.serverDeletedAt = source.serverDeletedAt
        clone.lastModifiedByDeviceId = source.lastModifiedByDeviceId
        clone.aiSummary = source.aiSummary
        clone.sortOrder = source.sortOrder
        clone.parent = source.parent
        clone.notes = source.notes
        clone.serverMutationId = nil
        clone.lastSubmittedMutationId = nil
        clone.lastSubmittedFingerprint = nil
        clone.acknowledgedFingerprint = nil
        context.insert(clone)
        return PreservedTagConflict(
            clone: clone,
            parent: source.parent,
            children: source.children,
            notes: source.notes
        )
    }
}

private struct PreservedTagConflict {
    let clone: Tag
    let parent: Tag?
    let children: [Tag]
    let notes: [Note]
}
