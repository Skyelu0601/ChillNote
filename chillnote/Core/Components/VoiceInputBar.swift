import SwiftUI

/// A simple voice input bar component for recording audio
struct VoiceInputBar: View {
    @ObservedObject var speechRecognizer: SpeechRecognizer
    var onCancel: () -> Void
    var onConfirm: () -> Void
    
    @State private var isRecordingPulsing = false
    
    var body: some View {
            HStack(spacing: 12) {
                if speechRecognizer.isRecording {
                    // Recording State
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.textSub)
                            .frame(width: 44, height: 44)
                            .background(Color.bgSecondary)
                            .clipShape(Circle())
                    }
                    
                    HStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .opacity(isRecordingPulsing ? 1.0 : 0.3)
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isRecordingPulsing)
                        
                        Text("Recording...")
                            .font(.bodyMedium)
                            .foregroundColor(.textMain)
                    }
                    .frame(maxWidth: .infinity)
                    .onAppear { isRecordingPulsing = true }
                    .onDisappear { isRecordingPulsing = false }
                    
                    Button(action: onConfirm) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.textMain)
                            .frame(width: 44, height: 44)
                            .background(Color.accentPrimary)
                            .clipShape(Circle())
                    }
                } else if speechRecognizer.recordingState == .processing {
                    // Processing State
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Processing...")
                            .font(.bodyMedium)
                            .foregroundColor(.textSub)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 44)
                } else if case .error(let message) = speechRecognizer.recordingState {
                    // Error State
                    HStack {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.red)
                            .lineLimit(1)
                        
                        Button("Retry") {
                            speechRecognizer.startRecording()
                        }
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.accentPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
            }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Group {
                if speechRecognizer.recordingState != .idle {
                    Capsule()
                        .fill(Color.white.opacity(0.95))
                        .background(Capsule().fill(.ultraThinMaterial))
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        .padding(.horizontal, 8)
                }
            }
        )
    }
}

#Preview {
    VStack {
        Spacer()
        VoiceInputBar(
            speechRecognizer: SpeechRecognizer(),
            onCancel: {},
            onConfirm: {}
        )
    }
    .background(Color.bgPrimary)
}
