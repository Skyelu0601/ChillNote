import Foundation
import SwiftData

@Model
final class ChecklistItem {
    var id: UUID
    var text: String
    var isDone: Bool
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    var note: Note?

    init(text: String, isDone: Bool = false, sortOrder: Int, note: Note? = nil) {
        let now = Date()
        self.id = UUID()
        self.text = text
        self.isDone = isDone
        self.sortOrder = sortOrder
        self.createdAt = now
        self.updatedAt = now
        self.note = note
    }
}

