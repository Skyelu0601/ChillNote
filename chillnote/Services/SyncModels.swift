import Foundation

struct NoteDTO: Codable {
    let id: String
    let content: String
    let createdAt: String
    let updatedAt: String
    let deletedAt: String?
}

struct SyncPayload: Codable {
    let notes: [NoteDTO]
}
