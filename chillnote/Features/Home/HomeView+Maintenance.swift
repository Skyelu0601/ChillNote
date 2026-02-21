import SwiftUI

extension HomeView {
    enum MaintenanceReason {
        case initial
        case foreground
        case userChanged
    }

    func scheduleInitialMaintenance() {
        guard !hasScheduledInitialMaintenance else { return }
        hasScheduledInitialMaintenance = true
        Task {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 150_000_000)
            await runMaintenance(reason: .initial)
        }
    }

    func scheduleMaintenance(reason: MaintenanceReason) {
        Task {
            await runMaintenance(reason: reason)
        }
    }

    @MainActor
    func runMaintenance(reason: MaintenanceReason) async {
        let now = Date()
        let bypassIntervalLimit = reason == .userChanged
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

        Task {
            switch reason {
            case .userChanged:
                await syncManager.syncNow(context: modelContext)
            case .initial, .foreground:
                await syncManager.syncIfNeeded(context: modelContext)
            }
        }

        await checkForPendingRecordingsAsync()
    }

    func checkForPendingRecordingsAsync() async {
        if case .recording = speechRecognizer.recordingState { return }
        let pending = await Task.detached(priority: .userInitiated) {
            RecordingFileManager.shared.pendingRecordings()
        }.value

        await MainActor.run {
            pendingRecordings = pending
        }
    }
}
