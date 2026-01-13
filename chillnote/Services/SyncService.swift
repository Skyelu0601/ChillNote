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
    func syncAll(context: ModelContext) async throws
}

struct LocalSyncService: SyncService {
    func syncAll(context: ModelContext) async throws {
        // Offline fallback: no-op sync for local testing.
    }
}

struct SyncConfig {
    let baseURL: URL
    let authToken: String?
    let since: Date?
}

struct RemoteSyncService: SyncService {
    let config: SyncConfig
    
    func syncAll(context: ModelContext) async throws {
        let engine = SyncEngine()
        let payload = engine.makePayload(context: context)
        
        var urlComponents = URLComponents(url: config.baseURL.appendingPathComponent("sync"), resolvingAgainstBaseURL: false)
        if let since = config.since {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            urlComponents?.queryItems = [
                URLQueryItem(name: "since", value: formatter.string(from: since))
            ]
        }
        guard let url = urlComponents?.url else {
            throw SyncError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = config.authToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(payload)
        
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
        
        let decoder = JSONDecoder()
        let remotePayload = try decoder.decode(SyncPayload.self, from: data)
        engine.apply(remote: remotePayload, context: context)
    }
}
