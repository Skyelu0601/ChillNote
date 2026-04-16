import SwiftUI
import UIKit

struct ChatInputBar: View {
    enum RecordTriggerMode {
        case releaseBased
        case tapToRecord
    }

    @Binding var text: String
    @Binding var isVoiceMode: Bool
    @ObservedObject var speechRecognizer: SpeechRecognizer
    @StateObject private var storeService = StoreService.shared
    @AppStorage("recording.has_seen_brain_dump_onboarding") private var hasSeenBrainDumpOnboarding = false

    var onSendText: () -> Void
    var onCancelVoice: () -> Void
    var onConfirmVoice: () -> Void
    var enforceVoiceQuota: Bool = true
    var recordTriggerMode: RecordTriggerMode = .tapToRecord
    var highlightIdleMic: Bool = false

    @FocusState private var isTextFocused: Bool
    @State private var showTextInput = false
    @State private var isPressed = false
    @State private var isBreathing = false
    @State private var waveformHeights: [CGFloat] = Array(repeating: 6, count: 5)

    @State private var elapsed: TimeInterval = 0
    @State private var didTriggerLimit = false
    @State private var showSubscription = false
    @State private var showBrainDumpOnboarding = false
    @State private var ghostPromptIndex = RecordingGhostPromptStore.randomIndex()
    @State private var isGhostPromptVisible = false
    @State private var ghostPromptDismissTask: Task<Void, Never>?
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var timeText: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        let current = formatter.string(from: elapsed) ?? "00:00"
        let maxTime = formatter.string(from: storeService.recordingTimeLimit) ?? "01:00"
        return "\(current) / \(maxTime)"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if showTextInput {
                HStack(alignment: .bottom, spacing: 8) {
                    TextField(L10n.text("chat_input.placeholder"), text: $text, axis: .vertical)
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

            HStack(alignment: .center, spacing: 0) {
                voiceCenterView
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .onAppear {
            syncElapsed()
        }
        .onDisappear {
            ghostPromptDismissTask?.cancel()
        }
        .onReceive(timer) { _ in
            syncElapsed()

            if elapsed >= storeService.recordingTimeLimit, speechRecognizer.isRecording {
                if storeService.currentTier == .free && !didTriggerLimit {
                    didTriggerLimit = true
                    showSubscription = true
                }
                onConfirmVoice()
            }
        }
        .onChange(of: speechRecognizer.recordingState) { _, _ in
            syncElapsed()
            if speechRecognizer.recordingState == .recording {
                didTriggerLimit = false
                showRandomGhostPrompt()
            } else {
                dismissGhostPrompt()
            }
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
        .sheet(isPresented: $showBrainDumpOnboarding) {
            BrainDumpOnboardingSheet(
                onStart: {
                    showBrainDumpOnboarding = false
                    tryStartRecordingWithQuotaCheck()
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var voiceCenterView: some View {
        VStack(spacing: 10) {
            if speechRecognizer.isRecording {
                ghostPromptView
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            ZStack {
                if speechRecognizer.isRecording {
                    recordingGlassCapsule
                        .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .opacity))
                } else {
                    idleGlassCapsule
                }
            }
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: speechRecognizer.recordingState)
        .animation(.easeInOut(duration: 0.25), value: shouldShowGhostPrompt)
    }

    private var ghostPromptView: some View {
        Text(RecordingGhostPromptStore.text(at: ghostPromptIndex))
            .font(.bodySmall)
            .foregroundColor(.textSub.opacity(0.78))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .frame(maxWidth: 300)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.86))
                    .background(.ultraThinMaterial, in: Capsule(style: .continuous))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
            .opacity(shouldShowGhostPrompt ? 1 : 0)
            .accessibilityHidden(!shouldShowGhostPrompt)
            .animation(.easeInOut(duration: 0.3), value: ghostPromptIndex)
    }

    private var idleGlassCapsule: some View {
        ZStack {
            Capsule()
                .fill(Color.accentPrimary)
                .frame(width: 80, height: 56)
                .rotationEffect(.degrees(isPressed ? 0 : 6))
                .offset(y: isPressed ? 2 : 4)
                .opacity(0.8)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)

            if isPressed {
                Image(systemName: "keyboard")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .offset(x: 28, y: 16)
                    .transition(.opacity)
            }

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

            Capsule()
                .fill(Color.bgPrimary)
                .frame(width: 90, height: 56)
                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
                .overlay(
                    Capsule()
                        .stroke(highlightIdleMic ? Color.accentPrimary : Color.clear, lineWidth: 2)
                )
                .shadow(
                    color: highlightIdleMic ? Color.accentPrimary.opacity(0.28) : .clear,
                    radius: 16,
                    y: 6
                )
                .overlay(
                    HStack(spacing: 8) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.textMain)
                    }
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .offset(y: isPressed ? 2 : 0)
        }
        .contentShape(Rectangle())
        .modifier(RecordGestureModifier(
            recordTriggerMode: recordTriggerMode,
            onTapRecord: handleTapRecord,
            onChanged: handlePressChanged,
            onEnded: handlePressEnded
        ))
    }

    private var recordingGlassCapsule: some View {
        ZStack {
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
                        Button(action: onCancelVoice) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.textSub)
                                .frame(width: 36, height: 36)
                                .background(Color.bgSecondary)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.bouncy)

                        VStack(spacing: 2) {
                            HStack(spacing: 3) {
                                ForEach(0..<5) { index in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.accentPrimary)
                                        .frame(width: 4, height: waveformHeights[index])
                                        .animation(.easeInOut(duration: 0.2), value: waveformHeights[index])
                                        .hueRotation(.degrees(elapsed * 5))
                                }
                            }
                            .frame(height: 24)
                            .onReceive(timer) { _ in
                                if speechRecognizer.isRecording {
                                    updateWaveform()
                                }
                            }

                            Text(timeText)
                                .font(.caption2)
                                .bold()
                                .foregroundColor(.accentPrimary)
                                .monospacedDigit()
                        }

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
        for i in 0..<5 {
            waveformHeights[i] = CGFloat.random(in: 4...20)
        }
    }

