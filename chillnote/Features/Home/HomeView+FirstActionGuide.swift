import Foundation

extension HomeView {
    @MainActor
    func configureFirstActionGuide() {
        guard let userId = currentUserId else { return }
        firstActionGuide.configure(
            userId: userId,
            accountCreatedAt: authService.currentUser?.createdAt
        )
    }

    @MainActor
    func reconcileFirstActionGuideImport() {
        guard firstActionGuide.stage == .waitingForImport,
              let noteID = firstActionGuide.targetNoteID,
              let note = resolveNote(noteID) else {
            return
        }

        firstActionGuide.updateTargetImportStatus(note.importStatus)

        guard firstActionGuide.stage == .openImportedNote else { return }
        isTrashSelected = false
        selectedTag = nil
        selectedSection = note.section
    }
}
