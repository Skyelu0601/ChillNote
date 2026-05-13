import Foundation
import SwiftData
import SwiftUI

@MainActor
final class SyncManager: ObservableObject {
    @AppStorage("syncEnabled") var isEnabled: Bool = true
    @AppStorage("syncLastAt") private var lastSyncAtTimestamp: Double = 0
    @AppStorage("syncCursor") private var syncCursor: String = ""
    @AppStorage("syncDeviceId") private var syncDeviceId: String = ""
    private let serverURLString: String = AppConfig.backendBaseURL
    @AppStorage("syncHasUploadedLocal") private var hasUploadedLocal: Bool = false
    
    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var lastError: String?
    private var hasPendingSyncRequest: Bool = false
    
    private let minimumSyncInterval: TimeInterval = 60

    struct SyncCheckpoint: Equatable {
        let since: Date?
        let cursor: String?
        let shouldMarkUploadedLocalAfterSuccess: Bool
    }

    init() {
        if !isEnabled {
            isEnabled = true
        }
        if syncDeviceId.isEmpty {
            syncDeviceId = UUID().uuidString
        }
    }
    
    var lastSyncAt: Date? {
        guard lastSyncAtTimestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: lastSyncAtTimestamp)
    }
    
    func syncIfNeeded(context: ModelContext) async {
        guard shouldSyncNow() else { return }
        _ = await syncNow(context: context)
    }
    
    @discardableResult
    func syncNow(context: ModelContext) async -> Bool {
        if isSyncing {
            hasPendingSyncRequest = true
            print("[SYNC] syncNow skipped because a sync is already running; queued follow-up sync.")
            return false
        }
        guard isEnabled else {
            lastError = AppErrorCode.syncDisabled.message
            return false
        }
        guard let url = URL(string: serverURLString) else {
            lastError = AppErrorCode.syncServerURLRequired.message
            return false
        }
        guard let currentUserId = AuthService.shared.confirmedUserId else {
            lastError = AppErrorCode.syncSignInRequired.message
            return false
        }
        guard let currentToken = await AuthService.shared.getSessionToken(), !currentToken.isEmpty else {
            lastError = AppErrorCode.syncSessionExpired.message
            return false
        }
        guard let container = DataService.shared.container else {
            lastError = AppErrorCode.syncUnavailable.message
            return false
        }
        WelcomeNoteFlagStore.syncGlobalFlag(for: currentUserId)
        let syncStartedAt = Date()
        isSyncing = true
        lastError = nil
        var didSucceed = false
        do {
            let lastSyncAt = lastSyncAt
            let hasUploadedLocalSnapshot = hasUploadedLocal
            let cursorSnapshot = syncCursor
            let deviceIdSnapshot = syncDeviceId
            let userIdForSync = currentUserId
            let tokenForSync = currentToken
            let hardDeletedNoteIdsSnapshot = HardDeleteQueueStore.noteIDs(for: userIdForSync)
            let hardDeletedTagIdsSnapshot = HardDeleteQueueStore.tagIDs(for: userIdForSync)
            print("[SYNC] syncNow user=\(userIdForSync) since=\(lastSyncAt?.description ?? "nil") cursor=\(cursorSnapshot.isEmpty ? "nil" : cursorSnapshot) hardDeletedNotes=\(hardDeletedNoteIdsSnapshot.count) hardDeletedTags=\(hardDeletedTagIdsSnapshot.count)")
            let syncOutcome = try await Task.detached(priority: .utility) {
                let backgroundContext = ModelContext(container)
                var userNotesDescriptor = FetchDescriptor<Note>()
                userNotesDescriptor.predicate = #Predicate<Note> { note in
                    note.userId == userIdForSync
                }
                let localNotesCount = (try? backgroundContext.fetchCount(userNotesDescriptor)) ?? 0
                let checkpoint = Self.resolveCheckpoint(
                    lastSyncAt: lastSyncAt,
                    cursor: cursorSnapshot,
                    hasUploadedLocal: hasUploadedLocalSnapshot,
                    localNotesCount: localNotesCount
                )
                let config = SyncConfig(
                    baseURL: url,
                    authToken: tokenForSync,
                    since: checkpoint.since,
                    cursor: checkpoint.cursor,
                    localSyncAnchor: syncStartedAt,
                    userId: userIdForSync,
                    deviceId: deviceIdSnapshot,
                    hardDeletedNoteIds: hardDeletedNoteIdsSnapshot,
                    hardDeletedTagIds: hardDeletedTagIdsSnapshot
                )
                let service: SyncService = RemoteSyncService(config: config)
                let result = try await service.syncAll(context: backgroundContext)
                TagService.shared.cleanupEmptyTags(context: backgroundContext, shouldSave: false)
                try backgroundContext.save()
                let postSyncNotesCount = (try? backgroundContext.fetchCount(userNotesDescriptor)) ?? 0
                return (result, postSyncNotesCount, checkpoint.shouldMarkUploadedLocalAfterSuccess)
            }.value
            HardDeleteQueueStore.dequeue(noteIDs: hardDeletedNoteIdsSnapshot, for: currentUserId)
            HardDeleteQueueStore.dequeue(tagIDs: hardDeletedTagIdsSnapshot, for: currentUserId)
            WelcomeNoteFlagStore.setHasSeenWelcome(UserDefaults.standard.bool(forKey: "hasSeededWelcomeNote"), for: currentUserId)

            // Use local time anchor to avoid device/server clock skew skipping local updates.
            lastSyncAtTimestamp = syncStartedAt.timeIntervalSince1970
            if let serverTime = syncOutcome.0.serverTime {
                let skewSeconds = serverTime.timeIntervalSince(syncStartedAt)
                if skewSeconds > 60 {
                    print("⚠️ SyncManager detected server clock ahead by \(Int(skewSeconds))s; using local sync time as incremental anchor.")
                }
            }
            if let cursor = syncOutcome.0.cursor, !cursor.isEmpty {
                syncCursor = cursor
            }
            self.hasUploadedLocal = syncOutcome.2 ? true : (syncOutcome.1 > 0)

            if FeatureFlags.useLocalFTSSearch {
                let hardDeletedNoteUUIDs = syncOutcome.0.remoteHardDeletedNoteIds.compactMap(UUID.init(uuidString:))
                if !hardDeletedNoteUUIDs.isEmpty {
                    await NotesSearchIndexer.shared.remove(noteIDs: hardDeletedNoteUUIDs)
                }
                await NotesSearchIndexer.shared.syncIncremental(context: context, userId: currentUserId)
            }
            didSucceed = true
        } catch {
            if case SyncError.unauthorized = error {
                // Supabase SDK handles session refresh under the hood, but if we get a 401 here,
                // it likely means the Refresh Token is also invalid/expired.
                // We should prompt user to sign in again.
                await AuthService.shared.checkSession() // Try one last check
                if !AuthService.shared.isSignedIn {
                    lastError = AppErrorCode.syncSessionExpired.message
                } else {
                     // If checkSession says we are signed in, maybe just a temporary glitch
                    lastError = AppErrorCode.syncAuthorizationFailed.message
                }
            } else {
                lastError = AppErrorCode.syncFailedWithReason.message(error.localizedDescription)
            }
        }
        isSyncing = false

        if hasPendingSyncRequest {
            hasPendingSyncRequest = false
            await syncNow(context: context)
        }
        return didSucceed
    }
    
    private func shouldSyncNow() -> Bool {
        guard isEnabled, !isSyncing else { return false }
        guard AuthService.shared.confirmedUserId != nil else { return false }
        guard URL(string: serverURLString) != nil else { return false }
        if let lastSyncAt, Date().timeIntervalSince(lastSyncAt) < minimumSyncInterval {
            return false
        }
        return true
    }

    nonisolated static func resolveCheckpoint(
        lastSyncAt: Date?,
        cursor: String,
        hasUploadedLocal: Bool,
        localNotesCount: Int
    ) -> SyncCheckpoint {
        let normalizedCursor = cursor.isEmpty ? nil : cursor

        // If local storage is empty, incremental sync is unsafe because the server
        // will only return recent changes after the saved cursor. Fall back to a
        // full sync so historical notes can be downloaded again after relogin,
        // migration resets, or store recreation.
        if localNotesCount == 0 {
            return SyncCheckpoint(
                since: nil,
                cursor: nil,
                shouldMarkUploadedLocalAfterSuccess: false
            )
        }

        // Existing local notes that were never uploaded should also avoid using an
        // incremental cursor, otherwise remote history may be skipped.
        if !hasUploadedLocal {
            return SyncCheckpoint(
                since: nil,
                cursor: nil,
                shouldMarkUploadedLocalAfterSuccess: true
            )
        }

        return SyncCheckpoint(
            since: lastSyncAt,
            cursor: normalizedCursor,
            shouldMarkUploadedLocalAfterSuccess: true
        )
    }
}
