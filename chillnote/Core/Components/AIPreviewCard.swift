import SwiftUI

/// Compact AI preview card shown after AI content replacement.
struct AIPreviewCard: View {
    let onRetry: () -> Void
    let onUndo: () -> Void
    let onSave: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Card action buttons
            HStack(spacing: 4) {
                // Retry action
                Button(action: onRetry) {
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 18))
                        Text("Retry")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.accentPrimary)
                    .frame(width: 60, height: 50)
                }
                
                Divider()
                    .frame(height: 30)
                    .background(Color.textSub.opacity(0.2))

                // Undo action
                Button(action: onUndo) {
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 18))
                        Text("Undo")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.orange)
                    .frame(width: 60, height: 50)
                }
                
                Divider()
                    .frame(height: 30)
                    .background(Color.textSub.opacity(0.2))
                
                // Save action
                Button(action: onSave) {
                    VStack(spacing: 2) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18))
                        Text("Save")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.accentPrimary)
                    .frame(width: 60, height: 50)
                }
            }
            .padding(.trailing, 8)
        }
        .frame(height: 60)
        .background(
            ZStack {
                // Base background
                Color.white
                
                // Gradient accent on left
                LinearGradient(
                    colors: [
                        Color.mellowYellow.opacity(0.15),
                        Color.mellowOrange.opacity(0.1),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: -4)
    }
}

#Preview {
    ZStack {
        Color.bgPrimary.ignoresSafeArea()
        
        VStack {
            Spacer()
            AIPreviewCard(
                onRetry: { print("Retry") },
                onUndo: { print("Undo") },
                onSave: { print("Save") }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }
}
