import SwiftUI

struct HomeCreditGiftPromptOverlay: View {
    let onDismiss: () -> Void

    private let sparkleGold = Color(hex: "F5B942")

    var body: some View {
        ZStack {
            Color.black.opacity(0.30)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 18) {
                giftMark

                VStack(spacing: 8) {
                    Text(L10n.text("home.credit_gift.title", 50))
                        .font(.system(size: 28, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.textMain)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    Text(L10n.text("home.credit_gift.message"))
                        .font(.bodyMedium)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.textSub)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(L10n.text("home.credit_gift.balance_hint"))
                    .font(.chillCaption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.textSub.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onDismiss) {
                    Text(L10n.text("home.credit_gift.action"))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.accentPrimary)
                        )
                }
                .buttonStyle(.plain)
                .shadow(color: Color.accentPrimary.opacity(0.22), radius: 12, x: 0, y: 6)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 22)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.accentPrimary.opacity(0.10), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.14), radius: 28, x: 0, y: 16)
            .padding(.horizontal, 24)
        }
        .accessibilityElement(children: .contain)
    }

    private var giftMark: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentPrimary.opacity(0.12),
                            Color.accentSecondary.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 86, height: 86)

            Image(systemName: "gift.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentPrimary, Color.accentSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "sparkle")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(sparkleGold)
                .offset(x: 34, y: -28)

            Image(systemName: "bolt.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(sparkleGold)
                .padding(7)
                .background(Circle().fill(Color.white))
                .offset(x: 32, y: 24)
                .shadow(color: Color.black.opacity(0.06), radius: 5, x: 0, y: 2)
        }
        .accessibilityLabel(L10n.text("home.credit_gift.icon_accessibility"))
    }
}

#Preview {
    HomeCreditGiftPromptOverlay {}
        .background(Color.bgPrimary)
}
