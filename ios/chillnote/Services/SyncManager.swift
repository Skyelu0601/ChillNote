import Foundation
import OSLog
import SwiftData
import SwiftUI

struct UserSyncCheckpointState: Equatable {
    var lastSyncAtTimestamp: Double = 0
    var cursor: String = ""
    var hasUploadedLocal = false
    var hasCompletedBootstrap = false
    var lastKnownLocalEntityCount: Int?

    var lastSyncAt: Date? {
        guard lastSyncAtTimestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: lastSyncAtTimestamp)
    }
}

enum UserSyncCheckpointStore {
    private static let lastSyncAtByUserKey = "syncLastAtByUser"
    private static let cursorByUserKey = "syncCursorByUser"
    private static let uploadedLocalByUserKey = "syncHasUploadedLocalByUser"
    private static let completedBootstrapByUserKey = "syncCompletedBootstrapByUser"
    private static let localEntityCountByUserKey = "syncLocalEntityCountByUser"
    private static let legacyMigrationVersionKey = "syncCheckpointLegacyMigrationVersion"
    private static let lastAuthenticatedUserIdKey = "auth.lastAuthenticatedUserId"
    private static let currentMigrationVersion = 1

    static func state(
        for userId: String,
        defaults: UserDefaults = .standard
    ) -> UserSyncCheckpointState {
        migrateLegacyCheckpointIfNeeded(for: userId, defaults: defaults)

        let lastSyncAtByUser = defaults.dictionary(forKey: lastSyncAtByUserKey) as? [String: Double] ?? [:]
        let cursorByUser = defaults.dictionary(forKey: cursorByUserKey) as? [String: String] ?? [:]
        let uploadedLocalByUser = defaults.dictionary(forKey: uploadedLocalByUserKey) as? [String: Bool] ?? [:]
        let completedBootstrapByUser = defaults.dictionary(forKey: completedBootstrapByUserKey) as? [String: Bool] ?? [:]
        let localEntityCountByUser = defaults.dictionary(forKey: localEntityCountByUserKey) as? [String: Int] ?? [:]

        return UserSyncCheckpointState(
            lastSyncAtTimestamp: lastSyncAtByUser[userId] ?? 0,
            cursor: cursorByUser[userId] ?? "",
            hasUploadedLocal: uploadedLocalByUser[userId] ?? false,
            hasCompletedBootstrap: completedBootstrapByUser[userId] ?? false,
            lastKnownLocalEntityCount: localEntityCountByUser[userId]
        )
    }

    static func save(
        _ state: UserSyncCheckpointState,
        for userId: String,
        defaults: UserDefaults = .standard
    ) {
        var lastSyncAtByUser = defaults.dictionary(forKey: lastSyncAtByUserKey) as? [String: Double] ?? [:]
        var cursorByUser = defaults.dictionary(forKey: cursorByUserKey) as? [String: String] ?? [:]
        var uploadedLocalByUser = defaults.dictionary(forKey: uploadedLocalByUserKey) as? [String: Bool] ?? [:]
        var completedBootstrapByUser = defaults.dictionary(forKey: completedBootstrapByUserKey) as? [String: Bool] ?? [:]
        var localEntityCountByUser = defaults.dictionary(forKey: localEntityCountByUserKey) as? [String: Int] ?? [:]

        lastSyncAtByUser[userId] = state.lastSyncAtTimestamp
        cursorByUser[userId] = state.cursor
        uploadedLocalByUser[userId] = state.hasUploadedLocal
        completedBootstrapByUser[userId] = state.hasCompletedBootstrap
        if let entityCount = state.lastKnownLocalEntityCount {
            localEntityCountByUser[userId] = entityCount
        } else {
            localEntityCountByUser.removeValue(forKey: userId)
        }

        defaults.set(lastSyncAtByUser, forKey: lastSyncAtByUserKey)
        defaults.set(cursorByUser, forKey: cursorByUserKey)
        defaults.set(uploadedLocalByUser, forKey: uploadedLocalByUserKey)
        defaults.set(completedBootstrapByUser, forKey: completedBootstrapByUserKey)
        defaults.set(localEntityCountByUser, forKey: localEntityCountByUserKey)
    }

