import Foundation
import SwiftData
import SwiftUI

@MainActor
final class SyncManager: ObservableObject {
    @AppStorage("syncEnabled") var isEnabled: Bool = true
    @AppStorage("syncLastAt") private var lastSyncAtTimestamp: Double = 0
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
            let postSyncNotesCount = try await Task.detached(priority: .utility) {
                let backgroundContext = ModelContext(container)
                let localNotesCount = (try? backgroundContext.fetchCount(FetchDescriptor<Note>())) ?? 0
                let shouldForceFullSync = !hasUploadedLocalSnapshot && localNotesCount > 0
                let sinceDate = shouldForceFullSync ? nil : lastSyncAt
                let config = SyncConfig(baseURL: url, authToken: authToken, since: sinceDate, userId: currentUserId)
                let service: SyncService = RemoteSyncService(config: config)
                try await service.syncAll(context: backgroundContext)
                TagService.shared.cleanupEmptyTags(context: backgroundContext)
                return (try? backgroundContext.fetchCount(FetchDescriptor<Note>())) ?? 0
            }.value
            WelcomeNoteFlagStore.setHasSeenWelcome(UserDefaults.standard.bool(forKey: "hasSeededWelcomeNote"), for: currentUserId)
            
            let seededWelcome = DataService.shared.seedDataIfNeeded(context: context, userId: currentUserId)
            
            if seededWelcome {
                self.hasUploadedLocal = false
                lastSyncAtTimestamp = 0
                needsFollowUpSync = true
            } else {
                lastSyncAtTimestamp = syncStartedAt.timeIntervalSince1970
                self.hasUploadedLocal = postSyncNotesCount > 0
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
