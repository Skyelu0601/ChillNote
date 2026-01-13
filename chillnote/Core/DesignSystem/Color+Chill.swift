import SwiftUI

extension Color {
    // MARK: - Brand Colors
    static let chillYellow = Color(hex: "FFD046")
    static let chillYellowDim = Color(hex: "FFEBA0")
    
    // MARK: - Semantic Colors
    static let bgPrimary = Color(hex: "FAFAFA")
    static let bgSecondary = Color(hex: "F2F2F7")
    static let cardBackground = Color.white
    
    static let textMain = Color(hex: "1A1A1A")
    static let textSub = Color(hex: "6E6E73")
    
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
