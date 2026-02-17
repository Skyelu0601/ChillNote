import Foundation
import UIKit

@MainActor
final class ExportViewModel: ObservableObject {
    @Published private(set) var estimatedNoteCount: Int?
    @Published private(set) var isLoadingEstimate = false
    @Published private(set) var isExporting = false
    @Published private(set) var progress: ExportProgress = .empty
    @Published var showErrorAlert = false
    @Published var errorMessage = ""
    @Published var exportURL: URL?
    @Published var showShareSheet = false
    @Published var successMessage: String?

    private let exportService: NotesExporting
    private var exportTask: Task<Void, Never>?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    init(exportService: NotesExporting = NotesExportService.shared) {
        self.exportService = exportService
    }

    func prepareIfNeeded(userId: String?) {
        guard estimatedNoteCount == nil, !isLoadingEstimate else { return }
        Task { await refreshEstimate(userId: userId) }
    }

    func refreshEstimate(userId: String?) async {
        guard let userId, !userId.isEmpty else {
            estimatedNoteCount = nil
            return
        }

        isLoadingEstimate = true
        defer { isLoadingEstimate = false }

        do {
            let count = try await exportService.countMarkdownNotes(
                request: ExportRequest(userId: userId, includeDeleted: false, batchSize: 200)
            )
            estimatedNoteCount = count
        } catch {
            estimatedNoteCount = nil
        }
    }

    func startExport(userId: String?) {
        guard !isExporting else { return }
        guard let userId, !userId.isEmpty else {
            showError(message: "Sign in required to export.")
            return
        }

        isExporting = true
        progress = ExportProgress(
            stage: .preparing,
            processed: 0,
            total: estimatedNoteCount ?? 0,
            elapsed: 0,
            message: "Preparing export..."
        )
        successMessage = nil
        showErrorAlert = false
        errorMessage = ""
        if let staleURL = exportURL {
            Task { [exportService] in
                await exportService.cleanupExportArtifact(at: staleURL)
            }
            exportURL = nil
        }

        beginBackgroundTask()

        // Analytics removed


        exportTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            await self.runExport(userId: userId)
        }
    }

    func cancelExport() {
        guard isExporting else { return }
        exportTask?.cancel()
        // Analytics removed

    }

    func resetEstimate() {
        estimatedNoteCount = nil
    }

    func handleShareDismissed() {
        showShareSheet = false
        if let exportURL {
            Task { [exportService] in
                await exportService.cleanupExportArtifact(at: exportURL)
            }
        }
        exportURL = nil
    }

    private func runExport(userId: String) async {
        let startedAt = Date()
        do {
            let request = ExportRequest(userId: userId, includeDeleted: false, batchSize: 200)
            let url = try await exportService.exportAllMarkdown(request: request) { [weak self] update in
                Task { @MainActor [weak self] in
                    self?.progress = update
                }
            }
            let fileSize = fileSizeFor(url: url)
            let duration = Date().timeIntervalSince(startedAt)

            progress = ExportProgress(
                stage: .finishing,
                processed: max(progress.processed, estimatedNoteCount ?? progress.processed),
                total: max(progress.total, estimatedNoteCount ?? progress.total),
                elapsed: duration,
                message: "Export complete"
            )
            successMessage = "\(estimatedNoteCount ?? progress.processed) notes • \(formatByteCount(fileSize))"
            exportURL = url
            showShareSheet = true
            scheduleDeferredCleanup(for: url)

            // Analytics removed

        } catch {
            if isCancellation(error) {
                successMessage = "Export cancelled"
            } else {
                let message = readableMessage(for: error)
                showError(message: message)
                // Analytics removed

            }
        }

        isExporting = false
        endBackgroundTaskIfNeeded()
        exportTask = nil
    }

    private func showError(message: String) {
        errorMessage = message
        showErrorAlert = true
    }

    private func readableMessage(for error: Error) -> String {
        if let exportError = error as? ExportError {
            return exportError.errorDescription ?? "Unable to export notes. Please try again."
        }
        return "Unable to export notes. Please try again."
    }

    private func errorCode(for error: Error) -> String {
        if let exportError = error as? ExportError {
            switch exportError {
            case .missingContainer: return "missing_container"
            case .noNotes: return "no_notes"
            case .insufficientStorage: return "insufficient_storage"
            case .cancelled: return "cancelled"
            case .invalidArchive: return "invalid_archive"
            case .writeFailed: return "write_failed"
            case .zipFailed: return "zip_failed"
            case .unknown: return "unknown"
            }
        }
        return "unknown"
    }

    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }
        if case ExportError.cancelled = error {
            return true
        }
        return false
    }

    private func fileSizeFor(url: URL) -> Int64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let value = attributes[.size] as? NSNumber else {
            return 0
        }
        return value.int64Value
    }

    private func formatByteCount(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func beginBackgroundTask() {
        guard backgroundTaskID == .invalid else { return }
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "export-all-notes") { [weak self] in
            Task { @MainActor [weak self] in
                self?.exportTask?.cancel()
                self?.endBackgroundTaskIfNeeded()
            }
        }
    }

    private func endBackgroundTaskIfNeeded() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }

    private func scheduleDeferredCleanup(for url: URL) {
        Task { [weak self, exportService] in
            try? await Task.sleep(nanoseconds: 600_000_000_000)
            guard let self else { return }
            let shouldCleanup = await MainActor.run { () -> Bool in
                guard self.exportURL == url, !self.showShareSheet else { return false }
                self.exportURL = nil
                return true
            }
            guard shouldCleanup else { return }
            await exportService.cleanupExportArtifact(at: url)
        }
    }
}