    private static func migrateLegacyCheckpointIfNeeded(
        for userId: String,
        defaults: UserDefaults
    ) {
        guard defaults.integer(forKey: legacyMigrationVersionKey) < currentMigrationVersion else {
            return
        }
        defer {
            defaults.set(currentMigrationVersion, forKey: legacyMigrationVersionKey)
        }

        // The former checkpoint was global. Only associate it with the account
        // that was last authenticated when this migration first runs; copying it
        // to any other account could make that account skip remote history.
        let completedUserIDs = Set(defaults.stringArray(forKey: "syncCompletedUserIDs") ?? [])
        guard defaults.string(forKey: lastAuthenticatedUserIdKey) == userId,
              completedUserIDs.count == 1,
              completedUserIDs.contains(userId) else {
            return
        }

        let timestamp = defaults.double(forKey: "syncLastAt")
        let cursor = defaults.string(forKey: "syncCursor") ?? ""
        let hasUploadedLocal = defaults.bool(forKey: "syncHasUploadedLocal")
        let hasLegacyCheckpoint = timestamp > 0 || !cursor.isEmpty || hasUploadedLocal || completedUserIDs.contains(userId)
        guard hasLegacyCheckpoint else { return }

        save(
            UserSyncCheckpointState(
                lastSyncAtTimestamp: timestamp,
                cursor: cursor,
                hasUploadedLocal: hasUploadedLocal,
                hasCompletedBootstrap: completedUserIDs.contains(userId) || timestamp > 0 || !cursor.isEmpty,
                lastKnownLocalEntityCount: nil
            ),
            for: userId,
            defaults: defaults
        )
    }
}

@MainActor
final class SyncManager: ObservableObject {
    nonisolated private static let logger = Logger(subsystem: "com.chillnote.app", category: "sync-manager")

    @AppStorage("syncEnabled") var isEnabled: Bool = true
    @AppStorage("syncDeviceId") private var syncDeviceId: String = ""
    private let serverURLString: String = AppConfig.backendBaseURL
    
    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var lastError: String?
    private var hasPendingSyncRequest: Bool = false
    
    private let minimumSyncInterval: TimeInterval = 60
    private let completedSyncUserIDsKey = "syncCompletedUserIDs"

    struct SyncCheckpoint: Equatable {
        let since: Date?
        let cursor: String?
        let shouldMarkUploadedLocalAfterSuccess: Bool
        let shouldMarkBootstrapCompletedAfterSuccess: Bool
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
        guard let userId = AuthService.shared.confirmedUserId else { return nil }
        return UserSyncCheckpointStore.state(for: userId).lastSyncAt
    }

    func hasCompletedSync(for userId: String) -> Bool {
        Set(UserDefaults.standard.stringArray(forKey: completedSyncUserIDsKey) ?? [])
            .contains(userId)
    }
    
    func syncIfNeeded(context: ModelContext) async {
        guard shouldSyncNow() else { return }
        _ = await syncNow(context: context)
    }
    
