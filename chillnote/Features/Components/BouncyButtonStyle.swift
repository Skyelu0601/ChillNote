import SwiftUI

struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, newValue in
                if newValue {
                    // Trigger a light haptic on press down
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
    }
}

extension ButtonStyle where Self == BouncyButtonStyle {
    static var bouncy: BouncyButtonStyle {
        BouncyButtonStyle()
    }
}
