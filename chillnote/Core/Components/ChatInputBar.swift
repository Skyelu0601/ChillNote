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
    @State private var isLongPressing = false
    @State private var isBreathing = false
    @State private var waveformHeights: [CGFloat] = Array(repeating: 6, count: 5)
    
    @State private var elapsed: TimeInterval = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Haptic generators
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    private var timeText: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        let current = formatter.string(from: elapsed) ?? "00:00"
        return "\(current) / 10:00"
    }
    
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
                        .buttonStyle(.bouncy)
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
                    .buttonStyle(.bouncy)
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
        .onReceive(timer) { _ in
            guard speechRecognizer.isRecording, let startTime = speechRecognizer.recordingStartTime else { 
                if !speechRecognizer.isRecording {
                    elapsed = 0
                }
                return 
            }
            elapsed = Date().timeIntervalSince(startTime)
            
            // Enforce 10-minute limit
            if elapsed >= 600 {
                onConfirmVoice() // Auto-finish
            }
        }
        // Removed onChange that was resetting local startTime
    }

    
    // MARK: - Central Voice View
    
    // MARK: - Central Voice View
    
    private var voiceCenterView: some View {
        ZStack {
            if speechRecognizer.isRecording {
                // Recording State (Expanded Capsule)
                recordingGlassCapsule
                    .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .opacity))
            } else if speechRecognizer.recordingState == .processing {
                // Processing State
                 idleGlassCapsule
                    .opacity(0.6)
                    .overlay {
                        ProgressView()
                            .tint(.accentPrimary)
                    }
            } else if isErrorState() {
                // Error State
                if case .error(let message) = speechRecognizer.recordingState {
                    errorView(message: message)
                }
            } else {
                // Idle State - Glass Capsule
                idleGlassCapsule
            }
        }
        .padding(.top, 4) // Slight top offset to balance shadows
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: speechRecognizer.recordingState)
    }
    
    private var isVoiceActive: Bool {
        speechRecognizer.recordingState != .idle
    }
    
    private func isErrorState() -> Bool {
        if case .error = speechRecognizer.recordingState { return true }
        return false
    }
    
    // MARK: - New Components
    
    private var idleGlassCapsule: some View {
        ZStack {
            // 1. Back Layer (Brand Color / Hint)
            // Rotated to show a sliver of color ("4-6 degrees")
            Capsule()
                .fill(Color.accentPrimary)
                .frame(width: 80, height: 56)
                .rotationEffect(.degrees(isPressed ? 0 : 6)) // Align when pressed for "sinking" effect
                .offset(y: isPressed ? 2 : 4) // Subtle depth
                .opacity(0.8)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            
            // "Type" Hint Icon (Hidden behind, revealed slightly)
             if isPressed {
                Image(systemName: "keyboard")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .offset(x: 28, y: 16) // Positioned to peek out or be visible on layer
                    .transition(.opacity)
            }
            
            // 2. Glow / Breathing Aura
            if !isPressed {
                Capsule()
                    .fill(Color.accentPrimary.opacity(0.3))
                    .frame(width: 100, height: 76)
                    .blur(radius: 12)
                    .scaleEffect(isBreathing ? 1.1 : 0.95)
                    .opacity(isBreathing ? 0.4 : 0.1)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                            isBreathing = true
                        }
                    }
            }
            
            // 3. Front Layer (Glass/White)
            Capsule()
                .fill(Color.bgPrimary) // Solid background for clarity
                .frame(width: 90, height: 56)
                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
                .overlay(
                    HStack(spacing: 8) {
                        // Dynamic Icon: Changes to Plus on long press idea (simulated logic)
                        Image(systemName: isLongPressing ? "plus" : "mic.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(isLongPressing ? .accentPrimary : .textMain)
                            .contentTransition(.symbolEffect(.replace))
                    }
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .offset(y: isPressed ? 2 : 0) // Physical "press" movement
            
        }
        .contentShape(Rectangle()) // Hit area
        .onTapGesture {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            speechRecognizer.startRecording()
        }
        .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
            withAnimation(.spring(response: 0.3)) {
                isPressed = pressing
                if pressing { isLongPressing = true } // Start visual cue
                else { isLongPressing = false }
            }
        }, perform: {
            // Heavy haptic feedback for document creation
            let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
            heavyImpact.impactOccurred()
            
            // Reset visual states
            withAnimation {
                isPressed = false
                isLongPressing = false
            }
            
            // Execute action
            onCreateBlankNote()
        })
    }
    
    private var recordingGlassCapsule: some View {
        ZStack {
            // Glowing border/aura for recording
            Capsule()
                .fill(Color.accentPrimary.opacity(0.1))
                .frame(height: 64)
                .frame(maxWidth: .infinity)
                .blur(radius: 10)
            
            Capsule()
                .fill(Color.white)
                .frame(height: 56)
                .frame(maxWidth: .infinity)
                .shadow(color: Color.accentPrimary.opacity(0.15), radius: 12, x: 0, y: 8)
                .overlay(
                    HStack(spacing: 16) {
                        // Cancel Button (Left)
                        Button(action: onCancelVoice) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.textSub)
                                .frame(width: 36, height: 36)
                                .background(Color.bgSecondary)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.bouncy)
                        
                        // Center Info (Waveform + Time)
                        VStack(spacing: 2) {
                            // Pseudo Waveform
                             HStack(spacing: 3) {
                                ForEach(0..<5) { index in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.accentPrimary)
                                        .frame(width: 4, height: waveformHeights[index])
                                        .animation(.easeInOut(duration: 0.2), value: waveformHeights[index])
                                        .hueRotation(.degrees(elapsed * 5)) // Shift color over time
                                }
                            }
                            .frame(height: 24)
                            .onReceive(timer) { _ in
                                // Update waveform randomly
                                if speechRecognizer.isRecording {
                                     updateWaveform()
                                }
                            }
                            
                            // Timer
                             Text(timeText)
                                .font(.caption2)
                                .bold()
                                .foregroundColor(.accentPrimary)
                                .monospacedDigit()
                        }
                        
                        // Confirm Button (Right)
                        Button(action: onConfirmVoice) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(Color.accentPrimary)
                                        .shadow(color: .accentPrimary.opacity(0.4), radius: 6, y: 3)
                                )
                        }
                        .buttonStyle(.bouncy)
                    }
                    .padding(.horizontal, 12)
                )
        }
        .padding(.horizontal, 24)
    }
    
    private func updateWaveform() {
        // Randomize heights to simulate voice activity
        for i in 0..<5 {
            waveformHeights[i] = CGFloat.random(in: 4...20)
        }
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
            .buttonStyle(.bouncy)
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
