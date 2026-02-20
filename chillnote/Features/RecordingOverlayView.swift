import SwiftUI
import UIKit

struct RecordingOverlayView: View {
    @ObservedObject var speechRecognizer: SpeechRecognizer
    var onDismiss: () -> Void
    var onSave: (String) async -> Void
    @State private var isProcessing = false
    @State private var bannerData: BannerData?
    @State private var startTime: Date?
    @State private var elapsed: TimeInterval = 0
    @State private var didTriggerStartHaptic = false
    @State private var pendingSave = false
    @State private var didTriggerLimit = false
    @State private var showUpgradeSheet = false
    @State private var showSubscription = false
    @State private var upgradeTitle = AppErrorCode.recordingLimitReached.message

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private func openSubscriptionFromUpgrade() {
        showUpgradeSheet = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            showSubscription = true
        }
    }
    
    var body: some View {
        ZStack {
            // Blur Background
            Color.white.opacity(0.9)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // Liquid Ripple Animation
                ZStack {
                    RippleView(isActive: speechRecognizer.isRecording, color: .accentPrimary)
                        .frame(width: 150, height: 150)
                    
                    Circle()
                        .fill(Color.accentPrimary)
                        .frame(width: 80, height: 80)
                        .scaleEffect(speechRecognizer.isRecording ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: speechRecognizer.isRecording)
                        .shadow(color: Color.accentPrimary.opacity(0.3), radius: 15, x: 0, y: 0)
                }
                .accessibilityHidden(true)
                .padding(.bottom, 40)
                
                Text(statusTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.textMain)
                    .accessibilityLabel(L10n.text("recording.accessibility.status_or_duration"))
                    .accessibilityValue(statusTitle)
                
                WaveformView(isActive: speechRecognizer.isRecording)
                    .padding(.top, 12)
                    .accessibilityHidden(true)
                
                // Live Transcript
                if speechRecognizer.permissionGranted {
                    ScrollView {
                        if case let .error(message) = speechRecognizer.recordingState {
                            VStack(spacing: 16) {
                                Text(displayErrorMessage(message))
                                    .font(.bodyMedium)
                                    .foregroundColor(.textMain)
                                    .multilineTextAlignment(.center)
                                
                                HStack(spacing: 24) {
                                    Button("Discard") {
                                        speechRecognizer.stopRecording(reason: .cancelled)
                                        // Force clear error state to close overlay if needed
                                        onDismiss()
                                    }
                                    .font(.bodyMedium)
                                    .foregroundColor(.red.opacity(0.8))
                                    
                                    Button("Retry Upload") {
                                        speechRecognizer.retryTranscription()
                                    }
                                    .font(.bodyMedium)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.accentPrimary)
                                }
                            }
                            .padding()
                        } else {
                            // User requested to hide real-time transcription
                            // Text(speechRecognizer.transcript.isEmpty ? "(Say something...)" : speechRecognizer.transcript)
                            //     .font(.bodyLarge)
                            //     .foregroundColor(.textMain)
                            //     .multilineTextAlignment(.center)
                            //     .padding()
                            if isProcessing {
                                VStack(spacing: 16) {
                                    ProgressView()
                                        .scaleEffect(1.5)
                                    VoiceProcessingWorkflowView(
                                        currentStage: .transcribing,
                                        style: .detailed,
                                        showPersistentHint: false
                                    )
                                }
                                .padding(.top, 20)
                            } else {
                                Text(speechRecognizer.transcript.isEmpty ? L10n.text("recording.listening_prompt") : " ")
                                    .font(.bodyLarge)
                                    .foregroundColor(.textSub)
                                    .padding()
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                } else {
                    VStack(spacing: 12) {
                        Text("Microphone and Speech access are required.")
                            .font(.bodyMedium)
                            .foregroundColor(.textMain)
                            .multilineTextAlignment(.center)
                        Button("Request Access") {
                            speechRecognizer.checkPermissions()
                        }
                        .font(.bodyMedium)
                        .foregroundColor(.accentPrimary)
                        .accessibilityHint("Requests microphone permission.")
                        Button("Open Settings") {
                            openSettings()
                        }
                        .font(.bodyMedium)
                        .foregroundColor(.accentPrimary)
                        .accessibilityHint("Opens system Settings for permissions.")
                    }
                    .padding(.horizontal, 32)
                }
                
                Spacer()
                
                // Controls
                Button(action: {
                    finishRecording()
                }) {
                    HStack {
                        if isProcessing {
                            EmptyView() // Spinner is in the middle now
                        } else {
                            Text("Done")
                        }
                    }
                    .font(.bodyMedium)
                    .fontWeight(.bold)
                    // Keep same frame/padding even if text changes
                    .frame(minWidth: 100) 
                    .padding(.vertical, 14)
                    .background(isProcessing ? Color.gray.opacity(0.3) : Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(30)
                }
                .buttonStyle(.bouncy)
                .disabled(isProcessing)
                .accessibilityLabel("Finish recording")
                .accessibilityHint("Stops recording and saves your note.")
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            startIfNeeded()
        }
        .onDisappear {
            if speechRecognizer.isRecording {
                speechRecognizer.stopRecording(reason: .cancelled)
            }
            // If overlay is dismissed while in error state, preserve the file
            // for recovery and clear the error so it doesn't leak to other views.
            if case .error = speechRecognizer.recordingState {
                speechRecognizer.dismissError()
            }
        }
        .onChange(of: speechRecognizer.permissionGranted) { _, newValue in
            if newValue {
                startIfNeeded()
            }
        }
        .onChange(of: speechRecognizer.recordingState) { _, newValue in
            switch newValue {
            case .recording:
                startTime = Date()
                elapsed = 0
                didTriggerLimit = false

                if !didTriggerStartHaptic {
                    didTriggerStartHaptic = true
                    impactHaptic(style: .medium)
                }
            case .processing:
                break
            case .idle:
                startTime = nil
                elapsed = 0
                didTriggerStartHaptic = false
                didTriggerLimit = false
                if pendingSave {
                    finalizeSave()
                }
            case .error(let message):
                if message.localizedCaseInsensitiveContains("daily free voice limit reached") {
                    upgradeTitle = AppErrorCode.recordingDailyLimitReached.message
                    showUpgradeSheet = true
                } else {
                    bannerData = BannerData(message: displayErrorMessage(message), style: .error)
                    notificationHaptic(type: .error)
                }
                

                
                if pendingSave {
                    pendingSave = false
                    isProcessing = false
                }
            }
        }
        .onReceive(timer) { _ in
            guard speechRecognizer.isRecording, let startTime = startTime else { return }
            elapsed = Date().timeIntervalSince(startTime)
            
            // Enforce limit based on subscription
            let limit = StoreService.shared.recordingTimeLimit
            if elapsed >= limit && !didTriggerLimit {
                didTriggerLimit = true
                if StoreService.shared.currentTier == .free {
                    upgradeTitle = AppErrorCode.recordingLimitReached.message
                    showUpgradeSheet = true
                }
                finishRecording()
            }
        }
        .onChange(of: speechRecognizer.shouldStop) { _, newValue in
            print("📍 shouldStop changed: \(newValue)")
            if newValue {
                print("📍 Calling stopRecording()")
                speechRecognizer.stopRecording()
                print("📍 After stopRecording()")
                speechRecognizer.shouldStop = false
            }
        }
        .banner(data: $bannerData)
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradeBottomSheet(
                title: upgradeTitle,
                message: UpgradeBottomSheet.unifiedMessage,
                primaryButtonTitle: L10n.text("subscription.upgrade_to_pro"),
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
    
    func finishRecording() {
        print("🔘 Done pressed, isProcessing=\(isProcessing)")
        guard !isProcessing else { return }
        pendingSave = true
        isProcessing = true
        print("📍 Setting shouldStop = true")
        speechRecognizer.shouldStop = true
        print("📍 shouldStop set to true")
    }

    private var statusTitle: String {
        if !speechRecognizer.permissionGranted {
            return AppErrorCode.recordingPermissionNeeded.message
        }
        switch speechRecognizer.recordingState {
        case .recording:
            return timeText
        case .processing:
            return AppErrorCode.recordingStateProcessing.message
        case .error:
            return AppErrorCode.recordingStateError.message
        case .idle:
            return AppErrorCode.recordingStateReady.message
        }
    }
    
    private var timeText: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        let current = formatter.string(from: elapsed) ?? "00:00"
        
        let limit = StoreService.shared.recordingTimeLimit
        let maxTime = formatter.string(from: limit) ?? "01:00"
        
        return "\(current) / \(maxTime)"
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func startIfNeeded() {
        guard speechRecognizer.permissionGranted, !speechRecognizer.isRecording else { return }
        Task { @MainActor in
            let canRecord = await StoreService.shared.checkDailyQuotaOnServer(feature: .voice)
            guard canRecord else {
                upgradeTitle = AppErrorCode.recordingDailyLimitReached.message
                showUpgradeSheet = true
                return
            }
            await Task.yield()
            speechRecognizer.startRecording(countsTowardQuota: true)
        }
    }

    private func finalizeSave() {
        pendingSave = false
        let trimmed = speechRecognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await onSave(trimmed)
            
            // Clean up the recording file after successful save
            speechRecognizer.completeRecording()
            
            // Analytics removed

            notificationHaptic(type: .success)
            
            isProcessing = false
            onDismiss()
        }
    }

    private func displayErrorMessage(_ message: String) -> String {
        if message.lowercased().contains("network error") {
            return AppErrorCode.recordingNetworkUnavailable.message
        }
        if message.lowercased().contains("timed out") || message.lowercased().contains("timeout") {
            return AppErrorCode.recordingTimeout.message
        }
        if message.lowercased().contains("transcription failed") {
            return AppErrorCode.recordingFailed.message
        }
        return message
    }

    private func impactHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    private func notificationHaptic(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}
