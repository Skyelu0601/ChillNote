import SwiftUI

/// Shared brand background used across onboarding and login so the visual
/// continues uninterrupted as the user transitions in.
struct BrandBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.bgPrimary,
                    Color.white.opacity(0.96),
                    Color.brandBlueSoft.opacity(0.45)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.accentPrimary.opacity(0.08))
                .frame(width: 240, height: 240)
                .blur(radius: 14)
                .offset(x: 138, y: -270)

            Circle()
                .fill(Color.accentPrimary.opacity(0.07))
                .frame(width: 210, height: 210)
                .blur(radius: 18)
                .offset(x: -140, y: 320)
        }
    }
}
