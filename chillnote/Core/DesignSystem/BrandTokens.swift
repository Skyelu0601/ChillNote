import SwiftUI

/// Shared visual tokens for the onboarding → login → paywall flow.
///
/// Existing screens use `Color+Chill` and `Font+Chill`. This file does NOT
/// replace them — it adds the missing layer (radii, spacing, elevation, and
/// fixed-size display fonts) that the three flagship flows need to look like
/// one app instead of three.
enum BrandTokens {

    // MARK: - Corner Radii
    //
    // Three tiers only. If a new component needs a different radius, pick the
    // closest one rather than introducing a fourth.
    enum Radius {
        /// Buttons, segmented controls, inputs.
        static let button: CGFloat = 14
        /// Cards, sheets, hero containers.
        static let card: CGFloat = 20
        /// Tags, chips, badges.
        static let pill: CGFloat = 999
    }

    // MARK: - Spacing (8pt grid)
    enum Space {
        static let s1: CGFloat = 8
        static let s2: CGFloat = 12
        static let s3: CGFloat = 16
        static let s4: CGFloat = 24
        static let s5: CGFloat = 32
        static let s6: CGFloat = 48
    }

    // MARK: - Sizes
    enum Size {
        /// Primary CTA button height — same across onboarding, login, paywall.
        static let primaryButtonHeight: CGFloat = 56
        /// Secondary / inline button height.
        static let secondaryButtonHeight: CGFloat = 44
    }

    // MARK: - Elevation
    enum Shadow {
        /// For white cards on bgPrimary.
        static let card = ShadowStyle(
            color: Color.shadowColor,
            radius: 16,
            x: 0,
            y: 8
        )
        /// For the accent-tinted primary CTA.
        static let primaryButton = ShadowStyle(
            color: Color.accentPrimary.opacity(0.22),
            radius: 12,
            x: 0,
            y: 6
        )
        /// For raised neutral buttons (Google/Apple/Email on the login page).
        static let neutralButton = ShadowStyle(
            color: Color.black.opacity(0.06),
            radius: 10,
            x: 0,
            y: 4
        )
    }

    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

struct BrandWordmark: View {
    var chillSize: CGFloat = 36

    private var noteSize: CGFloat {
        chillSize + 2
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(verbatim: "Chill")
                .font(.custom("AvenirNext-DemiBold", size: chillSize))
                .foregroundColor(Color(red: 0.184, green: 0.525, blue: 1.0))

            Text(verbatim: "Note")
                .font(.custom("AvenirNext-HeavyItalic", size: noteSize))
                .foregroundColor(Color(red: 0.365, green: 0.569, blue: 0.961))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(L10n.text("auth.login.brand_title")))
    }
}

// MARK: - Display Fonts (fixed-size, for marketing surfaces)
//
// `Font+Chill` exposes dynamic-type fonts for the in-app content. The
// onboarding / login / paywall screens use fixed sizes so the visual
// hierarchy stays predictable across devices. Keep these names scoped
// under `.brand…` so they can't collide with the existing tokens.
extension Font {
    /// 34 / bold — page hero ("Capture Inspiration, Your Way.")
    static let brandDisplay = Font.system(size: 34, weight: .bold)
    /// 28 / bold — secondary hero (paywall trial title).
    static let brandTitle1 = Font.system(size: 28, weight: .bold)
    /// 22 / semibold — section headers, price labels.
    static let brandTitle2 = Font.system(size: 22, weight: .semibold)
    /// 17 / semibold — primary CTA label.
    static let brandButton = Font.system(size: 17, weight: .semibold)
    /// 17 / regular — supporting body copy under hero titles.
    static let brandBody = Font.system(size: 17, weight: .regular)
    /// 15 / medium — card body, feature list items.
    static let brandBodySmall = Font.system(size: 15, weight: .medium)
    /// 13 / semibold — tab labels, captions.
    static let brandLabel = Font.system(size: 13, weight: .semibold)
    /// 11 / bold — uppercase eyebrow ("INPUT", "OUTPUT"). Pair with tracking 0.5.
    static let brandEyebrow = Font.system(size: 11, weight: .bold)
}

// MARK: - View helpers

extension View {
    /// Applies a `BrandTokens.ShadowStyle`.
    func brandShadow(_ style: BrandTokens.ShadowStyle) -> some View {
        shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }

    /// Standard primary-CTA chrome: full-width, 56pt tall, accent-filled,
    /// `Radius.button` corners, accent shadow. Use on the label inside a
    /// `Button { } label: { … }` block.
    func brandPrimaryCTAStyle() -> some View {
        font(.brandButton)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: BrandTokens.Size.primaryButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: BrandTokens.Radius.button, style: .continuous)
                    .fill(Color.accentPrimary)
            )
            .brandShadow(BrandTokens.Shadow.primaryButton)
    }

    /// Standard neutral button chrome (Google/Apple/Email on login).
    /// Pass `foreground` to control text/icon color (white on the Apple button,
    /// black on the others).
    func brandNeutralButtonStyle(
        background: Color = .white,
        foreground: Color = .black
    ) -> some View {
        font(.system(size: 17, weight: .medium))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: BrandTokens.Size.primaryButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: BrandTokens.Radius.button, style: .continuous)
                    .fill(background)
            )
            .brandShadow(BrandTokens.Shadow.neutralButton)
    }

    /// Standard white card surface used by hero/feature cards across the flow.
    func brandCardSurface() -> some View {
        background(
            RoundedRectangle(cornerRadius: BrandTokens.Radius.card, style: .continuous)
                .fill(Color.cardBackground)
                .brandShadow(BrandTokens.Shadow.card)
        )
    }
}