    private func syncElapsed() {
        guard speechRecognizer.isRecording,
              let startTime = speechRecognizer.recordingStartTime else {
            elapsed = 0
            return
        }
        elapsed = Date().timeIntervalSince(startTime)
    }

    private func handlePressChanged(_: DragGesture.Value) {
        withAnimation(.spring(response: 0.3)) {
            isPressed = true
        }
    }

    private func handlePressEnded(_: DragGesture.Value) {
        resetPressState()
        let lightImpact = UIImpactFeedbackGenerator(style: .light)
        lightImpact.impactOccurred()
        tryStartRecordingWithQuotaCheck()
    }

    private func handleTapRecord() {
        guard !speechRecognizer.isRecording else { return }
        let lightImpact = UIImpactFeedbackGenerator(style: .light)
        lightImpact.impactOccurred()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
            isPressed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                isPressed = false
            }
        }
        presentOnboardingOrStartRecording()
    }

    private func resetPressState() {
        withAnimation {
            isPressed = false
        }
    }



    private func tryStartRecordingWithQuotaCheck() {
        guard enforceVoiceQuota else {
            Task {
                _ = await speechRecognizer.startRecordingIfPermitted(countsTowardQuota: false)
            }
            return
        }

        Task {
            let hasConsent = await AIConsentManager.shared.ensureConsentIfNeeded(for: .audio)
            guard hasConsent else { return }

            let authorized = await storeService.authorizeVoiceRecordingStart()
            guard authorized else {
                await MainActor.run {
                    showSubscription = true
                }
                return
            }
            await MainActor.run {
                speechRecognizer.startRecording(countsTowardQuota: false)
            }
        }
    }

    private var shouldShowGhostPrompt: Bool {
        speechRecognizer.isRecording
            && isGhostPromptVisible
            && speechRecognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func presentOnboardingOrStartRecording() {
        guard !speechRecognizer.isRecording else { return }

        if hasSeenBrainDumpOnboarding {
            tryStartRecordingWithQuotaCheck()
            return
        }

        hasSeenBrainDumpOnboarding = true
        showBrainDumpOnboarding = true
    }

    private func showRandomGhostPrompt() {
        ghostPromptDismissTask?.cancel()
        ghostPromptIndex = RecordingGhostPromptStore.randomIndex()
        isGhostPromptVisible = true

        ghostPromptDismissTask = Task {
            let delay = UInt64(RecordingGhostPromptStore.displayDuration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isGhostPromptVisible = false
                }
            }
        }
    }

    private func dismissGhostPrompt() {
        ghostPromptDismissTask?.cancel()
        ghostPromptDismissTask = nil
        isGhostPromptVisible = false
    }
}

private struct RecordGestureModifier: ViewModifier {
    let recordTriggerMode: ChatInputBar.RecordTriggerMode
    let onTapRecord: () -> Void
    let onChanged: (DragGesture.Value) -> Void
    let onEnded: (DragGesture.Value) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        switch recordTriggerMode {
        case .tapToRecord:
            content.onTapGesture(perform: onTapRecord)
        case .releaseBased:
            content.gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onChanged(value)
                    }
                    .onEnded { value in
                        onEnded(value)
                    }
            )
        }
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
                onConfirmVoice: {}
            )
        }
        .background(Color.bgPrimary)
    }
}
#endif
