import SwiftUI

extension Color {
    // MARK: - Brand Palette (Clean / Fast / Modern)
    //
    // Goal: "秒开、秒记、秒同步" 的轻快工具感
    // - More neutral backgrounds (less warm paper tone)
    // - Crisp separators instead of heavy shadows
    // - iOS-like blue, slightly lighter than systemBlue (#007AFF)
    static let brandBlue = Color(hex: "2F86FF") // light iOS-like blue
    static let brandBlueSoft = Color(hex: "EAF2FF") // selection / subtle highlight

    // MARK: - Semantic Colors
    static let bgPrimary = Color(hex: "F7F7F8") // neutral near-white
    static let bgSecondary = Color(hex: "FFFFFF")
    static let cardBackground = Color(hex: "FFFFFF")

    // Surfaces & Separators
    static let separator = Color(hex: "E6E6E8")
    static let borderSubtle = Color(hex: "ECECEF")

    // Actions & Highlights
    static let accentPrimary = brandBlue
    static let selectionHighlight = brandBlueSoft

    // Text Colors
    static let textMain = Color(hex: "111114") // near-black
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
