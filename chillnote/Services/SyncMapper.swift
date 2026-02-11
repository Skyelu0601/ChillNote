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
            updatedAt: nil,
            deletedAt: note.deletedAt.map { dateFormatter.string(from: $0) },
            pinnedAt: note.pinnedAt.map { dateFormatter.string(from: $0) },
            tagIds: note.tags
                .filter { $0.deletedAt == nil }
                .map { $0.id.uuidString },
            version: nil,
            baseVersion: note.version,
            clientUpdatedAt: dateFormatter.string(from: note.updatedAt),
            lastModifiedByDeviceId: note.lastModifiedByDeviceId
        )
    }

    func tagDTO(from tag: Tag) -> TagDTO {
        TagDTO(
            id: tag.id.uuidString,
            name: tag.name,
            colorHex: tag.colorHex,
            createdAt: dateFormatter.string(from: tag.createdAt),
            updatedAt: nil,
            lastUsedAt: dateFormatter.string(from: tag.lastUsedAt),
            sortOrder: tag.sortOrder,
            parentId: tag.parent?.id.uuidString,
            deletedAt: tag.deletedAt.map { dateFormatter.string(from: $0) },
            version: nil,
            baseVersion: tag.version,
            clientUpdatedAt: dateFormatter.string(from: tag.updatedAt),
            lastModifiedByDeviceId: tag.lastModifiedByDeviceId
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
        if let updatedAt = dto.updatedAt, let date = parseDate(updatedAt) {
            note.serverUpdatedAt = date
            note.updatedAt = date
        }
        if let deletedAt = dto.deletedAt, let date = parseDate(deletedAt) {
            note.deletedAt = date
            note.serverDeletedAt = date
        } else {
            note.deletedAt = nil
            note.serverDeletedAt = nil
        }
        if let pinnedAt = dto.pinnedAt, let date = parseDate(pinnedAt) {
            note.pinnedAt = date
        } else {
            note.pinnedAt = nil
        }
        if let version = dto.version {
            note.version = version
        }
        if let deviceId = dto.lastModifiedByDeviceId {
            note.lastModifiedByDeviceId = deviceId
        }
        // Tags are handled separately in SyncEngine to resolve relationships
    }

    func apply(_ dto: TagDTO, to tag: Tag) {
        tag.name = dto.name
        tag.colorHex = dto.colorHex
        if let createdAt = parseDate(dto.createdAt) {
            tag.createdAt = createdAt
        }
        if let updatedAt = dto.updatedAt, let date = parseDate(updatedAt) {
            tag.serverUpdatedAt = date
            tag.updatedAt = date
        }
        if let lastUsedAt = dto.lastUsedAt, let date = parseDate(lastUsedAt) {
            tag.lastUsedAt = date
        }
        if let deletedAt = dto.deletedAt, let date = parseDate(deletedAt) {
            tag.deletedAt = date
            tag.serverDeletedAt = date
        } else {
            tag.deletedAt = nil
            tag.serverDeletedAt = nil
        }
        tag.sortOrder = dto.sortOrder
        if let version = dto.version {
            tag.version = version
        }
        if let deviceId = dto.lastModifiedByDeviceId {
            tag.lastModifiedByDeviceId = deviceId
        }
        // Parent/Child relationship is handled in SyncEngine
    }


}
