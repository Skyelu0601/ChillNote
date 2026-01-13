import SwiftUI
import SwiftData

@Model
final class Note {
    var id: UUID
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    
    var displayText: String {
        let sourceText = content
        let limit = 200
        if sourceText.count <= limit {
            return sourceText
        }
        let prefixText = sourceText.prefix(limit)
        return "\(prefixText)..."
    }

    init(content: String) {
        let now = Date()
        self.id = UUID()
        self.content = content
        self.createdAt = now
        self.updatedAt = now
        self.deletedAt = nil
    }
    
    func markDeleted() {
        deletedAt = Date()
        updatedAt = deletedAt ?? updatedAt
    }
}
