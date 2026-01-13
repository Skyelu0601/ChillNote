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
            deletedAt: note.deletedAt.map { dateFormatter.string(from: $0) }
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
    }
}
