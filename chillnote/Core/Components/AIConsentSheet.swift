import SwiftUI
import UIKit

struct AIConsentSheet: View {
    @ObservedObject var consentManager: AIConsentManager
    let prompt: AIConsentManager.Prompt
    @Binding var measuredHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(prompt.trigger.title)
                    .font(.displaySmall)
                    .foregroundColor(.textMain)

                Text(prompt.trigger.summary)
                    .font(.bodyMedium)
                    .foregroundColor(.textSub)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.text("ai_consent.data_usage"))
                    .font(.bodyMedium)
                    .foregroundColor(.textSub)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L10n.text("ai_consent.raw_audio"))
                    .font(.bodyMedium)
                    .foregroundColor(.textSub)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                Button(action: consentManager.declineAIDataConsent) {
                    Text(L10n.text("ai_consent.not_now"))
                        .font(.bodySmall)
                        .foregroundColor(.textMain)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.bgSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.black.opacity(0.05), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: consentManager.acceptAIDataConsent) {
                    Text(L10n.text("ai_consent.agree_and_continue"))
                        .font(.bodySmall)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            LinearGradient(
                                colors: [Color.accentPrimary, Color.mellowOrange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.accentPrimary.opacity(0.18), radius: 10, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }

            Button(action: openPrivacyPolicy) {
                Text(L10n.text("ai_consent.view_privacy_policy"))
                    .font(.chillCaption)
                    .foregroundColor(.accentPrimary)
                    .underline()
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(22)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: AIConsentSheetHeightPreferenceKey.self, value: geometry.size.height)
            }
        )
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.9))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color.shadowColor.opacity(0.9), radius: 20, x: 0, y: 10)
        )
        .padding(.horizontal, 16)
        .presentationBackground(.clear)
        .presentationDragIndicator(.visible)
        .onPreferenceChange(AIConsentSheetHeightPreferenceKey.self) { height in
            let adjustedHeight = height + 36
            if abs(measuredHeight - adjustedHeight) > 1 {
                measuredHeight = adjustedHeight
            }
        }
    }

    private func openPrivacyPolicy() {
        guard let url = URL(string: "https://www.chillnoteai.com/privacy.html") else { return }
        UIApplication.shared.open(url)
    }
}

private struct AIConsentSheetHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 360

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
