import SwiftUI

struct UpgradeBottomSheet: View {
    let content: PaywallContent
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

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Icon / Header
                    Image("coffee")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 110, height: 110)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                        .padding(.top, 24)
                    
                    Text(content.title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.textMain)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    if content.hasMessage {
                        Text(content.message)
                            .font(.subheadline)
                            .foregroundColor(.textSub)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(content.benefits, id: \.self) { benefit in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.accentPrimary)
                                    .padding(.top, 2)
                                Text(benefit)
                                    .font(.subheadline)
                                    .foregroundColor(.textMain)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    VStack(spacing: 12) {
                        Button(action: onUpgrade) {
                            HStack {
                                Text(content.primaryButtonTitle)
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
                            Text(content.secondaryButtonTitle)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.textSub)
                                .padding(.bottom, 4)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 8)
            }
        }
    }
}

#Preview {
    UpgradeBottomSheet(
        content: PaywallContext.recordingTimeLimit.content,
        onUpgrade: {},
        onDismiss: {}
    )
}
