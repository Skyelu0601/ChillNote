import Foundation
import SwiftUI

enum TagColorService {
    static let defaultColorHex = "#E6A355"

    static let paletteHexes: [String] = [
        "#E6A355", // warm orange
        "#EBB176", // apricot
        "#D9B75A", // honey yellow
        "#8FA96B", // moss green
        "#9CAF88", // sage
        "#7FA8A0", // teal gray
        "#6FA7C9", // lake blue
        "#6F86C9", // indigo
        "#9A8FC2", // soft violet gray
        "#C48A8A", // rose brown
        "#D97A6D", // coral
        "#7E7A74"  // stone gray
    ]

    static let tagBackgroundOpacity: Double = 0.28

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
