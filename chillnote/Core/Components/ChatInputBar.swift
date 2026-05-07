import SwiftUI
import UIKit
import UniformTypeIdentifiers
@preconcurrency import Vision

struct ChatInputBar: View {
    enum RecordTriggerMode {
        case releaseBased
        case tapToRecord
    }

    private enum QuickCaptureProgressState: Equatable {
        case link(QuickCaptureImportService.LinkImportPhase)
        case image
        case media

        var titleKey: String {
            switch self {
            case .link:
                return "quick_capture.import.link.title"
            case .image:
                return "quick_capture.import.image.title"
            case .media:
                return "quick_capture.import.media.title"
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
            case .image:
                return "quick_capture.import.image.subtitle"
            case .media:
                return "quick_capture.import.media.subtitle"
            }
        }

        var systemImageName: String {
            switch self {
            case .link:
                return "link.badge.plus"
            case .image:
                return "text.viewfinder"
            case .media:
                return "waveform.badge.magnifyingglass"
            }
        }
    }

    @Binding var isVoiceMode: Bool
    @ObservedObject var speechRecognizer: SpeechRecognizer
    @StateObject private var storeService = StoreService.shared

    var onCancelVoice: () -> Void
    var onConfirmVoice: () -> Void
    var onPasteLink: (QuickCaptureImportService.LinkImportResult) -> Void = { _ in }
    var onImportImageText: (String) -> Void = { _ in }
    var onCreateBlankNote: () -> Void = { }
    var enforceVoiceQuota: Bool = true
    var recordTriggerMode: RecordTriggerMode = .tapToRecord
    var highlightIdleMic: Bool = false

