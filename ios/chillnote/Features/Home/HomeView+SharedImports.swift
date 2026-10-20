import Foundation

extension HomeView {
    @MainActor
    func importPendingSharedNotes() {
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
            switch pendingFile.importItem.importKind {
            case .note:
                guard let noteText = pendingFile.importItem.noteText,
                      saveNote(
                        text: noteText,
                        source: pendingFile.importItem.noteSourceMetadata,
                        shouldNavigate: false
                      ) != nil else {
                    continue
                }

                didImport = true
                removePendingSharedImport(pendingFile)

            case .linkImport:
                let item = pendingFile.importItem
                let importedNote: Note
                if item.importJobId?.isEmpty == false {
                    do {
                        importedNote = try SharedImportQueue.adoptStartedLinkImport(item, context: modelContext)
                    } catch {
                        presentSharedImportQueueError(error)
                        continue
                    }
                } else if let url = URL(string: item.source.url),
                          let note = createLinkImportNote(
                        url,
                        noteID: item.id,
                        source: item.noteSourceMetadata,
                        shouldNavigate: false
                      ) {
                    importedNote = note
                } else {
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
        // Returning from the share extension should land on the home feed,
        // including when the app was previously left in a note editor.
        navigationPath = .init()
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
