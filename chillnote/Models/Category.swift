import SwiftUI
import SwiftData

@Model
final class Category {
    var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var order: Int
    var createdAt: Date
    
    @Relationship(inverse: \Note.categories)
    var notes: [Note]?
    
    init(name: String, icon: String, colorHex: String, order: Int) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.order = order
        self.createdAt = Date()
    }
    
    var color: Color {
        Color(hex: colorHex)
    }
    
    // Preset categories
    static let presets: [(name: String, icon: String, colorHex: String)] = [
        ("Work", "briefcase.fill", "#FF6B6B"),
        ("Life", "house.fill", "#4ECDC4"),
        ("Study", "book.fill", "#95E1D3"),
        ("Ideas", "lightbulb.fill", "#FFE66D"),
        ("Todo", "checkmark.circle.fill", "#A8E6CF"),
        ("Other", "folder.fill", "#C7CEEA")
    ]
    
    static func createPresets() -> [Category] {
        return presets.enumerated().map { index, preset in
            Category(
                name: preset.name,
                icon: preset.icon,
                colorHex: preset.colorHex,
                order: index
            )
        }
    }
}
