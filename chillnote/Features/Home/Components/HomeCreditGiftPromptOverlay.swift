import SwiftUI

struct HomeCreditGiftPromptOverlay: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.30)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 18) {
                giftMark

                Text(L10n.text("home.credit_gift.title", 50))
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.textMain)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

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
                .fill(Color.selectionHighlight)
                .frame(width: 86, height: 86)

            Image(systemName: "gift.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Color.accentPrimary)
        }
        .accessibilityLabel(L10n.text("home.credit_gift.icon_accessibility"))
    }
}

#Preview {
    HomeCreditGiftPromptOverlay {}
        .background(Color.bgPrimary)
}
