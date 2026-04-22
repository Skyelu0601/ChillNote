import Foundation
import SwiftUI

enum TagColorService {
    static let defaultColorHex = "#2F86FF"

    static let paletteHexes: [String] = [
        "#2F86FF", // iOS-like blue (light)
        "#5B8CFF", // periwinkle blue
        "#7A5CFF", // violet
        "#B14DFF", // purple
        "#00A3FF", // sky cyan
        "#00B8A9", // teal
        "#2ECC71", // green
        "#A3A3AE", // neutral gray (tool-like)
        "#6B7280", // slate gray
        "#111114"  // near-black (high contrast tag)
    ]

    static let tagBackgroundOpacity: Double = 0.20

    static func normalizedHex(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .uppercased()

        guard trimmed.count == 6,
              trimmed.range(of: "^[0-9A-F]{6}$", options: .regularExpression) != nil else {
            return defaultColorHex
        }
        return "#\(trimmed)"
    }

    static func color(for hex: String) -> Color {
        Color(hex: normalizedHex(hex))
    }

    static func textColor(for hex: String) -> Color {
        .textMain
    }

    static func autoColorHex(for tagName: String, existingTags: [Tag]) -> String {
        if let matched = existingTags.first(where: {
            $0.deletedAt == nil && $0.name.compare(tagName, options: .caseInsensitive) == .orderedSame
        }) {
            return normalizedHex(matched.colorHex)
        }

        let activeCount = existingTags.filter { $0.deletedAt == nil }.count
        let index = activeCount % paletteHexes.count
        return paletteHexes[index]
    }

}
