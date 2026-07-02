import SwiftData
import SwiftUI

extension HomeView {
    func scheduleAppRatingPrompt() {
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                showAppRatingPrompt = true
            }
        }
    }

    func registerCompletedLinkImportsForRating() {
        guard let userId = currentUserId else { return }

        let completedStatus = NoteImportStatus.completed.rawValue
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate<Note> { note in
                note.userId == userId
                && note.deletedAt == nil
                && note.sourceURL != nil
                && note.importStatusRaw == completedStatus
            }
        )

        guard let notes = try? modelContext.fetch(descriptor) else { return }

        for note in notes where isRateableCompletedLinkImport(note) {
            if AppRatingService.shared.registerSuccessfulLinkImportCompletion(noteID: note.id) {
                scheduleAppRatingPrompt()
                break
            }
        }
    }

    private func isRateableCompletedLinkImport(_ note: Note) -> Bool {
        let trimmedContent = note.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return note.importStatus == .completed
            && note.importJobId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && !trimmedContent.isEmpty
    }
}
