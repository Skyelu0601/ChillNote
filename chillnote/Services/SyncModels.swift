import Foundation

struct NoteDTO: Codable {
    let id: String
    let content: String
    let createdAt: String
    let updatedAt: String
    let deletedAt: String?
    let pinnedAt: String?
    let tagIds: [String]? // Optional for backward compatibility
}

struct TagDTO: Codable {
    let id: String
    let name: String
    let colorHex: String
    let createdAt: String
    let updatedAt: String
    let lastUsedAt: String?
    let sortOrder: Int
    let parentId: String? // Hierarchy support
    let deletedAt: String?
}



struct SyncPayload: Codable {
    let notes: [NoteDTO]
    let tags: [TagDTO]?

    let preferences: [String: String]?
}
