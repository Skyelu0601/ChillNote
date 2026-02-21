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
    let hardDeletedNoteIds: [String]?
    let hardDeletedTagIds: [String]?
    let preferences: [String: String]?
}

struct SyncChanges: Codable {
    let notes: [NoteDTO]
    let tags: [TagDTO]?
    let hardDeletedNoteIds: [String]?
    let hardDeletedTagIds: [String]?
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

enum HardDeleteQueueStore {
    private static let notesByUserKey = "syncHardDeleteNotesByUser"
    private static let tagsByUserKey = "syncHardDeleteTagsByUser"

    static func noteIDs(for userId: String) -> [String] {
        values(for: userId, key: notesByUserKey)
    }

    static func tagIDs(for userId: String) -> [String] {
        values(for: userId, key: tagsByUserKey)
    }

    static func enqueue(noteIDs: [UUID], for userId: String) {
        enqueue(ids: noteIDs.map(\.uuidString), for: userId, key: notesByUserKey)
    }

    static func enqueue(tagIDs: [UUID], for userId: String) {
        enqueue(ids: tagIDs.map(\.uuidString), for: userId, key: tagsByUserKey)
    }

    static func dequeue(noteIDs: [String], for userId: String) {
        dequeue(ids: noteIDs, for: userId, key: notesByUserKey)
    }

    static func dequeue(tagIDs: [String], for userId: String) {
        dequeue(ids: tagIDs, for: userId, key: tagsByUserKey)
    }

    private static func enqueue(ids: [String], for userId: String, key: String) {
        guard !ids.isEmpty else { return }
        var map = loadMap(for: key)
        var existing = Set(map[userId] ?? [])
        for id in ids where !id.isEmpty {
            existing.insert(id)
        }
        map[userId] = Array(existing)
        saveMap(map, for: key)
    }

    private static func dequeue(ids: [String], for userId: String, key: String) {
        guard !ids.isEmpty else { return }
        var map = loadMap(for: key)
        var existing = Set(map[userId] ?? [])
        for id in ids where !id.isEmpty {
            existing.remove(id)
        }
        map[userId] = Array(existing)
        saveMap(map, for: key)
    }

    private static func values(for userId: String, key: String) -> [String] {
        let map = loadMap(for: key)
        return map[userId] ?? []
    }

    private static func loadMap(for key: String) -> [String: [String]] {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: [String]]) ?? [:]
    }

    private static func saveMap(_ map: [String: [String]], for key: String) {
        UserDefaults.standard.set(map, forKey: key)
    }
}
