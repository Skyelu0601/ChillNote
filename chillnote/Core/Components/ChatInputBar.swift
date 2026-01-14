import SwiftUI

struct ChatInputBar: View {
    @Binding var text: String
    @Binding var isVoiceMode: Bool
    @ObservedObject var speechRecognizer: SpeechRecognizer
    
    var onSendText: () -> Void
    var onCancelVoice: () -> Void
    var onConfirmVoice: () -> Void
    
    @FocusState private var isTextFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.gray.opacity(0.1))
            
            HStack(alignment: .bottom, spacing: 12) {
                // Mode Switch Button
                Button(action: {
                    withAnimation(.spring()) {
                        isVoiceMode.toggle()
                        if isVoiceMode {
                            isTextFocused = false
                        } else {
                            // If we were recording, cancel it
                            if speechRecognizer.isRecording {
                                speechRecognizer.stopRecording(reason: .cancelled)
                            }
                            // Auto-focus the text field when switching to text mode
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isTextFocused = true
                            }
                        }
                    }
                }) {
                    Image(systemName: isVoiceMode ? "keyboard" : "mic.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.textMain)
                        .frame(width: 44, height: 44)
                        .background(Color.bgSecondary)
                        .clipShape(Circle())
                }
                
                if isVoiceMode {
                    voiceInputView
                } else {
                    textInputView
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8) // This will be supplemented by the safe area
            .background(Color.white)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
        }
    }
    
    private var textInputView: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Type a note...", text: $text, axis: .vertical)
                .font(.bodyMedium)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.bgSecondary)
                .cornerRadius(20)
                .focused($isTextFocused)
                .lineLimit(1...5)
            
            if !text.isEmpty {
                Button(action: {
                    onSendText()
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.accentPrimary)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    private var voiceInputView: some View {
        HStack(spacing: 12) {
            if speechRecognizer.isRecording {
                // Recording State
                Button(action: {
                    onCancelVoice()
                }) {
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
                
                Button(action: {
                    onConfirmVoice()
                }) {
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
                    Text("Processing thought...")
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
            } else {
                // Idle State - Tap to Start
                Button(action: {
                    speechRecognizer.startRecording()
                }) {
                    Text("Tap to Speak")
                        .font(.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(.textMain)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.accentPrimary.opacity(0.1))
                        .cornerRadius(22)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(Color.accentPrimary, lineWidth: 1)
                        )
                }
            }
        }
    }
    
    @State private var isRecordingPulsing = false
}

#Preview {
    VStack {
        Spacer()
        ChatInputBar(
            text: .constant(""),
            isVoiceMode: .constant(false),
            speechRecognizer: SpeechRecognizer(),
            onSendText: {},
            onCancelVoice: {},
            onConfirmVoice: {}
        )
    }
    .background(Color.bgPrimary)
}
