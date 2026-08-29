import CryptoKit
import Foundation

/// Local-only content identities for durable sync. The server never needs to
/// reproduce these hashes: they let the client distinguish a real local edit
/// from clock skew, retries, and metadata-only server updates.
enum SyncEntityFingerprint {
    static func note(_ note: Note) -> String {
        digest([
            note.content,
            date(note.createdAt),
            date(note.deletedAt),
            date(note.pinnedAt),
            note.tags
                .filter { $0.deletedAt == nil }
                .map { $0.id.uuidString.lowercased() }
                .sorted()
                .joined(separator: ","),
            note.sourceURL,
            note.sourceTitle,
            note.sourcePlatformID,
            note.sourcePlatformName,
            note.sourceHost,
            note.sourceAuthorName,
            note.sourceAuthorHandle,
            date(note.sourceCapturedAt),
            note.sectionRaw,
            note.importStatusRaw,
            note.importJobId,
            note.importErrorCode,
            date(note.importStartedAt),
            date(note.importCompletedAt)
        ])
    }

    static func tag(_ tag: Tag) -> String {
        digest([
            tag.name,
            tag.colorHex,
            date(tag.createdAt),
            date(tag.lastUsedAt),
            date(tag.deletedAt),
            String(tag.sortOrder),
            tag.parent?.id.uuidString.lowercased()
        ])
    }

    private static func date(_ value: Date?) -> String? {
        value.map { String($0.timeIntervalSinceReferenceDate.bitPattern) }
    }

    private static func date(_ value: Date) -> String {
        String(value.timeIntervalSinceReferenceDate.bitPattern)
    }

    private static func digest(_ fields: [String?]) -> String {
        // Length-prefix every field so nil, empty, and embedded separators are
        // unambiguous without relying on dictionary/JSON key ordering.
        let canonical = fields.map { value -> String in
            guard let value else { return "n" }
            return "s\(value.utf8.count):\(value)"
        }.joined(separator: "|")
        return SHA256.hash(data: Data(canonical.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

struct SyncMapper {
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private let fallbackDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
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
                .map { $0.id.uuidString }
                .sorted(),
            version: nil,
            baseVersion: note.version,
            clientUpdatedAt: dateFormatter.string(from: note.updatedAt),
            lastModifiedByDeviceId: note.lastModifiedByDeviceId,
            mutationId: note.lastSubmittedMutationId,
            previousMutationId: note.serverMutationId,
            sourceURL: note.sourceURL,
            sourceTitle: note.sourceTitle,
            sourcePlatformID: note.sourcePlatformID,
            sourcePlatformName: note.sourcePlatformName,
            sourceHost: note.sourceHost,
            sourceAuthorName: note.sourceAuthorName,
            sourceAuthorHandle: note.sourceAuthorHandle,
            sourceCapturedAt: note.sourceCapturedAt.map { dateFormatter.string(from: $0) },
            section: note.section.rawValue,
            importStatus: note.importStatusRaw,
            importJobId: note.importJobId,
            importErrorCode: note.importErrorCode,
            importStartedAt: note.importStartedAt.map { dateFormatter.string(from: $0) },
            importCompletedAt: note.importCompletedAt.map { dateFormatter.string(from: $0) }
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
            lastModifiedByDeviceId: tag.lastModifiedByDeviceId,
            mutationId: tag.lastSubmittedMutationId,
            previousMutationId: tag.serverMutationId
        )
    }



    func parseDate(_ string: String) -> Date? {
        dateFormatter.date(from: string) ?? fallbackDateFormatter.date(from: string)
    }

    func apply(_ dto: NoteDTO, to note: Note) {
        note.updateContent(dto.content)
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
        let isSameSource = note.sourceURL == dto.sourceURL
        note.sourceURL = dto.sourceURL
        note.sourceTitle = dto.sourceTitle
        note.sourcePlatformID = dto.sourcePlatformID
        note.sourcePlatformName = dto.sourcePlatformName
        note.sourceHost = dto.sourceHost
        if dto.sourceAuthorName != nil || dto.sourceAuthorHandle != nil {
            note.sourceAuthorName = dto.sourceAuthorName
            note.sourceAuthorHandle = dto.sourceAuthorHandle
        } else if !isSameSource {
            note.sourceAuthorName = nil
            note.sourceAuthorHandle = nil
        }
        note.sourceCapturedAt = dto.sourceCapturedAt.flatMap { parseDate($0) }
        note.section = dto.section.flatMap(NoteSection.init(rawValue:)) ?? .inbox
        note.importStatusRaw = dto.importStatus
        note.importJobId = dto.importJobId
        note.importErrorCode = dto.importErrorCode
        note.importStartedAt = dto.importStartedAt.flatMap { parseDate($0) }
        note.importCompletedAt = dto.importCompletedAt.flatMap { parseDate($0) }
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
