import Foundation
import SwiftData

enum SyncError: Error {
    case disabled
    case invalidURL
    case remoteUnavailable
    case unauthorized
    case serverError
}

protocol SyncService {
    func syncAll(context: ModelContext) async throws -> SyncResult
}

struct SyncConfig {
    let baseURL: URL
    let authToken: String?
    let since: Date?
    let cursor: String?
    let localSyncAnchor: Date
    let userId: String
    let deviceId: String
    let hardDeletedNoteIds: [String]
    let hardDeletedTagIds: [String]
}

struct SyncResult {
    let cursor: String?
    let serverTime: Date?
    let remoteHardDeletedNoteIds: [String]
    let remoteHardDeletedTagIds: [String]
}

struct RemoteSyncService: SyncService {
    let config: SyncConfig
    
    func syncAll(context: ModelContext) async throws -> SyncResult {
        let payload = makeSyncPayload(
            context: context,
            since: config.since,
            userId: config.userId,
            cursor: config.cursor,
            deviceId: config.deviceId,
            hardDeletedNoteIds: config.hardDeletedNoteIds,
            hardDeletedTagIds: config.hardDeletedTagIds
        )
        
        guard let url = URLComponents(url: config.baseURL.appendingPathComponent("sync"), resolvingAgainstBaseURL: false)?.url else {
            throw SyncError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = config.authToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let httpBody = try await Task.detached(priority: .utility) {
            let encoder = JSONEncoder()
            return try encoder.encode(payload)
        }.value
        request.httpBody = httpBody
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.remoteUnavailable
        }
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw SyncError.unauthorized
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SyncError.serverError
        }
        
        let remoteResponse = try await Task.detached(priority: .utility) {
            let decoder = JSONDecoder()
            return try decoder.decode(SyncResponse.self, from: data)
        }.value
        applyRemotePayload(
            context: context,
            response: remoteResponse,
            userId: config.userId,
            localSyncAnchor: config.localSyncAnchor
        )
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]
        let serverTime = formatter.date(from: remoteResponse.serverTime) ?? fallbackFormatter.date(from: remoteResponse.serverTime)
        return SyncResult(
            cursor: remoteResponse.cursor,
            serverTime: serverTime,
            remoteHardDeletedNoteIds: remoteResponse.changes.hardDeletedNoteIds ?? [],
            remoteHardDeletedTagIds: remoteResponse.changes.hardDeletedTagIds ?? []
        )
    }
}

private func makeSyncPayload(
    context: ModelContext,
    since: Date?,
    userId: String,
    cursor: String?,
    deviceId: String,
    hardDeletedNoteIds: [String],
    hardDeletedTagIds: [String]
) -> SyncPayload {
    let engine = SyncEngine()
    return engine.makePayload(
        context: context,
        since: since,
        userId: userId,
        cursor: cursor,
        deviceId: deviceId,
        hardDeletedNoteIds: hardDeletedNoteIds,
        hardDeletedTagIds: hardDeletedTagIds
    )
}

private func applyRemotePayload(context: ModelContext, response: SyncResponse, userId: String, localSyncAnchor: Date) {
    let engine = SyncEngine()
    engine.apply(remote: response, context: context, userId: userId, localSyncAnchor: localSyncAnchor)
}
