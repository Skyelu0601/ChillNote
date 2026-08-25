import SwiftUI

extension Color {
    // MARK: - Brand Palette (Calm / Warm / Focused)
    //
    // Goal: "秒开、秒记、秒同步" 的轻快工具感
    // - Keep the existing blue as the recognizable brand signature.
    // - Let warmer neutrals carry most of the interface.
    // - Give AI and inspiration their own quieter semantic colors.
    static let brandBlue = Color(hex: "2F86FF")
    static let brandBlueText = Color(hex: "176BCB")
    static let brandBlueSoft = Color(hex: "EEF5FF")

    static let brandTeal = Color(hex: "258C86")
    static let brandTealText = Color(hex: "176F6A")
    static let brandTealSoft = Color(hex: "EAF4F2")

    static let brandHoney = Color(hex: "D89A3D")
    static let brandHoneyText = Color(hex: "8C5A10")
    static let brandHoneySoft = Color(hex: "FBF3E4")

    // MARK: - Semantic Colors
    static let bgPrimary = Color(hex: "F6F5F2") // warm near-white
    static let bgSecondary = Color(hex: "FFFFFF")
    static let cardBackground = Color(hex: "FFFFFF")

    // Surfaces & Separators
    static let separator = Color(hex: "E7E5E0")
    static let borderSubtle = Color(hex: "EBE9E4")

    // Actions & Highlights
    static let accentPrimary = brandBlue
    static let accentPrimaryText = brandBlueText
    static let accentSecondary = brandTeal
    static let accentSecondaryText = brandTealText
    static let inspirationAccent = brandHoney
    static let inspirationAccentText = brandHoneyText
    static let selectionHighlight = brandBlueSoft
    static let secondaryHighlight = brandTealSoft
    static let inspirationHighlight = brandHoneySoft

    // Text Colors
    static let textMain = Color(hex: "17181B") // warm near-black
    static let textSub = Color(hex: "6B6B73")  // system-like secondary
    static let textTertiary = Color(hex: "9A9AA3")

    // Shadows (kept subtle; prefer separators/borders for structure)
    static let shadowColor = Color(hex: "0B0B10").opacity(0.06)
    
    // MARK: - Helpers
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
