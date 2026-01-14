import SwiftUI

extension Color {
    // MARK: - Brand Palette (Warm & Mellow)
    static let mellowYellow = Color(hex: "FFD56B") // Warm Honey Yellow
    static let mellowOrange = Color(hex: "FFB347") // Sunset Orange for accents
    static let paleCream = Color(hex: "FFF9E5")    // Very light yellow background
    
    // MARK: - Semantic Colors
    static let bgPrimary = Color(hex: "FAFAFA")    // Light grey background (original)
    static let bgSecondary = Color(hex: "F2F2F7")  // Slightly darker grey (original)
    static let cardBackground = Color.white
    
    // Warm accent replacement for system blue
    static let accentPrimary = Color(hex: "FFC043") // Richer yellow for actions
    static let selectionHighlight = Color(hex: "FFF4D1") // Very pale yellow for selection bg
    
    // Text Colors (Softer than pure black)
    static let textMain = Color(hex: "3E3B36")     // Deep Latte Brown
    static let textSub = Color(hex: "8A8680")      // Warm Grey
    
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
