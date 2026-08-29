import Foundation
import SwiftData

enum SyncError: Error {
    case disabled
    case invalidURL
    case localStoreUnavailable
    case remoteUnavailable
    case unauthorized
    case serverError
    case authSessionChanged
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
    let isSessionCurrent: @Sendable () async -> Bool
}

struct SyncResult {
    let cursor: String?
    let serverTime: Date?
    let remoteHardDeletedNoteIds: [String]
    let remoteHardDeletedTagIds: [String]
}

enum SyncAcknowledgementValidator {
    /// Returns true only when every locally submitted entity has an authoritative
    /// representation in the response. Conflict metadata alone is deliberately
    /// ignored: the response must also include the winning entity or tombstone.
    /// Hard-delete requests are stricter and require their corresponding tombstone.
    static func hasCompleteAuthoritativeAcknowledgements(
        payload: SyncPayload,
        response: SyncResponse
    ) -> Bool {
        guard let submittedNoteIDs = normalizedUUIDs(payload.notes.map(\.id)),
              let submittedTagIDs = normalizedUUIDs((payload.tags ?? []).map(\.id)),
              let submittedHardDeletedNoteIDs = normalizedUUIDs(payload.hardDeletedNoteIds ?? []),
              let submittedHardDeletedTagIDs = normalizedUUIDs(payload.hardDeletedTagIds ?? []) else {
            return false
        }

        let hardDeletedNoteIDs = Set(
            (response.changes.hardDeletedNoteIds ?? []).compactMap(UUID.init(uuidString:))
        )
        let hardDeletedTagIDs = Set(
            (response.changes.hardDeletedTagIds ?? []).compactMap(UUID.init(uuidString:))
        )
        let responseNotes = Dictionary(
            response.changes.notes.compactMap { dto in
                UUID(uuidString: dto.id).map { ($0, dto) }
            },
            uniquingKeysWith: { _, latest in latest }
        )
        let responseTags = Dictionary(
            (response.changes.tags ?? []).compactMap { dto in
                UUID(uuidString: dto.id).map { ($0, dto) }
            },
            uniquingKeysWith: { _, latest in latest }
        )
        let authoritativeNoteIDs = Set(responseNotes.keys).union(hardDeletedNoteIDs)
        let authoritativeTagIDs = Set(responseTags.keys).union(hardDeletedTagIDs)

        if (payload.protocolVersion ?? 0) >= 4 {
            guard let forcedNoteIDs = normalizedUUIDs(response.forcedNoteIds ?? []),
                  let forcedTagIDs = normalizedUUIDs(response.forcedTagIds ?? []),
                  forcedNoteIDs.isSubset(of: Set(responseNotes.keys)),
                  forcedTagIDs.isSubset(of: Set(responseTags.keys)) else {
                // `forced*Ids` means that the ordinary entity in `changes` is
                // authoritative even though its mutation differs. A tombstone
                // (or a missing/invalid ID) must use the hard-delete channel;
                // otherwise the client could advance its cursor without ever
                // receiving the state it was told to force-apply.
                return false
            }
            for submitted in payload.notes {
                guard let id = UUID(uuidString: submitted.id) else { return false }
                if hardDeletedNoteIDs.contains(id) { continue }
                guard let authoritative = responseNotes[id] else { return false }
                guard forcedNoteIDs.contains(id)
                        || sameMutation(submitted.mutationId, authoritative.mutationId) else {
                    return false
                }
            }
            for submitted in payload.tags ?? [] {
                guard let id = UUID(uuidString: submitted.id) else { return false }
                if hardDeletedTagIDs.contains(id) { continue }
                guard let authoritative = responseTags[id] else { return false }
                guard forcedTagIDs.contains(id)
                        || sameMutation(submitted.mutationId, authoritative.mutationId) else {
                    return false
                }
            }
        }

        return submittedNoteIDs.isSubset(of: authoritativeNoteIDs)
            && submittedTagIDs.isSubset(of: authoritativeTagIDs)
            && submittedHardDeletedNoteIDs.isSubset(of: hardDeletedNoteIDs)
            && submittedHardDeletedTagIDs.isSubset(of: hardDeletedTagIDs)
    }

    private static func normalizedUUIDs(_ values: [String]) -> Set<UUID>? {
        var result = Set<UUID>()
        for value in values {
            guard let id = UUID(uuidString: value) else { return nil }
            result.insert(id)
        }
        return result
    }

    private static func sameMutation(_ left: String?, _ right: String?) -> Bool {
        guard let left, let right else { return false }
        return left.caseInsensitiveCompare(right) == .orderedSame
    }
}

struct RemoteSyncService: SyncService {
    let config: SyncConfig
    
    func syncAll(context: ModelContext) async throws -> SyncResult {
        guard await config.isSessionCurrent() else {
            throw SyncError.authSessionChanged
        }
        let payload = try makeSyncPayload(
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

        // Payload construction persists durable mutation IDs. Re-check auth
        // after that suspension point and before any bytes leave the device.
        guard await config.isSessionCurrent() else {
            throw SyncError.authSessionChanged
        }
        
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
        guard SyncAcknowledgementValidator.hasCompleteAuthoritativeAcknowledgements(
            payload: payload,
            response: remoteResponse
        ) else {
            throw SyncError.serverError
        }
        guard await config.isSessionCurrent() else {
            throw SyncError.authSessionChanged
        }
        try Self.applyRemoteResponseUsingFreshContext(
            sourceContext: context,
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

    /// The payload context may have cached records while the request was in
    /// flight. Applying through a new context guarantees that the anchor guard
    /// observes edits committed by the UI during that interval.
    static func applyRemoteResponseUsingFreshContext(
        sourceContext: ModelContext,
        response: SyncResponse,
        userId: String,
        localSyncAnchor: Date
    ) throws {
        let applyContext = ModelContext(sourceContext.container)
        try applyRemotePayload(
            context: applyContext,
            response: response,
            userId: userId,
            localSyncAnchor: localSyncAnchor
        )
        try applyContext.save()
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
) throws -> SyncPayload {
    let engine = SyncEngine()
    return try engine.makePayload(
        context: context,
        since: since,
        userId: userId,
        cursor: cursor,
        deviceId: deviceId,
        hardDeletedNoteIds: hardDeletedNoteIds,
        hardDeletedTagIds: hardDeletedTagIds
    )
}

private func applyRemotePayload(context: ModelContext, response: SyncResponse, userId: String, localSyncAnchor: Date) throws {
    let engine = SyncEngine()
    try engine.apply(remote: response, context: context, userId: userId, localSyncAnchor: localSyncAnchor)
}