    @discardableResult
    func syncNow(context: ModelContext) async -> Bool {
        if isSyncing {
            hasPendingSyncRequest = true
            Self.logger.debug("syncNow queued because another sync is already running")
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
        guard AuthService.shared.confirmedUserId != nil else {
            lastError = AppErrorCode.syncSignInRequired.message
            return false
        }
        guard let authSnapshot = await AuthService.shared.syncSessionSnapshot() else {
            lastError = AppErrorCode.syncSessionExpired.message
            return false
        }
        guard let container = DataService.shared.container else {
            lastError = AppErrorCode.syncUnavailable.message
            return false
        }
        guard AuthService.shared.isCurrentSyncSession(authSnapshot) else {
            return false
        }
        let currentUserId = authSnapshot.userId
        WelcomeNoteFlagStore.syncGlobalFlag(for: currentUserId)
        let syncStartedAt = Date()
        isSyncing = true
        lastError = nil
        var didSucceed = false
        do {
            let persistedState = UserSyncCheckpointStore.state(for: currentUserId)
            let lastSyncAt = persistedState.lastSyncAt
            let hasUploadedLocalSnapshot = persistedState.hasUploadedLocal
            let hasCompletedBootstrapSnapshot = persistedState.hasCompletedBootstrap
            let lastKnownLocalEntityCountSnapshot = persistedState.lastKnownLocalEntityCount
            let cursorSnapshot = persistedState.cursor
            let deviceIdSnapshot = syncDeviceId
            let userIdForSync = currentUserId
            let tokenForSync = authSnapshot.token
            let hardDeletedNoteIdsSnapshot = HardDeleteQueueStore.noteIDs(for: userIdForSync)
            let hardDeletedTagIdsSnapshot = HardDeleteQueueStore.tagIDs(for: userIdForSync)
            let sinceText = lastSyncAt?.description ?? "nil"
            let cursorText = cursorSnapshot.isEmpty ? "nil" : cursorSnapshot
            Self.logger.debug("syncNow user=\(userIdForSync, privacy: .private) since=\(sinceText, privacy: .public) cursor=\(cursorText, privacy: .private) hardDeletedNotes=\(hardDeletedNoteIdsSnapshot.count, privacy: .public) hardDeletedTags=\(hardDeletedTagIdsSnapshot.count, privacy: .public)")
            guard AuthService.shared.isCurrentSyncSession(authSnapshot) else {
                throw SyncError.authSessionChanged
            }
            let syncOutcome = try await Task.detached(priority: .utility) {
                guard await AuthService.shared.isCurrentSyncSession(authSnapshot) else {
                    throw SyncError.authSessionChanged
                }
                let backgroundContext = ModelContext(container)
                var userNotesDescriptor = FetchDescriptor<Note>()
                userNotesDescriptor.predicate = #Predicate<Note> { note in
                    note.userId == userIdForSync
                }
                let localNotesCount: Int
                do {
                    localNotesCount = try backgroundContext.fetchCount(userNotesDescriptor)
                } catch {
                    Self.logger.error("Failed to count local notes before sync: \(error.localizedDescription, privacy: .public)")
                    throw SyncError.localStoreUnavailable
                }
                var userTagsDescriptor = FetchDescriptor<Tag>()
                userTagsDescriptor.predicate = #Predicate<Tag> { tag in
                    tag.userId == userIdForSync
                }
                let localTagsCount: Int
                do {
                    localTagsCount = try backgroundContext.fetchCount(userTagsDescriptor)
                } catch {
                    Self.logger.error("Failed to count local tags before sync: \(error.localizedDescription, privacy: .public)")
                    throw SyncError.localStoreUnavailable
                }
                let localEntityCount = localNotesCount + localTagsCount
                let checkpoint = Self.resolveCheckpoint(
                    lastSyncAt: lastSyncAt,
                    cursor: cursorSnapshot,
                    hasUploadedLocal: hasUploadedLocalSnapshot,
                    hasCompletedBootstrap: hasCompletedBootstrapSnapshot,
                    lastKnownLocalEntityCount: lastKnownLocalEntityCountSnapshot,
                    localEntityCount: localEntityCount
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
                    hardDeletedTagIds: hardDeletedTagIdsSnapshot,
                    isSessionCurrent: {
                        await AuthService.shared.isCurrentSyncSession(authSnapshot)
                    }
                )
                let service: SyncService = RemoteSyncService(config: config)
                let result = try await service.syncAll(context: backgroundContext)
                guard await AuthService.shared.isCurrentSyncSession(authSnapshot) else {
                    throw SyncError.authSessionChanged
                }
                let postSyncContext = ModelContext(container)
                TagService.shared.cleanupEmptyTags(
                    context: postSyncContext,
                    userId: userIdForSync,
                    shouldSave: false
                )
                try postSyncContext.save()
                let postSyncNotesCount: Int
                do {
                    postSyncNotesCount = try postSyncContext.fetchCount(userNotesDescriptor)
                } catch {
                    Self.logger.error("Failed to count local notes after sync: \(error.localizedDescription, privacy: .public)")
                    throw SyncError.localStoreUnavailable
                }
                let postSyncTagsCount: Int
                do {
                    postSyncTagsCount = try postSyncContext.fetchCount(userTagsDescriptor)
                } catch {
                    Self.logger.error("Failed to count local tags after sync: \(error.localizedDescription, privacy: .public)")
                    throw SyncError.localStoreUnavailable
                }
                return (
                    result,
                    postSyncNotesCount + postSyncTagsCount,
                    checkpoint.shouldMarkUploadedLocalAfterSuccess,
                    checkpoint.shouldMarkBootstrapCompletedAfterSuccess
                )
            }.value
            guard AuthService.shared.isCurrentSyncSession(authSnapshot) else {
                throw SyncError.authSessionChanged
            }
            HardDeleteQueueStore.dequeue(noteIDs: hardDeletedNoteIdsSnapshot, for: currentUserId)
            HardDeleteQueueStore.dequeue(tagIDs: hardDeletedTagIdsSnapshot, for: currentUserId)
            WelcomeNoteFlagStore.setHasSeenWelcome(UserDefaults.standard.bool(forKey: "hasSeededWelcomeNote"), for: currentUserId)

            // Use local time anchor to avoid device/server clock skew skipping local updates.
            var nextPersistedState = persistedState
            nextPersistedState.lastSyncAtTimestamp = syncStartedAt.timeIntervalSince1970
            if let serverTime = syncOutcome.0.serverTime {
                let skewSeconds = serverTime.timeIntervalSince(syncStartedAt)
                if skewSeconds > 60 {
                    Self.logger.warning("Server clock is ahead by \(Int(skewSeconds), privacy: .public)s; using local sync time as incremental anchor")
                }
            }
            if let cursor = syncOutcome.0.cursor, !cursor.isEmpty {
                nextPersistedState.cursor = cursor
            }
            if syncOutcome.2 || syncOutcome.1 > 0 {
                nextPersistedState.hasUploadedLocal = true
            }
            if syncOutcome.3 {
                nextPersistedState.hasCompletedBootstrap = true
            }
            nextPersistedState.lastKnownLocalEntityCount = syncOutcome.1
            UserSyncCheckpointStore.save(nextPersistedState, for: currentUserId)

            if FeatureFlags.useLocalFTSSearch {
                let hardDeletedNoteUUIDs = syncOutcome.0.remoteHardDeletedNoteIds.compactMap(UUID.init(uuidString:))
                if !hardDeletedNoteUUIDs.isEmpty {
                    await NotesSearchIndexer.shared.remove(noteIDs: hardDeletedNoteUUIDs)
                }
                await NotesSearchIndexer.shared.syncIncremental(context: context, userId: currentUserId)
            }
            markSyncCompleted(for: currentUserId)
            didSucceed = true
        } catch {
            if case SyncError.authSessionChanged = error {
                // An account transition intentionally cancels this run. No
                // queue/checkpoint is advanced; the active account can sync on
                // its next normal trigger.
                lastError = nil
            } else if case SyncError.unauthorized = error {
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

    private func markSyncCompleted(for userId: String) {
        var completedUserIDs = Set(
            UserDefaults.standard.stringArray(forKey: completedSyncUserIDsKey) ?? []
        )
        completedUserIDs.insert(userId)
        UserDefaults.standard.set(Array(completedUserIDs), forKey: completedSyncUserIDsKey)
    }

    nonisolated static func resolveCheckpoint(
        lastSyncAt: Date?,
        cursor: String,
        hasUploadedLocal: Bool,
        hasCompletedBootstrap: Bool,
        lastKnownLocalEntityCount: Int?,
        localEntityCount: Int
    ) -> SyncCheckpoint {
        let normalizedCursor = cursor.isEmpty ? nil : cursor

        // Bootstrap once per account. A successful empty bootstrap is still a
        // complete snapshot and must retain its cursor instead of full-syncing on
        // every foreground transition.
        if !hasCompletedBootstrap {
            return SyncCheckpoint(
                since: nil,
                cursor: nil,
                shouldMarkUploadedLocalAfterSuccess: true,
                shouldMarkBootstrapCompletedAfterSuccess: true
            )
        }

        // Existing local notes that were never uploaded should also avoid using an
        // incremental cursor, otherwise remote history may be skipped.
        if !hasUploadedLocal {
            return SyncCheckpoint(
                since: nil,
                cursor: nil,
                shouldMarkUploadedLocalAfterSuccess: true,
                shouldMarkBootstrapCompletedAfterSuccess: true
            )
        }

        // If a previously populated account suddenly has no local notes or tags,
        // assume the local store was rebuilt and replay the complete remote state.
        // A genuinely empty account records zero after its first successful sync,
        // so it continues incrementally on later foreground transitions.
        if localEntityCount == 0, let lastKnownLocalEntityCount, lastKnownLocalEntityCount > 0 {
            return SyncCheckpoint(
                since: nil,
                cursor: nil,
                shouldMarkUploadedLocalAfterSuccess: true,
                shouldMarkBootstrapCompletedAfterSuccess: true
            )
        }

        return SyncCheckpoint(
            since: lastSyncAt,
            cursor: normalizedCursor,
            shouldMarkUploadedLocalAfterSuccess: localEntityCount > 0,
            shouldMarkBootstrapCompletedAfterSuccess: false
        )
    }
}
