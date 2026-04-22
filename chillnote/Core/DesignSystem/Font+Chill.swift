import SwiftUI

extension Font {
    // New direction: Clean / fast / modern.
    // Avoid serif (it reads "slow journal"). Use system sans-serif and hierarchy via size/weight.

    static let displayLarge = Font.system(.largeTitle, design: .default).weight(.semibold)
    static let displayMedium = Font.system(.title2, design: .default).weight(.semibold)
    static let displaySmall = Font.system(.headline, design: .default).weight(.semibold)

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
