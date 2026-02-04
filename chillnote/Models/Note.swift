import SwiftUI
import SwiftData

enum NoteContentFormat: String {
    case text
    case checklist
}

@Model
final class Note {
    var id: UUID
    var userId: String
    var content: String  // Markdown format - single source of truth
    var contentFormat: String
    var checklistNotes: String
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var pinnedAt: Date?
    
    @Relationship
    var tags: [Tag] = []
    
    var suggestedTags: [String] = []
    
    /// Get display text for previews (strips Markdown formatting)
    var displayText: String {
        let sourceText: String
        if isChecklist {
            sourceText = ChecklistMarkdown.serializePlainText(notes: checklistNotes, items: checklistItems)
        } else {
            sourceText = stripMarkdownFormatting(content)
        }
        let limit = 200
        if sourceText.count <= limit {
            return sourceText
        }
        let prefixText = sourceText.prefix(limit)
        return "\(prefixText)..."
    }
    
    /// Strip basic Markdown formatting for plain text display
    private func stripMarkdownFormatting(_ text: String) -> String {
        var result = text
        // Remove headers
        result = result.replacingOccurrences(of: #"^#{1,6}\s+"#, with: "", options: .regularExpression)
        // Remove bold
        result = result.replacingOccurrences(of: "**", with: "")
        // Remove italic
        result = result.replacingOccurrences(of: "*", with: "")
        // Remove code
        result = result.replacingOccurrences(of: "`", with: "")
        // Remove checkbox markers
        result = result.replacingOccurrences(of: "- [ ] ", with: "")
        result = result.replacingOccurrences(of: "- [x] ", with: "")
        result = result.replacingOccurrences(of: "- [X] ", with: "")
        // Remove bullet markers
        result = result.replacingOccurrences(of: #"^[\-\•]\s+"#, with: "", options: .regularExpression)
        return result
    }

    @Relationship(deleteRule: .cascade, inverse: \ChecklistItem.note)
    var checklistItems: [ChecklistItem] = []

    init(content: String, userId: String) {
        let now = Date()
        self.id = UUID()
        self.userId = userId
        self.content = content
        self.contentFormat = NoteContentFormat.text.rawValue
        self.checklistNotes = ""
        self.createdAt = now
        self.updatedAt = now
        self.deletedAt = nil
        self.pinnedAt = nil
        self.tags = []
        self.suggestedTags = []

        if let parsed = ChecklistMarkdown.parse(content) {
            self.contentFormat = NoteContentFormat.checklist.rawValue
            self.checklistNotes = parsed.notes
            self.checklistItems = parsed.items.enumerated().map { index, item in
                ChecklistItem(text: item.text, isDone: item.isDone, sortOrder: index, note: self)
            }
            self.content = ChecklistMarkdown.serialize(notes: self.checklistNotes, items: self.checklistItems)
        }
    }

    var isChecklist: Bool {
        contentFormat == NoteContentFormat.checklist.rawValue
    }

    func syncContentStructure(with context: ModelContext) {
        guard let parsed = ChecklistMarkdown.parse(content) else {
            guard isChecklist else { return }
            contentFormat = NoteContentFormat.text.rawValue
            checklistNotes = ""
            if !checklistItems.isEmpty {
                for item in checklistItems {
                    context.delete(item)
                }
                checklistItems.removeAll()
            }
            return
        }

        contentFormat = NoteContentFormat.checklist.rawValue
        checklistNotes = parsed.notes

        // Update existing checklist items in place to preserve any future local metadata.
        var updatedItems: [ChecklistItem] = []
        for (index, item) in parsed.items.enumerated() {
            if index < checklistItems.count {
                let existingItem = checklistItems[index]
                existingItem.text = item.text
                existingItem.isDone = item.isDone
                existingItem.sortOrder = index
                updatedItems.append(existingItem)
            } else {
                let newItem = ChecklistItem(text: item.text, isDone: item.isDone, sortOrder: index, note: self)
                context.insert(newItem)
                updatedItems.append(newItem)
            }
        }

        if checklistItems.count > parsed.items.count {
            let itemsToRemove = checklistItems.suffix(from: parsed.items.count)
            for item in itemsToRemove {
                context.delete(item)
            }
        }

        checklistItems = updatedItems
    }

    func rebuildContentFromChecklist() {
        content = ChecklistMarkdown.serialize(notes: checklistNotes, items: checklistItems)
    }
    
    func markDeleted() {
        deletedAt = Date()
        updatedAt = deletedAt ?? updatedAt
    }
    
    // MARK: - Export Functions
    
    /// Export note as Markdown (original format)
    func exportAsMarkdown() -> String {
        return content
    }
    
    /// Export note as plain text (all formatting stripped)
    func exportAsPlainText() -> String {
        return stripMarkdownFormatting(content)
    }
}

extension Note: Hashable {
    static func == (lhs: Note, rhs: Note) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
