import SwiftUI
import SwiftData

enum NoteContentFormat: String {
    case text
    case checklist
    case html  // New: Rich text stored as HTML
}

@Model
final class Note {
    var id: UUID
    var content: String  // Legacy: Markdown/plain text (kept for backward compatibility)
    var contentHTML: String?  // New: HTML formatted content for rich text editing
    var contentFormat: String
    var checklistNotes: String
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    
    /// Get the editable HTML content, migrating from Markdown if needed
    var editableHTML: String {
        get {
            // If we already have HTML content, use it
            if let html = contentHTML, !html.isEmpty {
                return html
            }
            // Otherwise, convert from Markdown/plain text
            return HTMLConverter.markdownToHTML(content)
        }
        set {
            contentHTML = newValue
            contentFormat = NoteContentFormat.html.rawValue
            // Keep plain text version synced for search/preview
            content = HTMLConverter.htmlToPlainText(newValue)
        }
    }
    
    /// Check if note uses the new HTML format
    var isHTMLFormat: Bool {
        contentFormat == NoteContentFormat.html.rawValue && contentHTML != nil && !contentHTML!.isEmpty
    }
    
    var displayText: String {
        // For HTML format, use plain text extracted from HTML
        if isHTMLFormat {
            let plainText = HTMLConverter.htmlToPlainText(contentHTML ?? "")
            let limit = 200
            if plainText.count <= limit {
                return plainText
            }
            return "\(plainText.prefix(limit))..."
        }
        
        // Legacy handling for Markdown format
        let sourceText: String
        if isChecklist {
            sourceText = ChecklistMarkdown.serializePlainText(notes: checklistNotes, items: checklistItems)
        } else {
            sourceText = content
        }
        let limit = 200
        if sourceText.count <= limit {
            return sourceText
        }
        let prefixText = sourceText.prefix(limit)
        return "\(prefixText)..."
    }

    @Relationship(deleteRule: .cascade, inverse: \ChecklistItem.note)
    var checklistItems: [ChecklistItem] = []

    init(content: String) {
        let now = Date()
        self.id = UUID()
        self.content = content
        self.contentHTML = nil
        self.contentFormat = NoteContentFormat.text.rawValue
        self.checklistNotes = ""
        self.createdAt = now
        self.updatedAt = now
        self.deletedAt = nil

        if let parsed = ChecklistMarkdown.parse(content) {
            self.contentFormat = NoteContentFormat.checklist.rawValue
            self.checklistNotes = parsed.notes
            self.checklistItems = parsed.items.enumerated().map { index, item in
                ChecklistItem(text: item.text, isDone: item.isDone, sortOrder: index, note: self)
            }
            self.content = ChecklistMarkdown.serialize(notes: self.checklistNotes, items: self.checklistItems)
        }
    }
    
    /// Initialize with HTML content directly
    init(htmlContent: String) {
        let now = Date()
        self.id = UUID()
        self.contentHTML = htmlContent
        self.content = HTMLConverter.htmlToPlainText(htmlContent)
        self.contentFormat = NoteContentFormat.html.rawValue
        self.checklistNotes = ""
        self.createdAt = now
        self.updatedAt = now
        self.deletedAt = nil
    }

    var isChecklist: Bool {
        contentFormat == NoteContentFormat.checklist.rawValue
    }
    
    /// Migrate legacy content to HTML format
    func migrateToHTML() {
        guard !isHTMLFormat else { return }
        
        let html = HTMLConverter.markdownToHTML(content)
        contentHTML = html
        contentFormat = NoteContentFormat.html.rawValue
    }

    func syncContentStructure(with context: ModelContext) {
        // Skip for HTML format notes
        guard !isHTMLFormat else { return }
        
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
}
