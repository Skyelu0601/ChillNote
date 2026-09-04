import Foundation

extension HomeView {
    @MainActor
    func importPendingSharedNotes(navigateToLatest: Bool) {
        guard let currentUserId else { return }

        let pendingFiles: [SharedImportQueue.PendingImportFile]
        do {
            pendingFiles = try SharedImportQueue.pendingImports().filter {
                $0.importItem.belongs(to: currentUserId)
            }
        } catch {
            presentSharedImportQueueError(error)
            return
        }
        guard !pendingFiles.isEmpty else { return }

        var didImport = false
        for pendingFile in pendingFiles {
            let shouldNavigate = navigateToLatest && pendingFile.fileURL == pendingFiles.last?.fileURL

            switch pendingFile.importItem.importKind {
            case .note:
                guard let noteText = pendingFile.importItem.noteText,
                      saveNote(
                        text: noteText,
                        source: pendingFile.importItem.noteSourceMetadata,
                        shouldNavigate: shouldNavigate
                      ) != nil else {
                    continue
                }

                didImport = true
                removePendingSharedImport(pendingFile)

            case .linkImport:
                guard let url = URL(string: pendingFile.importItem.source.url),
                      let importedNote = createLinkImportNote(
                        url,
                        noteID: pendingFile.importItem.id,
                        source: pendingFile.importItem.noteSourceMetadata,
                        existingJobId: pendingFile.importItem.importJobId,
                        existingJobStatus: pendingFile.importItem.importStatus,
                        shouldNavigate: shouldNavigate && !firstActionGuide.isWaitingForSharedVideo
                      ) else {
                    removePendingSharedImport(pendingFile)
                    continue
                }

                firstActionGuide.registerSharedVideoImport(noteID: importedNote.id)
                Task {
                    await StoreService.shared.fetchCreditBalance()
                }
                didImport = true
                removePendingSharedImport(pendingFile)
            }
        }

        guard didImport else { return }
        requestReload(keepItemsWhileLoading: true)
        reconcileFirstActionGuideImport()
    }

    @MainActor
    private func removePendingSharedImport(_ file: SharedImportQueue.PendingImportFile) {
        do {
            try SharedImportQueue.remove(file)
        } catch {
            presentSharedImportQueueError(error)
        }
    }

    @MainActor
    private func presentSharedImportQueueError(_ error: Error) {
        PerformanceTelemetry.mark("shared_imports.queue_failed", detail: error.localizedDescription)
        clipboardLinkImportErrorMessage = L10n.text("quick_capture.error.shared_import_queue")
        showClipboardLinkImportErrorAlert = true
    }
}
