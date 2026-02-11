import SwiftUI

struct ExportProgressView: View {
    let progress: ExportProgress
    let isExporting: Bool
    let onCancel: () -> Void

    private var percentageText: String {
        if progress.total <= 0 { return "0%" }
        return "\(Int(progress.fraction * 100))%"
    }

    private var elapsedText: String {
        let totalSeconds = Int(progress.elapsed.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(progress.message)
                        .font(.bodyMedium)
                        .foregroundColor(.textMain)
                    Text("\(progress.processed)/\(progress.total) • \(percentageText)")
                        .font(.bodySmall)
                        .foregroundColor(.textSub)
                }
                Spacer()
                Text(elapsedText)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.textSub)
            }

            ProgressView(value: progress.fraction)
                .progressViewStyle(.linear)
                .tint(.accentPrimary)

            if isExporting {
                Button(role: .cancel, action: onCancel) {
                    Text("Cancel Export")
                        .font(.bodyMedium)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding(16)
        .background(Color.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
