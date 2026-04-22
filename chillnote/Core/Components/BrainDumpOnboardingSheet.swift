import SwiftUI

struct BrainDumpOnboardingSheet: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 12) {
                BrainDumpOnboardingPoint(
                    icon: "quote.bubble.fill",
                    title: L10n.text("recording.onboarding.point.speak.title"),
                    message: L10n.text("recording.onboarding.point.speak.body")
                )
                BrainDumpOnboardingPoint(
                    icon: "sparkles",
                    title: L10n.text("recording.onboarding.point.organize.title"),
                    message: L10n.text("recording.onboarding.point.organize.body")
                )
                BrainDumpOnboardingPoint(
                    icon: "scribble.variable",
                    title: L10n.text("recording.onboarding.point.messy.title"),
                    message: L10n.text("recording.onboarding.point.messy.body")
                )
            }

            Button(action: onStart) {
                Text(L10n.text("recording.onboarding.cta"))
                    .font(.bodySmall)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(
                            colors: [Color.accentPrimary, Color.accentPrimary.opacity(0.88)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.accentPrimary.opacity(0.18), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 24)
        .background(Color.bgPrimary)
    }
}

private struct BrainDumpOnboardingPoint: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentPrimary.opacity(0.09))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.accentPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.bodyMedium.weight(.semibold))
                    .foregroundColor(.textMain)

                Text(message)
                    .font(.caption)
                    .foregroundColor(.textSub)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

#if DEBUG
struct BrainDumpOnboardingSheet_Previews: PreviewProvider {
    static var previews: some View {
        BrainDumpOnboardingSheet(onStart: {})
            .background(Color.bgPrimary)
    }
}
#endif