    @State private var showMoreSheet = false
    @State private var showImageSourceDialog = false
    @State private var showMediaFileImporter = false
    @State private var imagePickerRoute: QuickCaptureImagePickerRoute?
    @State private var captureErrorMessage: String?
    @State private var isRecognizingImageText = false
    @State private var isImportingMedia = false
    @State private var quickCaptureProgressState: QuickCaptureProgressState?
    @State private var isPressed = false
    @State private var isBreathing = false
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
        .sheet(isPresented: $showMoreSheet) {
            QuickCaptureMoreSheet(
                onPasteLink: handlePasteLink,
                onPhotoOrImage: handlePhotoOrImage,
                onMediaFile: handleMediaFile
            )
            .presentationDetents([.height(390)])
        }
        .confirmationDialog(
            L10n.text("quick_capture.image_source.title"),
            isPresented: $showImageSourceDialog,
            titleVisibility: .visible
        ) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button(L10n.text("quick_capture.image_source.camera")) {
                    imagePickerRoute = QuickCaptureImagePickerRoute(sourceType: .camera)
                }
            }

            Button(L10n.text("quick_capture.image_source.photo_library")) {
                imagePickerRoute = QuickCaptureImagePickerRoute(sourceType: .photoLibrary)
            }

            Button(L10n.text("common.cancel"), role: .cancel) { }
        }
        .sheet(item: $imagePickerRoute) { route in
            QuickCaptureImagePicker(sourceType: route.sourceType) { image in
                Task {
                    await handleSelectedImage(image)
                }
            }
        }
        .fileImporter(
            isPresented: $showMediaFileImporter,
            allowedContentTypes: Self.importableMediaTypes,
            allowsMultipleSelection: false
        ) { result in
            handleSelectedMediaFile(result)
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

    private var idleQuickCaptureDock: some View {
        HStack(spacing: 14) {
            quickCaptureIconButton(
                systemName: "plus",
                accessibilityKey: "quick_capture.accessibility.more",
                action: {
                    showMoreSheet = true
                }
            )

            recordButton

            quickCaptureIconButton(
                systemName: "square.and.pencil",
                accessibilityKey: "quick_capture.accessibility.text",
                action: onCreateBlankNote
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.82))
                .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.black.opacity(0.035), lineWidth: 1)
        )
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
        .shadow(color: Color.black.opacity(0.07), radius: 14, x: 0, y: 6)
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
        ZStack {
            if !isPressed {
                Capsule()
                    .fill(Color.accentPrimary.opacity(0.25))
                    .frame(width: 94, height: 70)
                    .blur(radius: 12)
                    .scaleEffect(isBreathing ? 1.08 : 0.96)
                    .opacity(isBreathing ? 0.32 : 0.10)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                            isBreathing = true
                        }
                    }
            }

            Capsule(style: .continuous)
                .fill(Color.bgSecondary)
                .frame(width: 76, height: 56)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(highlightIdleMic ? Color.accentPrimary : Color.clear, lineWidth: 2)
                )
                .overlay(
                    Image(systemName: "mic.fill")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundColor(.textMain)
                )
                .scaleEffect(isPressed ? 0.94 : 1)
        }
        .contentShape(Rectangle())
        .modifier(RecordGestureModifier(
            recordTriggerMode: recordTriggerMode,
            onTapRecord: handleTapRecord,
            onChanged: handlePressChanged,
            onEnded: handlePressEnded
        ))
        .accessibilityLabel(L10n.text("quick_capture.accessibility.record"))
    }

    private func quickCaptureIconButton(
        systemName: String,
        accessibilityKey: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 23, weight: .semibold))
                .foregroundColor(.textMain)
                .frame(width: 54, height: 54)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
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
        tryStartRecordingWithQuotaCheck()
    }

    private func handlePasteLink() {
        guard canUseQuickCaptureMoreFeature else {
            presentQuickCaptureUpgrade()
            return
        }

        let pastedText = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let url = QuickCaptureLinkParser.extractWebURL(from: pastedText) else {
            captureErrorMessage = L10n.text("quick_capture.error.no_link")
            return
        }

        showMoreSheet = false
        quickCaptureProgressState = .link(.resolvingSource)

        Task {
            defer { quickCaptureProgressState = nil }

            do {
                let result = try await QuickCaptureImportService.shared.importWebLink(url) { phase in
                    await MainActor.run {
                        quickCaptureProgressState = .link(phase)
                    }
                }
                onPasteLink(result)
            } catch {
                captureErrorMessage = L10n.text("quick_capture.error.no_link")
            }
        }
    }

    private func handlePhotoOrImage() {
        guard canUseQuickCaptureMoreFeature else {
            presentQuickCaptureUpgrade()
            return
        }

        showMoreSheet = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            showImageSourceDialog = true
        }
    }

    private func handleMediaFile() {
        guard canUseQuickCaptureMoreFeature else {
            presentQuickCaptureUpgrade()
            return
        }

        showMoreSheet = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            showMediaFileImporter = true
        }
    }

    private func handleSelectedMediaFile(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await importMediaFile(from: url)
            }
        case .failure:
            captureErrorMessage = L10n.text("quick_capture.error.media_import_failed")
        }
    }

    private func importMediaFile(from url: URL) async {
        isImportingMedia = true
        quickCaptureProgressState = .media
        defer { isImportingMedia = false }
        defer { quickCaptureProgressState = nil }

        let didAccessSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        if let fileSizeInBytes = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           fileSizeInBytes > Self.maxImportableMediaBytes {
            captureErrorMessage = L10n.text(
                "quick_capture.error.media_file_too_large",
                Self.maxImportableMediaMB
            )
            return
        }

        do {
            let rawTranscript = try await GeminiService.shared.transcribeAudio(
                audioFileURL: url,
                countUsage: true
            )
            let noteText = try await QuickCaptureImportService.shared.makeMediaTranscriptNote(
                fileName: url.lastPathComponent,
                transcript: rawTranscript
            )
            onImportImageText(noteText)
        } catch {
            captureErrorMessage = L10n.text("quick_capture.error.media_import_failed")
        }
    }

    private func handleSelectedImage(_ image: UIImage) async {
        isRecognizingImageText = true
        quickCaptureProgressState = .image
        defer { isRecognizingImageText = false }
        defer { quickCaptureProgressState = nil }
        showMoreSheet = false

        do {
            guard let cgImage = image.cgImage else {
                captureErrorMessage = L10n.text("quick_capture.error.image_load_failed")
                return
            }

            let recognizedText = try await recognizeText(in: cgImage)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !recognizedText.isEmpty else {
                captureErrorMessage = L10n.text("quick_capture.error.no_image_text")
                return
            }

            let noteText = await QuickCaptureImportService.shared.makeImageTextNote(recognizedText)
            onImportImageText(noteText)
        } catch {
            captureErrorMessage = L10n.text("quick_capture.error.image_load_failed")
        }
    }

    private func recognizeText(in cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
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
        quickCaptureProgressState != nil || isRecognizingImageText || isImportingMedia
    }

    private var canUseQuickCaptureMoreFeature: Bool {
        storeService.currentTier == .pro
    }

    private func presentQuickCaptureUpgrade() {
        showMoreSheet = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showSubscription = true
        }
    }

    private static let importableMediaTypes: [UTType] = [
        .audio,
        .movie,
        .video,
        .mp3,
        .wav,
        .mpeg4Audio,
        .mpeg4Movie,
        .quickTimeMovie
    ]
    private static let maxImportableMediaMB = 100
    private static let maxImportableMediaBytes = maxImportableMediaMB * 1024 * 1024

}

