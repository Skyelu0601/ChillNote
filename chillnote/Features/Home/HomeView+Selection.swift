import SwiftUI
import SwiftData

extension HomeView {
    func applyTagToSelected(_ tag: Tag) {
        let notes = getSelectedNotes()
        guard !notes.isEmpty else { return }

        withAnimation {
            let now = Date()
            for note in notes {
                if !note.tags.contains(where: { $0.id == tag.id }) {
                    note.tags.append(tag)
                }
                note.updatedAt = now
            }
            touchTag(tag)
        }

        persistAndSync()
        exitSelectionMode()
    }

    func clampSelectionToCurrentFilter() {
        guard !selectedNotes.isEmpty else { return }
        let validIds = fetchFilteredNotes().map(\.id)
        selectedNotes = selectedNotes.intersection(Set(validIds))
    }

    func fetchFilteredNotes() -> [Note] {
        let userId = currentUserId
        var descriptor = FetchDescriptor<Note>()
        if isTrashSelected {
            descriptor.predicate = #Predicate<Note> { note in
                note.userId == userId && note.deletedAt != nil
            }
        } else {
            descriptor.predicate = #Predicate<Note> { note in
                note.userId == userId && note.deletedAt == nil
            }
        }

        guard let fetched = try? modelContext.fetch(descriptor) else { return [] }

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return fetched.filter { note in
            let passesTag: Bool
            if let selectedTag {
                passesTag = note.tags.contains(where: { $0.id == selectedTag.id })
            } else {
                passesTag = true
            }

            let passesSearch: Bool
            if trimmedQuery.isEmpty {
                passesSearch = true
            } else {
                passesSearch = note.content.localizedCaseInsensitiveContains(trimmedQuery)
                    || note.tags.contains { $0.name.localizedCaseInsensitiveContains(trimmedQuery) }
            }

            return passesTag && passesSearch
        }
    }

    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    func enterSelectionMode() {
        guard !isTrashSelected else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isSelectionMode = true
            selectedNotes.removeAll()
        }
    }

    func exitSelectionMode() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isSelectionMode = false
            selectedNotes.removeAll()
        }
    }

    func toggleNoteSelection(_ note: Note) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedNotes.contains(note.id) {
                selectedNotes.remove(note.id)
            } else {
                selectedNotes.insert(note.id)
            }
        }
    }

    func selectAllNotes() {
        let allIDs = Set(fetchFilteredNotes().map(\.id))
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedNotes = allIDs
        }
    }

    func getSelectedNotes() -> [Note] {
        guard !selectedNotes.isEmpty else { return [] }
        let ids = Array(selectedNotes)
        let userId = currentUserId
        var descriptor = FetchDescriptor<Note>()
        descriptor.predicate = #Predicate<Note> { note in
            note.userId == userId && ids.contains(note.id)
        }
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func startAIChat() {
        guard !selectedNotes.isEmpty else { return }
        let selectedCount = selectedNotes.count
        if selectedCount > askHardLimit {
            showAskHardLimitAlert = true
            return
        }
        if selectedCount > askSoftLimit {
            showAskSoftLimitAlert = true
            return
        }
        cachedContextNotes = getSelectedNotes()
        showAIChat = true
    }

    func deleteNote(_ note: Note) {
        guard note.deletedAt == nil else { return }
        withAnimation {
            note.markDeleted()
        }
        persistAndSync()
        TagService.shared.cleanupEmptyTags(context: modelContext, candidates: Array(note.tags))
    }

    func restoreNote(_ note: Note) {
        guard note.deletedAt != nil else { return }
        let now = Date()
        withAnimation {
            note.deletedAt = nil
            note.updatedAt = now
            for tag in note.tags where tag.deletedAt != nil {
                tag.deletedAt = nil
                tag.updatedAt = now
            }
        }
        persistAndSync()
    }

    func deleteNotePermanently(_ note: Note) {
        let noteId = note.id
        modelContext.delete(note)
        Task { await NotesSearchIndexer.shared.remove(noteIDs: [noteId]) }
        persistAndSync()
        TagService.shared.cleanupEmptyTags(context: modelContext, candidates: Array(note.tags))
    }

    func emptyTrash() {
        let deleted = fetchDeletedNotesForCurrentUser()
        guard !deleted.isEmpty else { return }
        let affectedTags = deleted.flatMap { $0.tags }
        let deletedIds = deleted.map { $0.id }
        withAnimation {
            for note in deleted {
                modelContext.delete(note)
            }
        }
        Task { await NotesSearchIndexer.shared.remove(noteIDs: deletedIds) }
        persistAndSync()
        TagService.shared.cleanupEmptyTags(context: modelContext, candidates: affectedTags)
    }

    func fetchDeletedNotesForCurrentUser() -> [Note] {
        var descriptor = FetchDescriptor<Note>()
        let userId = currentUserId
        descriptor.predicate = #Predicate<Note> { note in
            note.userId == userId && note.deletedAt != nil
        }
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func togglePin(_ note: Note) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if note.pinnedAt == nil {
                note.pinnedAt = Date()
            } else {
                note.pinnedAt = nil
            }
            note.updatedAt = Date()
        }
        persistAndSync()
    }

    func deleteSelectedNotes() {
        let notesToDelete = getSelectedNotes()
        deleteNotes(notesToDelete)
        exitSelectionMode()
    }

    func deleteNotes(_ notes: [Note]) {
        withAnimation {
            for note in notes where note.deletedAt == nil {
                note.markDeleted()
            }
        }
        persistAndSync()
        TagService.shared.cleanupEmptyTags(context: modelContext, candidates: notes.flatMap { $0.tags })
    }

    func persistAndSync() {
        try? modelContext.save()
        Task {
            if FeatureFlags.useLocalFTSSearch {
                await NotesSearchIndexer.shared.syncIncremental(context: modelContext, userId: currentUserId)
            }
            await syncManager.syncIfNeeded(context: modelContext)
            requestReload(delayNanoseconds: 80_000_000)
        }
    }

    func touchTag(_ tag: Tag, note: Note? = nil) {
        let now = Date()
        tag.lastUsedAt = now
        tag.updatedAt = now
        note?.updatedAt = now
    }

    func applyCurrentTagContext(to note: Note) {
        guard let currentTag = selectedTag else { return }
        note.tags.append(currentTag)
        touchTag(currentTag, note: note)
    }
}
