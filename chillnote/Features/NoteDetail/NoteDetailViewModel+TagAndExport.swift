import Foundation
import SwiftData
import SwiftUI

@MainActor
extension NoteDetailViewModel {
    func generateTagsIfNeeded(force: Bool = false) async {
        guard let modelContext else { return }
        guard force || !hasRequestedTagSuggestions else { return }
        guard !note.content.isEmpty else { return }
        hasRequestedTagSuggestions = true

        do {
            let fetchDescriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.deletedAt == nil })
            let allTags = (try? modelContext.fetch(fetchDescriptor))?.map { $0.name } ?? []

            let suggestions = try await dependencies.suggestTags(note.content, allTags)
            guard !suggestions.isEmpty else { return }

            withAnimation {
                note.suggestedTags = suggestions
            }
            try? modelContext.save()
        } catch {
            hasRequestedTagSuggestions = false
        }
    }

    func removeTag(_ tag: Tag) {
        guard let modelContext else { return }
        note.tags.removeAll { $0.id == tag.id }
        note.updatedAt = dependencies.now()
        TagService.shared.cleanupEmptyTags(context: modelContext)
    }

    func confirmTag(_ tagName: String) {
        guard let modelContext else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            note.suggestedTags.removeAll { $0 == tagName }

            let fetchDescriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.deletedAt == nil })
            let allTags = (try? modelContext.fetch(fetchDescriptor)) ?? []
            let existing = allTags.first { $0.name.lowercased() == tagName.lowercased() }

            if let existing {
                if !note.tags.contains(where: { $0.id == existing.id }) {
                    note.tags.append(existing)
                    touchTag(existing, note: note)
                }
            } else {
                guard let userId = AuthService.shared.currentUserId else { return }
                let newTag = Tag(name: tagName, userId: userId)
                modelContext.insert(newTag)
                note.tags.append(newTag)
                note.updatedAt = dependencies.now()
            }

            persistAndSync()
        }
    }

    func exportMarkdown() {
        let markdown = note.content
        let fileName = makeExportFilename(from: markdown, createdAt: note.createdAt, noteId: note.id)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try dependencies.writeFile(markdown, url)
            exportURL = url
            showExportSheet = true
        } catch {
            exportErrorMessage = String(localized: "Unable to export this note. Please try again.")
            showExportError = true
        }
    }

    func makeExportFilename(from markdown: String, createdAt: Date, noteId: UUID) -> String {
        let rawTitle = markdown
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""

        var base = rawTitle.isEmpty ? "ChillNote" : rawTitle
        base = base.replacingOccurrences(of: #"[\\/:*?\"<>|]"#, with: "-", options: .regularExpression)
        base = base.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if base.isEmpty {
            base = "ChillNote"
        }

        if base.count > 60 {
            base = String(base.prefix(60))
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: createdAt)
        let suffix = noteId.uuidString.prefix(6)
        return "\(base)-\(timestamp)-\(suffix).md"
    }

    private func touchTag(_ tag: Tag, note: Note? = nil) {
        let now = dependencies.now()
        tag.lastUsedAt = now
        tag.updatedAt = now
        note?.updatedAt = now
    }
}
