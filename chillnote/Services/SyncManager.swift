import Foundation
import SwiftData
import SwiftUI

@MainActor
final class SyncManager: ObservableObject {
    @AppStorage("syncEnabled") var isEnabled: Bool = true
    @AppStorage("syncLastAt") private var lastSyncAtTimestamp: Double = 0
    @AppStorage("syncCursor") private var syncCursor: String = ""
    @AppStorage("syncDeviceId") private var syncDeviceId: String = ""
    @AppStorage("syncServerURL") var serverURLString: String = AppConfig.backendBaseURL
    @AppStorage("syncAuthToken") var authToken: String = ""
    @AppStorage("syncHasUploadedLocal") private var hasUploadedLocal: Bool = false
    
    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var lastError: String?
    
    private let minimumSyncInterval: TimeInterval = 60

    init() {
        if !isEnabled {
            isEnabled = true
        }
        // Server URL is not user-configurable; it comes from AppConfig.
        serverURLString = AppConfig.backendBaseURL
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
        await syncNow(context: context)
    }
    
    func syncNow(context: ModelContext) async {
        guard isEnabled else {
            lastError = "Sync is disabled."
            return
        }
        guard !authToken.isEmpty else {
            lastError = "Sign in required to sync."
            return
        }
        guard let url = URL(string: serverURLString), !serverURLString.isEmpty else {
            lastError = "Server URL is required."
            return
        }
        guard let currentUserId = AuthService.shared.currentUserId else {
            lastError = "Sign in required to sync."
            return
        }
        guard let container = DataService.shared.container else {
            lastError = "Sync unavailable."
            return
        }
        WelcomeNoteFlagStore.syncGlobalFlag(for: currentUserId)
        let syncStartedAt = Date()
        var needsFollowUpSync = false
        isSyncing = true
        lastError = nil
        do {
            let lastSyncAt = lastSyncAt
            let hasUploadedLocalSnapshot = hasUploadedLocal
            let authToken = authToken
            let cursorSnapshot = syncCursor
            let deviceIdSnapshot = syncDeviceId
            let syncOutcome = try await Task.detached(priority: .utility) {
                let backgroundContext = ModelContext(container)
                let localNotesCount = (try? backgroundContext.fetchCount(FetchDescriptor<Note>())) ?? 0
                let shouldForceFullSync = !hasUploadedLocalSnapshot && localNotesCount > 0
                let sinceDate = shouldForceFullSync ? nil : lastSyncAt
                let cursorValue = shouldForceFullSync ? nil : (cursorSnapshot.isEmpty ? nil : cursorSnapshot)
                let config = SyncConfig(baseURL: url, authToken: authToken, since: sinceDate, cursor: cursorValue, userId: currentUserId, deviceId: deviceIdSnapshot)
                let service: SyncService = RemoteSyncService(config: config)
                let result = try await service.syncAll(context: backgroundContext)
                TagService.shared.cleanupEmptyTags(context: backgroundContext)
                let postSyncNotesCount = (try? backgroundContext.fetchCount(FetchDescriptor<Note>())) ?? 0
                return (result, postSyncNotesCount)
            }.value
            WelcomeNoteFlagStore.setHasSeenWelcome(UserDefaults.standard.bool(forKey: "hasSeededWelcomeNote"), for: currentUserId)
            
            let seededWelcome = DataService.shared.seedDataIfNeeded(context: context, userId: currentUserId)
            
            if seededWelcome {
                self.hasUploadedLocal = false
                lastSyncAtTimestamp = 0
                syncCursor = ""
                needsFollowUpSync = true
            } else {
                if let serverTime = syncOutcome.0.serverTime {
                    lastSyncAtTimestamp = serverTime.timeIntervalSince1970
                } else {
                    lastSyncAtTimestamp = syncStartedAt.timeIntervalSince1970
                }
                if let cursor = syncOutcome.0.cursor, !cursor.isEmpty {
                    syncCursor = cursor
                }
                self.hasUploadedLocal = syncOutcome.1 > 0
            }

            if FeatureFlags.useLocalFTSSearch {
                await NotesSearchIndexer.shared.syncIncremental(context: context, userId: currentUserId)
            }
        } catch {
            if case SyncError.unauthorized = error {
                // Supabase SDK handles session refresh under the hood, but if we get a 401 here,
                // it likely means the Refresh Token is also invalid/expired.
                // We should prompt user to sign in again.
                await AuthService.shared.checkSession() // Try one last check
                if !AuthService.shared.isSignedIn {
                    lastError = "Session expired. Please sign in again."
                } else {
                     // If checkSession says we are signed in, maybe just a temporary glitch
                    lastError = "Sync authorization failed."
                }
            } else {
                lastError = "Sync failed: \(error.localizedDescription)"
            }
        }
        isSyncing = false
        
        if needsFollowUpSync {
            await syncIfNeeded(context: context)
        }
    }
    
    private func shouldSyncNow() -> Bool {
        guard isEnabled, !isSyncing else { return false }
        guard !authToken.isEmpty else { return false }
        guard !serverURLString.isEmpty else { return false }
        if let lastSyncAt, Date().timeIntervalSince(lastSyncAt) < minimumSyncInterval {
            return false
        }
        return true
    }
}