private struct QuickCaptureImagePickerRoute: Identifiable {
    let id = UUID()
    let sourceType: UIImagePickerController.SourceType
}

private struct QuickCaptureImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_: UIImagePickerController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImagePicked: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImagePicked = onImagePicked
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_: UIImagePickerController) {
            dismiss()
        }
    }
}

private struct QuickCaptureMoreSheet: View {
    let onPasteLink: () -> Void
    let onPhotoOrImage: () -> Void
    let onMediaFile: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(L10n.text("quick_capture.more.title"))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.textMain)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.textSub)
                        .frame(width: 40, height: 40)
                        .background(Color.white)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.text("common.close"))
            }

            VStack(spacing: 0) {
                QuickCaptureMoreRow(
                    iconName: "link",
                    titleKey: "quick_capture.more.paste_link.title",
                    subtitleKey: "quick_capture.more.paste_link.subtitle",
                    action: onPasteLink
                )

                Divider()
                    .padding(.leading, 76)

                Button(action: onPhotoOrImage) {
                    QuickCaptureMoreRowContent(
                        iconName: "photo",
                        titleKey: "quick_capture.more.photo.title",
                        subtitleKey: "quick_capture.more.photo.subtitle"
                    )
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.leading, 76)

                Button(action: onMediaFile) {
                    QuickCaptureMoreRowContent(
                        iconName: "waveform.badge.magnifyingglass",
                        titleKey: "quick_capture.more.media.title",
                        subtitleKey: "quick_capture.more.media.subtitle"
                    )
                }
                .buttonStyle(.plain)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.bgSecondary.ignoresSafeArea())
    }
}

private struct QuickCaptureMoreRow: View {
    let iconName: String
    let titleKey: String
    let subtitleKey: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            QuickCaptureMoreRowContent(
                iconName: iconName,
                titleKey: titleKey,
                subtitleKey: subtitleKey
            )
        }
        .buttonStyle(.plain)
    }
}

private struct QuickCaptureMoreRowContent: View {
    let iconName: String
    let titleKey: String
    let subtitleKey: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: iconName)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.textMain)
                .frame(width: 48, height: 48)
                .background(Color.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.text(titleKey))
                    .font(.bodyLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(.textMain)

                Text(L10n.text(subtitleKey))
                    .font(.bodySmall)
                    .foregroundColor(.textSub)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.textSub.opacity(0.7))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
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
