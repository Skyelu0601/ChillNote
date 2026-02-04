import SwiftUI

struct UpgradeBottomSheet: View {
    let title: String
    let message: String
    let primaryButtonTitle: String
    let onUpgrade: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.textMain)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.body)
                .foregroundColor(.textSub)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Button(action: onUpgrade) {
                Text(primaryButtonTitle)
                    .font(.bodyMedium)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentPrimary)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }

            Button(action: onDismiss) {
                Text("Not now")
                    .font(.bodyMedium)
                    .foregroundColor(.textSub)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}

#Preview {
    UpgradeBottomSheet(
        title: "Free limit reached",
        message: "Upgrade to Pro for unlimited AI chat and 10-minute recordings.",
        primaryButtonTitle: "Upgrade to Pro",
        onUpgrade: {},
        onDismiss: {}
    )
}
