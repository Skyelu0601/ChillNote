import SwiftUI

/// Lightweight notice for pending recordings
struct PendingRecordingsNotice: View {
    let pendingCount: Int
    let onOpenSettings: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.accentPrimary.opacity(0.12))
                        .frame(width: 64, height: 64)

                    Image(systemName: "waveform")
                        .font(.system(size: 28))
                        .foregroundColor(.accentPrimary)
                }

                Text("Unprocessed Recording")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.textMain)

                let countText = pendingCount == 1 ? "1 recording" : "\(pendingCount) recordings"
                Text("You have \(countText) waiting to be processed.")
                    .font(.bodyMedium)
                    .foregroundColor(.textSub)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button(action: onDismiss) {
                    Text("Later")
                        .font(.bodyMedium)
                        .foregroundColor(.textSub)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.gray.opacity(0.12))
                        .cornerRadius(14)
                }

                Button(action: onOpenSettings) {
                    Text("Open Settings")
                        .font(.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentPrimary)
                        .cornerRadius(14)
                }
            }
        }
        .padding(24)
        .background(Color.bgPrimary)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 10)
        .padding(.horizontal, 32)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()
        PendingRecordingsNotice(
            pendingCount: 2,
            onOpenSettings: {},
            onDismiss: {}
        )
    }
}
