import SwiftUI

struct NoteDetailLightningBallButton: View {
    let action: () -> Void
    let isEnabled: Bool
    var size: CGFloat = 36

    var body: some View {
        Button(action: action) {
            NoteDetailLightningBallIcon(size: size)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
        .accessibilityLabel(L10n.text("note_detail.header.accessibility.ai_skills"))
    }
}

struct NoteDetailLightningBallIcon: View {
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.bgSecondary)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.brandBlue.opacity(0.10),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(2)

            Circle()
                .strokeBorder(Color.borderSubtle, lineWidth: 1)
                .padding(0.5)

            Image(systemName: "bolt.fill")
                .font(.system(size: size * 0.44, weight: .bold))
                .foregroundColor(.brandBlue)
                .shadow(color: Color.brandBlue.opacity(0.12), radius: 2, x: 0, y: 1)
                .rotationEffect(.degrees(4))
        }
        .frame(width: size, height: size)
        .shadow(color: Color.shadowColor, radius: 5, x: 0, y: 2)
        .overlay(
            Circle()
                .strokeBorder(Color.brandBlue.opacity(0.12), lineWidth: 0.5)
        )
        .contentShape(Circle())
    }
}
