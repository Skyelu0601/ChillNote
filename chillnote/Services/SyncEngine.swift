import Foundation
import SwiftData

struct SyncEngine {
    private let mapper = SyncMapper()

    func makePayload(context: ModelContext, since: Date?) -> SyncPayload {
        var descriptor = FetchDescriptor<Note>()
        if let since {
            descriptor.predicate = #Predicate<Note> { note in
                note.updatedAt >= since || (note.deletedAt != nil && note.deletedAt! >= since)
            }
        }

        let notes = (try? context.fetch(descriptor)) ?? []
        return SyncPayload(notes: notes.map { mapper.noteDTO(from: $0) })
    }

    func apply(remote: SyncPayload, context: ModelContext) {
        let localNotes = (try? context.fetch(FetchDescriptor<Note>())) ?? []
        var notesById: [UUID: Note] = Dictionary(uniqueKeysWithValues: localNotes.map { ($0.id, $0) })

        for dto in remote.notes {
            guard let id = UUID(uuidString: dto.id) else { continue }
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
                }
            } else {
                let note = Note(content: dto.content)
                note.id = id
                mapper.apply(dto, to: note)
                note.syncContentStructure(with: context)
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
