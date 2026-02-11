import Foundation

struct NoteDTO: Codable {
    let id: String
    let content: String
    let createdAt: String
    let updatedAt: String?
    let deletedAt: String?
    let pinnedAt: String?
    let tagIds: [String]? // Optional for backward compatibility
    let version: Int?
    let baseVersion: Int?
    let clientUpdatedAt: String?
    let lastModifiedByDeviceId: String?
}

struct TagDTO: Codable {
    let id: String
    let name: String
    let colorHex: String
    let createdAt: String
    let updatedAt: String?
    let lastUsedAt: String?
    let sortOrder: Int
    let parentId: String? // Hierarchy support
    let deletedAt: String?
    let version: Int?
    let baseVersion: Int?
    let clientUpdatedAt: String?
    let lastModifiedByDeviceId: String?
}

struct SyncPayload: Codable {
    let cursor: String?
    let deviceId: String?
    let notes: [NoteDTO]
    let tags: [TagDTO]?
    let preferences: [String: String]?
}

struct SyncChanges: Codable {
    let notes: [NoteDTO]
    let tags: [TagDTO]?
    let preferences: [String: String]?
}

struct ConflictDTO: Codable {
    let entityType: String
    let id: String
    let serverVersion: Int
    let serverContent: String?
    let clientContent: String?
    let message: String
}

struct SyncResponse: Codable {
    let cursor: String
    let changes: SyncChanges
    let conflicts: [ConflictDTO]
    let serverTime: String
}
