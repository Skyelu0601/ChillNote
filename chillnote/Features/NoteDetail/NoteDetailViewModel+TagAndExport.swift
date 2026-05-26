import Foundation
import OSLog
import SwiftData
import SwiftUI

private let noteDetailTagLogger = Logger(subsystem: "com.chillnote.app", category: "note-detail-tags")

@MainActor
extension NoteDetailViewModel {
    func removeTag(_ tag: Tag) {
        guard let modelContext else { return }
        note.tags.removeAll { $0.id == tag.id }
        note.updatedAt = dependencies.now()
        TagService.shared.cleanupEmptyTags(context: modelContext, candidates: [tag])
    }

    func confirmTag(_ tagName: String, preferredColorHex: String? = nil) {
        guard let modelContext else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            let fetchDescriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.deletedAt == nil })
            let allTags: [Tag]
            do {
                allTags = try modelContext.fetch(fetchDescriptor)
            } catch {
                noteDetailTagLogger.error("Failed to fetch tags for note detail confirmation: \(error.localizedDescription, privacy: .public)")
                return
            }
            let existing = allTags.first { $0.name.lowercased() == tagName.lowercased() }

            if let existing {
                if !note.tags.contains(where: { $0.id == existing.id }) {
                    note.tags.append(existing)
                    touchTag(existing, note: note)
                }
            } else {
                guard let userId = AuthService.shared.currentUserId else { return }
                let colorHex = preferredColorHex.map(TagColorService.normalizedHex)
                    ?? TagColorService.autoColorHex(for: tagName, existingTags: allTags)
                let newTag = Tag(name: tagName, userId: userId, colorHex: colorHex)
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
            exportErrorMessage = L10n.text("note_detail.export.error.unable_to_export_note")
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
