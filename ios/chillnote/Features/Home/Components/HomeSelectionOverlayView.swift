import SwiftUI

struct HomeSelectionOverlayView: View {
    let isSelectionMode: Bool
    let selectedNotesCount: Int
    let onStartAIChat: () -> Void

    @State private var shouldShowSelectionHint = false

    var body: some View {
        if isSelectionMode {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    VStack(spacing: 12) {
                        if shouldShowSelectionHint && selectedNotesCount == 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.orange)

                                Text(L10n.text("home.selection_overlay.select_notes_hint"))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.textMain)
                                    .multilineTextAlignment(.leading)

                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.orange.opacity(0.22), lineWidth: 1)
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        Button(action: handleAskAIButtonTap) {
                            Text(L10n.text("home.selection_overlay.ask_ai"))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    LinearGradient(
                                        colors: [Color.accentPrimary, Color.accentPrimary.opacity(0.9)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(Capsule())
                                .shadow(color: Color.accentPrimary.opacity(0.35), radius: 10, x: 0, y: 5)
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 32)
                }
            }
            .onChange(of: selectedNotesCount) { _, newValue in
                if newValue > 0 {
                    shouldShowSelectionHint = false
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(100)
        }
    }

    private func handleAskAIButtonTap() {
        guard selectedNotesCount > 0 else {
            presentSelectionHint()
            return
        }
        onStartAIChat()
    }

    private func presentSelectionHint() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            shouldShowSelectionHint = true
        }
    }
}
