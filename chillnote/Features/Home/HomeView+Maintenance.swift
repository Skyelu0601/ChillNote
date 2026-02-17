import SwiftUI

extension HomeView {
    enum MaintenanceReason {
        case initial
        case foreground
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
        if let lastMaintenanceAt, now.timeIntervalSince(lastMaintenanceAt) < minimumMaintenanceInterval {
            return
        }
        lastMaintenanceAt = now
        TrashPolicy.purgeExpiredNotes(context: modelContext)

        Task {
            await syncManager.syncIfNeeded(context: modelContext)
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
