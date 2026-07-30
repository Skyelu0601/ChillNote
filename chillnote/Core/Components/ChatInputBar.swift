import SwiftUI
import UIKit

struct ChatInputBar: View {
    enum RecordTriggerMode {
        case releaseBased
        case tapToRecord
    }

    private enum QuickCaptureProgressState: Equatable {
        case link(QuickCaptureImportService.LinkImportPhase)

        var titleKey: String {
            switch self {
            case .link:
                return "quick_capture.import.link.title"
            }
        }

        var subtitleKey: String {
            switch self {
            case .link(.resolvingSource):
                return "quick_capture.import.link.phase.resolving"
            case .link(.fetchingContent):
                return "quick_capture.import.link.phase.fetching"
            case .link(.extractingContent):
                return "quick_capture.import.link.phase.extracting"
            case .link(.organizingNote):
                return "quick_capture.import.link.phase.organizing"
            case .link(.finalizing):
                return "quick_capture.import.link.phase.finalizing"
            }
        }

        var systemImageName: String {
            switch self {
            case .link:
                return "link.badge.plus"
            }
        }
    }

    @Binding var isVoiceMode: Bool
    @ObservedObject var speechRecognizer: SpeechRecognizer
    @StateObject private var storeService = StoreService.shared

    var onCancelVoice: () -> Void
    var onConfirmVoice: () -> Void
    var onPasteLink: (URL) -> Void = { _ in }
    var onCreateBlankNote: () -> Void = { }
    var enforceVoiceQuota: Bool = true
    var recordTriggerMode: RecordTriggerMode = .tapToRecord
    var highlightIdleMic: Bool = false

    @State private var captureErrorMessage: String?
    @State private var quickCaptureProgressState: QuickCaptureProgressState?
    @State private var showMissingLinkHint = false
    @State private var missingLinkHintTask: Task<Void, Never>?
    @State private var isPressed = false
    @State private var waveformHeights: [CGFloat] = Array(repeating: 6, count: 5)

