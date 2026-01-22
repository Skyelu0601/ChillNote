import Foundation
import SwiftData
import SwiftUI

@Model
final class Tag {
    var id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date
    var lastUsedAt: Date
    
    var aiSummary: String?
    
    // MARK: - Hierarchy Support
    /// Parent tag for tree structure
    @Relationship var parent: Tag?
    
    /// Child tags (inverse of parent)
    @Relationship(inverse: \Tag.parent) var children: [Tag] = []
    
    /// Sort order within siblings
    var sortOrder: Int = 0
    
    @Relationship(inverse: \Note.tags)
    var notes: [Note] = []
    
    init(name: String, colorHex: String = "#E6A355") {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.createdAt = Date()
        self.lastUsedAt = Date()
        self.notes = []
        self.parent = nil
        self.children = []
        self.sortOrder = 0
    }
    
    // MARK: - Computed Properties
    
    var color: Color {
        Color(hex: colorHex)
    }
    
    /// Whether this tag is a root-level tag (no parent)
    var isRoot: Bool {
        parent == nil
    }
    
    /// Get all ancestor tags (from root to immediate parent)
    var ancestors: [Tag] {
        var result: [Tag] = []
        var current = self.parent
        while let p = current {
            result.insert(p, at: 0)
            current = p.parent
        }
        return result
    }
    
    /// Get all descendant tags recursively
    var allDescendants: [Tag] {
        var result: [Tag] = []
        for child in children {
            result.append(child)
            result.append(contentsOf: child.allDescendants)
        }
        return result
    }
    
    /// Full path including this tag (e.g., "Work > AI > LLM")
    var fullPath: String {
        let path = ancestors + [self]
        return path.map { $0.name }.joined(separator: " > ")
    }
    
    /// Check if this tag is an ancestor of another tag
    func isAncestor(of tag: Tag) -> Bool {
        var current = tag.parent
        while let p = current {
            if p.id == self.id { return true }
            current = p.parent
        }
        return false
    }
    
    /// Sorted children by sortOrder
    var sortedChildren: [Tag] {
        children.sorted { $0.sortOrder < $1.sortOrder }
    }
}
