import SwiftUI

struct BouncyButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(
                reduceMotion ? .easeOut(duration: 0.08) : .spring(response: 0.28, dampingFraction: 0.68),
                value: configuration.isPressed
            )
            .onChange(of: configuration.isPressed) { _, newValue in
                if newValue, isEnabled {
                    AppInteractionFeedback.impact(.light, intensity: 0.72)
                }
            }
    }
}

struct TactileButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(
                reduceMotion ? .easeOut(duration: 0.08) : .spring(response: 0.24, dampingFraction: 0.82),
                value: configuration.isPressed
            )
            .onChange(of: configuration.isPressed) { _, newValue in
                if newValue, isEnabled {
                    AppInteractionFeedback.impact(.soft, intensity: 0.65)
                }
            }
    }
}

extension ButtonStyle where Self == BouncyButtonStyle {
    static var bouncy: BouncyButtonStyle {
        BouncyButtonStyle()
    }
}

extension ButtonStyle where Self == TactileButtonStyle {
    static var tactile: TactileButtonStyle {
        TactileButtonStyle()
    }
}
