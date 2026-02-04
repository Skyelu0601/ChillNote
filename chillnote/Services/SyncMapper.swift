import Foundation

struct SyncMapper {
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    func noteDTO(from note: Note) -> NoteDTO {
        NoteDTO(
            id: note.id.uuidString,
            content: note.content,
            createdAt: dateFormatter.string(from: note.createdAt),
            updatedAt: dateFormatter.string(from: note.updatedAt),
            deletedAt: note.deletedAt.map { dateFormatter.string(from: $0) },
            pinnedAt: note.pinnedAt.map { dateFormatter.string(from: $0) },
            tagIds: note.tags
                .filter { $0.deletedAt == nil }
                .map { $0.id.uuidString }
        )
    }

    func tagDTO(from tag: Tag) -> TagDTO {
        TagDTO(
            id: tag.id.uuidString,
            name: tag.name,
            colorHex: tag.colorHex,
            createdAt: dateFormatter.string(from: tag.createdAt),
            updatedAt: dateFormatter.string(from: tag.updatedAt),
            lastUsedAt: dateFormatter.string(from: tag.lastUsedAt),
            sortOrder: tag.sortOrder,
            parentId: tag.parent?.id.uuidString,
            deletedAt: tag.deletedAt.map { dateFormatter.string(from: $0) }
        )
    }



    func parseDate(_ string: String) -> Date? {
        dateFormatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }

    func apply(_ dto: NoteDTO, to note: Note) {
        note.content = dto.content
        if let createdAt = parseDate(dto.createdAt) {
            note.createdAt = createdAt
        }
        if let updatedAt = parseDate(dto.updatedAt) {
            note.updatedAt = updatedAt
        }
        if let deletedAt = dto.deletedAt, let date = parseDate(deletedAt) {
            note.deletedAt = date
        } else {
            note.deletedAt = nil
        }
        if let pinnedAt = dto.pinnedAt, let date = parseDate(pinnedAt) {
            note.pinnedAt = date
        } else {
            note.pinnedAt = nil
        }
        // Tags are handled separately in SyncEngine to resolve relationships
    }

    func apply(_ dto: TagDTO, to tag: Tag) {
        tag.name = dto.name
        tag.colorHex = dto.colorHex
        if let createdAt = parseDate(dto.createdAt) {
            tag.createdAt = createdAt
        }
        if let updatedAt = parseDate(dto.updatedAt) {
            tag.updatedAt = updatedAt
        }
        if let lastUsedAt = dto.lastUsedAt, let date = parseDate(lastUsedAt) {
            tag.lastUsedAt = date
        }
        if let deletedAt = dto.deletedAt, let date = parseDate(deletedAt) {
            tag.deletedAt = date
        } else {
            tag.deletedAt = nil
        }
        tag.sortOrder = dto.sortOrder
        // Parent/Child relationship is handled in SyncEngine
    }


}
