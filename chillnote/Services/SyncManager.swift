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
        let syncStartedAt = Date()
        isSyncing = true
        lastError = nil
        let localNotesCount = (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
        let shouldForceFullSync = !hasUploadedLocal && localNotesCount > 0
        let sinceDate = shouldForceFullSync ? nil : lastSyncAt
        do {
            let config = SyncConfig(baseURL: url, authToken: authToken, since: sinceDate)
            let service: SyncService = RemoteSyncService(config: config)
            try await service.syncAll(context: context)
            TagService.shared.cleanupEmptyTags(context: context)
            lastSyncAtTimestamp = syncStartedAt.timeIntervalSince1970
            if localNotesCount > 0 {
                hasUploadedLocal = true
            }
        } catch {
            if case SyncError.unauthorized = error {
                let refreshed = await AuthService.shared.refreshAccessToken()
                if refreshed {
                    do {
                        let refreshedToken = UserDefaults.standard.string(forKey: "syncAuthToken") ?? authToken
                        let retryConfig = SyncConfig(baseURL: url, authToken: refreshedToken, since: sinceDate)
                        let retryService: SyncService = RemoteSyncService(config: retryConfig)
                        try await retryService.syncAll(context: context)
                        TagService.shared.cleanupEmptyTags(context: context)
                        lastSyncAtTimestamp = syncStartedAt.timeIntervalSince1970
                        if localNotesCount > 0 {
                            hasUploadedLocal = true
                        }
                    } catch {
                        lastError = "Sync failed. Please try again."
                    }
                } else {
                    lastError = "Session expired. Please sign in again."
                }
            } else {
                lastError = "Sync failed. Please try again."
            }
        }
        isSyncing = false
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
