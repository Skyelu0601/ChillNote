import SwiftUI

struct MagicButton: View {
    // Action closure
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.chillYellow)
                    .frame(width: 72, height: 72)
                    .shadow(color: Color.chillYellow.opacity(0.5), radius: 20, x: 0, y: 10)
                
                Image(systemName: "mic.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.black)
            }
        }
        .buttonStyle(MagicButtonStyle())
        .accessibilityLabel("Start recording")
        .accessibilityHint("Opens the recording overlay.")
    }
}

private struct MagicButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    MagicButton(action: {})
        .padding()
}
