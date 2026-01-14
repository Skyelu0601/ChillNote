import SwiftUI
import SwiftData

@Model
final class Note {
    var id: UUID
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    
    // Category support
    @Relationship(deleteRule: .nullify)
    var categories: [Category]?
    var aiSuggestedCategories: [String]?  // Legacy field (unused)
    
    var displayText: String {
        let sourceText = content
        let limit = 200
        if sourceText.count <= limit {
            return sourceText
        }
        let prefixText = sourceText.prefix(limit)
        return "\(prefixText)..."
    }

    init(content: String, aiSuggestedCategories: [String]? = nil) {
        let now = Date()
        self.id = UUID()
        self.content = content
        self.createdAt = now
        self.updatedAt = now
        self.deletedAt = nil
        self.aiSuggestedCategories = aiSuggestedCategories
    }
    
    func markDeleted() {
        deletedAt = Date()
        updatedAt = deletedAt ?? updatedAt
    }
    
    func addCategory(_ category: Category) {
        if categories == nil {
            categories = []
        }
        if !(categories?.contains(where: { $0.id == category.id }) ?? false) {
            categories?.append(category)
            updatedAt = Date()
        }
    }
    
    func removeCategory(_ category: Category) {
        categories?.removeAll(where: { $0.id == category.id })
        updatedAt = Date()
    }
}
