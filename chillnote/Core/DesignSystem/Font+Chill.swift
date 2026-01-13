import SwiftUI

extension Font {
    // We stick to Apple System rounded for that "Chill" vibe + native feel
    // unless user loads "Outfit" externally. for MVP, System Rounded is robust.
    
    static let displayLarge = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let displayMedium = Font.system(.title2, design: .rounded).weight(.semibold)
    
    static let bodyLarge = Font.system(.body, design: .default)
    static let bodyMedium = Font.system(.callout, design: .default)
    static let bodySmall = Font.system(.subheadline, design: .default).weight(.medium)
    
    static let chillCaption = Font.system(.caption, design: .default).weight(.medium)
}

struct Typography_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Display Large").font(.displayLarge)
            Text("Display Medium").font(.displayMedium)
            Text("Body Large").font(.bodyLarge)
            Text("Body Medium").font(.bodyMedium)
            Text("Body Small").font(.bodySmall)
            Text("Caption").font(.chillCaption)
        }
    }
}
