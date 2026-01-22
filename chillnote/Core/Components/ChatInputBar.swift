import SwiftUI

struct ChatInputBar: View {
    @Binding var text: String
    @Binding var isVoiceMode: Bool
    @ObservedObject var speechRecognizer: SpeechRecognizer
    
    var onSendText: () -> Void
    var onCancelVoice: () -> Void
    var onConfirmVoice: () -> Void
    var onCreateBlankNote: () -> Void
    
    @FocusState private var isTextFocused: Bool
    @State private var isRecordingPulsing = false
    @State private var showTextInput = false
    @State private var isPressed = false
    
    // Haptic generators
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        VStack(spacing: 0) {
            // Expandable Text Input (Secondary)
            if showTextInput {
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
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showTextInput = false
                            isTextFocused = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.textSub)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
// Main Voice-First Bar
            HStack(alignment: .center, spacing: 0) {
                // Central Voice Button (Primary)
                voiceCenterView
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - Central Voice View
    
    private var voiceCenterView: some View {
        Group {
            if speechRecognizer.isRecording {
                // Recording State
                recordingView
            } else if speechRecognizer.recordingState == .processing {
                // Processing State
                processingView
            } else if isErrorState() {
                // Error State
                if case .error(let message) = speechRecognizer.recordingState {
                    errorView(message: message)
                }
            } else {
                // Idle State - Main Mic Button
                idleVoiceButton
            }
        }
        .padding(.horizontal, isVoiceActive ? 16 : 0)
        .padding(.vertical, isVoiceActive ? 12 : 0)
        .background(
            ZStack {
                if isVoiceActive {
                    Capsule()
                        .fill(Color.white.opacity(0.95))
                        .background(Capsule().fill(.ultraThinMaterial))
                        .shadow(color: Color.black.opacity(0.1), radius: 15, x: 0, y: 5)
                }
            }
        )
        .frame(maxWidth: .infinity)
    }
    
    private var isVoiceActive: Bool {
        speechRecognizer.recordingState != .idle
    }
    
    private func isErrorState() -> Bool {
        if case .error = speechRecognizer.recordingState { return true }
        return false
    }
    
    private var idleVoiceButton: some View {
        ZStack {
            // Outer breathable ring
            Circle()
                .fill(Color.accentPrimary.opacity(0.1))
                .frame(width: 88, height: 88)
            
            // Main Button with Shadow
            Circle()
                .fill(Color.accentPrimary)
                .frame(width: 72, height: 72)
                .shadow(color: Color.accentPrimary.opacity(0.4), radius: 12, x: 0, y: 6)
            
            // Icon
            Image(systemName: "mic.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 88)
        .contentShape(Circle())
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .onTapGesture {
            impactGenerator.impactOccurred()
            speechRecognizer.startRecording()
        }
        .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = pressing
            }
        }, perform: {
            // Heavy haptic feedback for document creation
            let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
            heavyImpact.impactOccurred()
            
            // Reset scale
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = false
            }
            
            // Execute action
            onCreateBlankNote()
        })
    }
    
    private var recordingView: some View {
        HStack(spacing: 12) {
            // Cancel Button
            Button(action: {
                onCancelVoice()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.textSub)
                    .frame(width: 40, height: 40)
                    .background(Color.bgSecondary)
                    .clipShape(Circle())
            }
            
            // Recording Indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .opacity(isRecordingPulsing ? 1.0 : 0.3)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isRecordingPulsing)
                
                Text("Listening...")
                    .font(.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(.textMain)
            }
            .frame(maxWidth: .infinity)
            .onAppear { isRecordingPulsing = true }
            .onDisappear { isRecordingPulsing = false }
            
            // Confirm Button
            Button(action: {
                onConfirmVoice()
            }) {
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.accentPrimary)
                    .clipShape(Circle())
            }
        }
    }
    
    private var processingView: some View {
        // Processing state is now handled in the Note Detail View
        // We show the idle button (or minimal transition state) here
        // to prevent UI flash before navigation.
        return idleVoiceButton
            .disabled(true)
            .opacity(0.5)
    }
    
    private func errorView(message: String) -> some View {
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

#if DEBUG
struct ChatInputBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            ChatInputBar(
                text: .constant(""),
                isVoiceMode: .constant(true),
                speechRecognizer: SpeechRecognizer(),
                onSendText: {},
                onCancelVoice: {},
                onConfirmVoice: {},
                onCreateBlankNote: {}
            )
        }
        .background(Color.bgPrimary)
    }
}
#endif
