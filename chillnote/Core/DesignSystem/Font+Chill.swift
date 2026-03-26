import SwiftUI

extension Font {
    // We use Serif for titles to give a premium, organic "Japandi" feel.
    // Body text remains sans-serif (Default or Rounded) for legibility.
    
    static let displayLarge = Font.system(.largeTitle, design: .serif).weight(.medium)
    static let displayMedium = Font.system(.title2, design: .serif).weight(.medium)
    static let displaySmall = Font.system(.headline, design: .serif).weight(.medium)
    
    static let bodyLarge = Font.system(.body, design: .default)
    static let bodyMedium = Font.system(.callout, design: .default)
    static let bodySmall = Font.system(.subheadline, design: .default).weight(.medium)
    
    static let chillCaption = Font.system(.caption, design: .default).weight(.medium)
}

struct Typography_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.text("font.preview.display_large")).font(.displayLarge)
            Text(L10n.text("font.preview.display_medium")).font(.displayMedium)
            Text(L10n.text("font.preview.body_large")).font(.bodyLarge)
            Text(L10n.text("font.preview.body_medium")).font(.bodyMedium)
            Text(L10n.text("font.preview.body_small")).font(.bodySmall)
            Text(L10n.text("font.preview.caption")).font(.chillCaption)
        }
    }
}
