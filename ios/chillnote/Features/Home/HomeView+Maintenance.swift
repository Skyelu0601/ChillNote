import SwiftUI

extension HomeView {
    enum MaintenanceReason {
        case initial
        case foreground
        case userChanged
    }

    func scheduleMaintenance(reason: MaintenanceReason) {
        Task {
            await runMaintenance(reason: reason)
        }
    }

    @MainActor
    func pollSyncWhileHomeIsVisible() async {
        guard currentUserId != nil,
              scenePhase == .active,
              navigationPath.isEmpty else {
            return
        }

        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: 60_000_000_000)
            } catch {
                return
            }

            guard !Task.isCancelled,
                  currentUserId != nil,
                  scenePhase == .active,
                  navigationPath.isEmpty else {
                return
            }
            await syncManager.syncIfNeeded(context: modelContext)
        }
    }

    @MainActor
    func runMaintenance(reason: MaintenanceReason) async {
        let now = Date()
        // A pending import may have completed on the server while the app was in
        // the background. In that case the local `processing` state is stale, so
        // foregrounding must not be blocked by the general maintenance cooldown.
        let bypassIntervalLimit = reason == .initial
            || reason == .userChanged
            || (reason == .foreground && !pendingLinkImportIDs.isEmpty)
        if !bypassIntervalLimit,
           let lastMaintenanceAt,
           now.timeIntervalSince(lastMaintenanceAt) < minimumMaintenanceInterval {
            return
        }
        lastMaintenanceAt = now
        TrashPolicy.purgeExpiredNotes(context: modelContext)
        if let userId = AuthService.shared.currentUserId {
            TrashPolicy.purgeExpiredTags(context: modelContext, userId: userId)
        }

        switch reason {
        case .initial, .userChanged:
            _ = await syncManager.syncNow(context: modelContext)
        case .foreground:
            if pendingLinkImportIDs.isEmpty {
                await syncManager.syncIfNeeded(context: modelContext)
            } else {
                _ = await syncManager.syncNow(context: modelContext)
            }
        }

        registerCompletedLinkImportsForRating()
        await checkForPendingRecordingsAsync()
    }

    func checkForPendingRecordingsAsync() async {
        if case .recording = speechRecognizer.recordingState { return }
        let activeProcessingPaths = await MainActor.run { speechRecognizer.activeTranscriptionFilePaths }
        let pending = await Task.detached(priority: .userInitiated) {
            RecordingFileManager.shared.pendingRecordings()
        }.value

        await MainActor.run {
            pendingRecordings = pending.filter { !activeProcessingPaths.contains($0.fileURL.path) }
        }
    }
}
