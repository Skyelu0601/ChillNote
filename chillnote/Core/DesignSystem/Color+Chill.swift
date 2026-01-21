import SwiftUI

extension Color {
    // MARK: - Brand Palette (Japandi / Warm & Mellow)
    static let mellowYellow = Color(hex: "F3E2A9") // Softer, pastel yellow (Butter)
    static let mellowOrange = Color(hex: "EBB176") // Soft Apricot
    static let paleCream = Color(hex: "FDFCF8")    // Paper White (Main Background)
    
    // MARK: - Aesthetic Accents
    static let sageGreen = Color(hex: "9CAF88")    // Muted earthy green
    static let dustyBlue = Color(hex: "8DA399")    // Muted blue-grey
    
    // MARK: - Semantic Colors
    static let bgPrimary = Color(hex: "FDFCF8")    // Paper White
    static let bgSecondary = Color(hex: "F4F2EB")  // Warm light grey/beige
    static let cardBackground = Color.white
    
    // Actions & Highlights
    static let accentPrimary = Color(hex: "E6A355") // Warm Bronze/Orange for primary actions
    static let selectionHighlight = Color(hex: "FFF8E1") // Very pale warm highlight
    
    // Text Colors
    static let textMain = Color(hex: "2D2A26")     // Soft Charcoal
    static let textSub = Color(hex: "85807A")      // Warm Grey
    
    // Shadows
    static let shadowColor = Color(hex: "5A4C38").opacity(0.08) // Warm diffused shadow
    
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
