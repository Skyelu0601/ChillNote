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

struct LocalSyncService: SyncService {
    func syncAll(context: ModelContext) async throws -> SyncResult {
        // Offline fallback: no-op sync for local testing.
        return SyncResult(cursor: nil, serverTime: nil)
    }
}

struct SyncConfig {
    let baseURL: URL
    let authToken: String?
    let since: Date?
    let cursor: String?
    let userId: String
    let deviceId: String
}

struct SyncResult {
    let cursor: String?
    let serverTime: Date?
}

struct RemoteSyncService: SyncService {
    let config: SyncConfig
    
    func syncAll(context: ModelContext) async throws -> SyncResult {
        let payload = makeSyncPayload(context: context, since: config.since, userId: config.userId, cursor: config.cursor, deviceId: config.deviceId)
        
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
        applyRemotePayload(context: context, response: remoteResponse, userId: config.userId)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let serverTime = formatter.date(from: remoteResponse.serverTime) ?? ISO8601DateFormatter().date(from: remoteResponse.serverTime)
        return SyncResult(cursor: remoteResponse.cursor, serverTime: serverTime)
    }
}

private func makeSyncPayload(context: ModelContext, since: Date?, userId: String, cursor: String?, deviceId: String) -> SyncPayload {
    let engine = SyncEngine()
    return engine.makePayload(context: context, since: since, userId: userId, cursor: cursor, deviceId: deviceId)
}

private func applyRemotePayload(context: ModelContext, response: SyncResponse, userId: String) {
    let engine = SyncEngine()
    engine.apply(remote: response, context: context, userId: userId)
}
