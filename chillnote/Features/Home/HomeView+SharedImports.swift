import Foundation

extension HomeView {
    @MainActor
    func importPendingSharedNotes(navigateToLatest: Bool) {
        guard currentUserId != nil else { return }

        let pendingFiles = SharedImportQueue.pendingImports()
        guard !pendingFiles.isEmpty else { return }

        var importedNote: Note?
        for pendingFile in pendingFiles {
            let shouldNavigate = navigateToLatest && pendingFile.fileURL == pendingFiles.last?.fileURL
            guard let note = saveNote(
                text: pendingFile.importItem.noteText,
                source: pendingFile.importItem.noteSourceMetadata,
                shouldNavigate: shouldNavigate
            ) else {
                continue
            }

            importedNote = note
            SharedImportQueue.remove(pendingFile)
        }

        guard importedNote != nil else { return }
        requestReload(keepItemsWhileLoading: true)
    }
}
