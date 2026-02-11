import SwiftUI

struct UpgradeBottomSheet: View {
    static let unifiedMessage = "Upgrade to Pro to unlock more with ChillNote."

    let title: String
    let message: String
    let primaryButtonTitle: String
    let onUpgrade: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Background with subtle gradient
            LinearGradient(
                colors: [Color.bgPrimary, Color.mellowYellow.opacity(0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Icon / Header
                Image("chillohead_touming")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 110)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                    .padding(.top, 24)
                
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.textMain)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.textSub)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                
                VStack(spacing: 12) {
                    Button(action: onUpgrade) {
                        HStack {
                            Text(primaryButtonTitle)
                            Image(systemName: "arrow.right")
                                .font(.caption).bold()
                        }
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [.accentPrimary, Color(hex: "E09040")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(18)
                        .shadow(color: .accentPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    Button(action: onDismiss) {
                        Text("Maybe Later")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.textSub)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
    }
}

#Preview {
    UpgradeBottomSheet(
        title: "Recording limit reached",
        message: UpgradeBottomSheet.unifiedMessage,
        primaryButtonTitle: "Upgrade to Pro",
        onUpgrade: {},
        onDismiss: {}
    )
}
