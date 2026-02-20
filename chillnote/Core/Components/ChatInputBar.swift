import SwiftUI

struct ChatInputBar: View {
    enum RecordTriggerMode {
        case releaseBased
        case tapToRecord
    }

    @Binding var text: String
    @Binding var isVoiceMode: Bool
    @ObservedObject var speechRecognizer: SpeechRecognizer
    @StateObject private var storeService = StoreService.shared

    var onSendText: () -> Void
    var onCancelVoice: () -> Void
    var onConfirmVoice: () -> Void
    var onCreateBlankNote: () -> Void
    var enforceVoiceQuota: Bool = true
    var recordTriggerMode: RecordTriggerMode = .releaseBased

    @FocusState private var isTextFocused: Bool
    @State private var showTextInput = false
    @State private var isPressed = false
    @State private var isLongPressing = false
    @State private var isBreathing = false
    @State private var waveformHeights: [CGFloat] = Array(repeating: 6, count: 5)
    @State private var pressStartTime: Date?

    @State private var elapsed: TimeInterval = 0
    @State private var didTriggerLimit = false
    @State private var showUpgradeSheet = false
    @State private var showSubscription = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let longPressThreshold: TimeInterval = 0.5

    private var timeText: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        let current = formatter.string(from: elapsed) ?? "00:00"
        let maxTime = formatter.string(from: storeService.recordingTimeLimit) ?? "01:00"
        return "\(current) / \(maxTime)"
    }

    private func openSubscriptionFromUpgrade() {
        showUpgradeSheet = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            showSubscription = true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
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
        .onReceive(timer) { _ in
            syncElapsed()

            if elapsed >= storeService.recordingTimeLimit, speechRecognizer.isRecording {
                if storeService.currentTier == .free && !didTriggerLimit {
                    didTriggerLimit = true
                    showUpgradeSheet = true
                }
                onConfirmVoice()
            }
        }
        .onChange(of: speechRecognizer.recordingState) { _, _ in
            syncElapsed()
            if speechRecognizer.recordingState == .recording {
                didTriggerLimit = false
            }
        }
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradeBottomSheet(
                title: String(localized: "Recording limit reached"),
                message: UpgradeBottomSheet.unifiedMessage,
                primaryButtonTitle: String(localized: "Upgrade to Pro"),
                onUpgrade: openSubscriptionFromUpgrade,
                onDismiss: { showUpgradeSheet = false }
            )
            .presentationDetents([.height(350)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
    }

    private var voiceCenterView: some View {
        ZStack {
            if speechRecognizer.isRecording {
                recordingGlassCapsule
                    .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .opacity))
            } else {
                idleGlassCapsule
            }
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: speechRecognizer.recordingState)
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
                    HStack(spacing: 8) {
                        Image(systemName: isLongPressing ? "plus" : "mic.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(isLongPressing ? .accentPrimary : .textMain)
                            .contentTransition(.symbolEffect(.replace))
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

    private func handlePressChanged(_ value: DragGesture.Value) {
        if pressStartTime == nil {
            pressStartTime = value.time
        }

        let duration = value.time.timeIntervalSince(pressStartTime ?? value.time)
        withAnimation(.spring(response: 0.3)) {
            isPressed = true
            isLongPressing = duration >= longPressThreshold
        }
    }

    private func handlePressEnded(_ value: DragGesture.Value) {
        let duration = value.time.timeIntervalSince(pressStartTime ?? value.time)
        let isLongPress = duration >= longPressThreshold
        resetPressState()

        if isLongPress {
            let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
            heavyImpact.impactOccurred()
            onCreateBlankNote()
        } else {
            let lightImpact = UIImpactFeedbackGenerator(style: .light)
            lightImpact.impactOccurred()
            tryStartRecordingWithQuotaCheck()
        }
    }

    private func handleTapRecord() {
        guard !speechRecognizer.isRecording else { return }
        let lightImpact = UIImpactFeedbackGenerator(style: .light)
        lightImpact.impactOccurred()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
            isPressed = true
            isLongPressing = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                isPressed = false
            }
        }
        tryStartRecordingWithQuotaCheck()
    }

    private func resetPressState() {
        pressStartTime = nil
        withAnimation {
            isPressed = false
            isLongPressing = false
        }
    }



    private func tryStartRecordingWithQuotaCheck() {
        guard enforceVoiceQuota else {
            speechRecognizer.startRecording(countsTowardQuota: false)
            return
        }

        Task {
            let canRecord = await storeService.checkDailyQuotaOnServer(feature: .voice)
            await MainActor.run {
                guard canRecord else {
                    showUpgradeSheet = true
                    return
                }
                speechRecognizer.startRecording(countsTowardQuota: true)
            }
        }
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
                onConfirmVoice: {},
                onCreateBlankNote: {}
            )
        }
        .background(Color.bgPrimary)
    }
}
#endif