    @State private var elapsed: TimeInterval = 0
    @State private var didTriggerLimit = false
    @State private var showSubscription = false
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
            HStack(alignment: .center, spacing: 0) {
                voiceCenterView
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 13)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .onAppear {
            syncElapsed()
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
            }
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
        .alert(L10n.text("quick_capture.error.title"), isPresented: captureErrorBinding) {
            Button(L10n.text("common.ok"), role: .cancel) { }
        } message: {
            Text(captureErrorMessage ?? "")
        }
    }

    private var voiceCenterView: some View {
        VStack(spacing: 10) {
            if speechRecognizer.isRecording {
                ghostPromptView
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if showMissingLinkHint {
                missingLinkHintView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            ZStack {
                if speechRecognizer.isRecording {
                    recordingGlassCapsule
                        .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .opacity))
                } else {
                    idleQuickCaptureDock
                }
            }
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: speechRecognizer.recordingState)
        .animation(.easeInOut(duration: 0.25), value: shouldShowFreeTierUpgradePrompt)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: showMissingLinkHint)
    }

    private var captureErrorBinding: Binding<Bool> {
        Binding(
            get: { captureErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    captureErrorMessage = nil
                }
            }
        )
    }

    private var ghostPromptView: some View {
        Button {
            showSubscription = true
        } label: {
            Text(L10n.text("recording.free_tier_prompt.longer_time"))
                .font(.bodySmall)
                .foregroundColor(.accentPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .frame(maxWidth: 320)
                .underline()
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
        }
        .buttonStyle(.plain)
        .opacity(shouldShowFreeTierUpgradePrompt ? 1 : 0)
        .accessibilityHidden(!shouldShowFreeTierUpgradePrompt)
        .accessibilityHint(L10n.text("recording.free_tier_prompt.longer_time_hint"))
        .allowsHitTesting(shouldShowFreeTierUpgradePrompt)
    }

    private var missingLinkHintView: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.accentPrimary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.accentPrimary.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.text("quick_capture.missing_link.title"))
                    .font(.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundColor(.textMain)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L10n.text("quick_capture.missing_link.subtitle"))
                    .font(.caption)
                    .foregroundColor(.textSub)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: 340, alignment: .leading)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.92))
                .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 5)
        .accessibilityElement(children: .combine)
    }

    private var idleQuickCaptureDock: some View {
        HStack(spacing: 12) {
            recordButton

            pasteLinkButton

            quickCaptureIconButton(
                systemName: "square.and.pencil",
                accessibilityKey: "quick_capture.accessibility.text",
                action: onCreateBlankNote
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .modifier(QuickCaptureDockSurface())
        .overlay {
            if isProcessingQuickCaptureImport {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.82))
                    .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                    .overlay {
                        quickCaptureProgressOverlay
                    }
            }
        }
        .opacity(isProcessingQuickCaptureImport ? 0.55 : 1)
        .allowsHitTesting(!isProcessingQuickCaptureImport)
    }

    private var quickCaptureProgressOverlay: some View {
        HStack(spacing: 12) {
            Image(systemName: quickCaptureProgressState?.systemImageName ?? "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.accentPrimary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color.accentPrimary.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.text(quickCaptureProgressState?.titleKey ?? "common.loading"))
                    .font(.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundColor(.textMain)
                    .lineLimit(1)

                Text(L10n.text(quickCaptureProgressState?.subtitleKey ?? "common.loading"))
                    .font(.caption)
                    .foregroundColor(.textSub)
                    .lineLimit(2)

                ProgressView()
                    .tint(.accentPrimary)
                    .controlSize(.small)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var recordButton: some View {
        Image(systemName: "mic.fill")
            .font(.system(size: 22, weight: .semibold))
            .foregroundColor(.textMain)
            .frame(width: 50, height: 50)
            .contentShape(Circle())
            .scaleEffect(isPressed ? 0.94 : 1)
        .modifier(RecordGestureModifier(
            recordTriggerMode: recordTriggerMode,
            onTapRecord: handleTapRecord,
            onChanged: handlePressChanged,
            onEnded: handlePressEnded
        ))
        .accessibilityLabel(L10n.text("quick_capture.accessibility.record"))
    }

    private var pasteLinkButton: some View {
        Button(action: handlePasteLink) {
            ZStack {
                Capsule(style: .continuous)
                    .fill(Color.borderSubtle)
                    .frame(width: 74, height: 50)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(highlightIdleMic ? Color.accentPrimary : Color.clear, lineWidth: 2)
                    )

                Image(systemName: "link")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundColor(.accentPrimary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.bouncy)
        .accessibilityLabel(L10n.text("quick_capture.more.paste_link.title"))
    }

    private func quickCaptureIconButton(
        systemName: String,
        accessibilityKey: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.textMain)
                .frame(width: 50, height: 50)
                .contentShape(Circle())
        }
        .buttonStyle(.bouncy)
        .accessibilityLabel(L10n.text(accessibilityKey))
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
        AppInteractionFeedback.impact(.light, intensity: 0.72)
        tryStartRecordingWithQuotaCheck()
    }

    private func handleTapRecord() {
        guard !speechRecognizer.isRecording else { return }
        AppInteractionFeedback.impact(.light, intensity: 0.72)
        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
            isPressed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                isPressed = false
            }
        }
        tryStartRecordingWithQuotaCheck()
    }

    private func handlePasteLink() {
        Task { @MainActor in
            let pastedText = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard let url = QuickCaptureLinkParser.extractCreatorMediaURL(from: pastedText) else {
                showMissingLinkGuidance()
                return
            }

            let hasCredits = await storeService.consumeCredits(feature: .import)
            guard hasCredits else {
                presentQuickCaptureUpgrade()
                return
            }

            onPasteLink(url)
        }
    }

    @MainActor
    private func showMissingLinkGuidance() {
        missingLinkHintTask?.cancel()
        UINotificationFeedbackGenerator().notificationOccurred(.warning)

        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            showMissingLinkHint = true
        }

        missingLinkHintTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                showMissingLinkHint = false
            }
        }
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

    private var shouldShowFreeTierUpgradePrompt: Bool {
        speechRecognizer.isRecording
            && storeService.currentTier == .free
            && speechRecognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isProcessingQuickCaptureImport: Bool {
        quickCaptureProgressState != nil
    }

    private func presentQuickCaptureUpgrade() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showSubscription = true
        }
    }
}

private struct QuickCaptureDockSurface: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: .capsule)
        } else {
            content
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.82))
                        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.black.opacity(0.035), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.07), radius: 14, x: 0, y: 6)
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
                isVoiceMode: .constant(true),
                speechRecognizer: SpeechRecognizer(),
                onCancelVoice: {},
                onConfirmVoice: {}
            )
        }
        .background(Color.bgPrimary)
    }
}
#endif
