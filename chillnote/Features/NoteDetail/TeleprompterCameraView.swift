@preconcurrency import AVFoundation
import Photos
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct TeleprompterCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var camera = TeleprompterCameraManager()

    @State private var scriptText: String
    @State private var scrollSpeed: Double = 24
    @State private var fontSize: Double = 24
    @State private var textColor: TeleprompterTextColor = .white
    @State private var teleprompterOffset: CGSize = .zero
    @State private var storedTeleprompterOffset: CGSize = .zero
    @State private var teleprompterScale: CGFloat = 1
    @State private var storedTeleprompterScale: CGFloat = 1
    @State private var showPromptSettings = false
    @State private var showCameraSettings = false
    @State private var showScriptEditor = false
    @State private var countdownSelection: TeleprompterCountdown = .three
    @State private var aspectRatio: TeleprompterAspectRatio = .vertical
    @State private var resolution: TeleprompterResolution = .hd1080
    @State private var draggedClip: TeleprompterClip?
    @State private var resetScriptScrollToken = UUID()
    @State private var showPermissionSettings = false
    @State private var previewRoute: TeleprompterExportRoute?

    init(initialScript: String) {
        _scriptText = State(initialValue: initialScript.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 18)
                    .padding(.top, 12)

                if showCameraSettings {
                    cameraSettingsPanel
                        .padding(.horizontal, 18)
                        .padding(.top, 10)
                }

                Spacer()
            }

            GeometryReader { proxy in
                TeleprompterFloatingPanel(
                    scriptText: scriptText.isEmpty ? L10n.text("teleprompter.script.empty_placeholder") : scriptText,
                    scrollSpeed: $scrollSpeed,
                    fontSize: fontSize,
                    textColor: textColor.color,
                    panelSize: teleprompterPanelSize(in: proxy.size),
                    isScrolling: camera.isRecording || showPromptSettings,
                    resetToken: resetScriptScrollToken,
                    onEdit: { showScriptEditor = true },
                    onSettings: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.86)) {
                            showPromptSettings.toggle()
                            showCameraSettings = false
                        }
                    }
                )
                .scaleEffect(teleprompterScale)
                .offset(
                    x: teleprompterOffset.width,
                    y: teleprompterOffset.height + cameraSettingsTeleprompterOffset(in: proxy.size)
                )
                .animation(.spring(response: 0.25, dampingFraction: 0.86), value: showCameraSettings)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let proposed = CGSize(
                                width: storedTeleprompterOffset.width + value.translation.width,
                                height: storedTeleprompterOffset.height + value.translation.height
                            )
                            teleprompterOffset = clampedTeleprompterOffset(proposed, in: proxy.size)
                        }
                        .onEnded { _ in
                            storedTeleprompterOffset = teleprompterOffset
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            teleprompterScale = min(max(storedTeleprompterScale * value, 0.78), 1.35)
                        }
                        .onEnded { _ in
                            storedTeleprompterScale = teleprompterScale
                            teleprompterOffset = clampedTeleprompterOffset(teleprompterOffset, in: proxy.size)
                            storedTeleprompterOffset = teleprompterOffset
                        }
                )
            }
            .ignoresSafeArea()

            VStack {
                Spacer()

                if showPromptSettings {
                    promptSettingsPanel
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18)
                }

                clipStripAndExport
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)

                recordControls
                    .padding(.bottom, 26)
            }

            if let value = camera.countdownValue {
                Text("\(value)")
                    .id(value)
                    .font(.system(size: 92, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.45), radius: 8, x: 0, y: 3)
                    .transition(.scale.combined(with: .opacity))
            }

            if camera.isExporting {
                exportingOverlay
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await camera.configureIfNeeded(resolution: resolution, flashMode: .off)
        }
        .onChange(of: resolution) { _, newValue in
            camera.updateResolution(newValue)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                camera.handleAppDeactivation()
            }
        }
        .onChange(of: camera.supportedResolutions) { _, supported in
            guard !supported.isEmpty, supported.contains(resolution) == false else { return }
            resolution = supported.first ?? .hd1080
        }
        .onChange(of: camera.permissionDenied) { _, denied in
            showPermissionSettings = denied
        }
        .onDisappear {
            camera.cleanup()
        }
        .sheet(isPresented: $showScriptEditor) {
            TeleprompterScriptEditorView(scriptText: $scriptText)
        }
        .sheet(item: $previewRoute) { route in
            TeleprompterExportPreviewView(videoURL: route.url)
        }
        .onChange(of: camera.exportedVideoURL) { _, newValue in
            if let newValue {
                previewRoute = newValue
                camera.exportedVideoURL = nil
            }
        }
        .alert(L10n.text("teleprompter.permission.title"), isPresented: $showPermissionSettings) {
            Button(L10n.text("common.cancel"), role: .cancel) {
                dismiss()
            }
            Button(L10n.text("teleprompter.permission.open_settings")) {
                camera.openAppSettings()
                dismiss()
            }
        } message: {
            Text(L10n.text("teleprompter.permission.message"))
        }
        .alert(L10n.text("teleprompter.error.title"), isPresented: Binding(
            get: { camera.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    camera.errorMessage = nil
                }
            }
        )) {
            Button(L10n.text("common.ok"), role: .cancel) { }
        } message: {
            Text(camera.errorMessage ?? "")
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.black.opacity(0.48)))
            }
            .accessibilityLabel(L10n.text("teleprompter.accessibility.close"))

            Spacer()

            Button {
                camera.switchCamera()
            } label: {
                Image(systemName: "camera.rotate")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.black.opacity(0.48)))
            }
            .accessibilityLabel(L10n.text("teleprompter.camera.switch"))
            .disabled(camera.isRecording || camera.isCountingDown)
            .opacity(camera.isRecording || camera.isCountingDown ? 0.45 : 1)

            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.86)) {
                    showCameraSettings.toggle()
                    showPromptSettings = false
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.black.opacity(0.48)))
            }
            .accessibilityLabel(L10n.text("teleprompter.accessibility.camera_settings"))
            .disabled(camera.isRecording || camera.isCountingDown)
            .opacity(camera.isRecording || camera.isCountingDown ? 0.45 : 1)
        }
        .overlay(alignment: .center) {
            if camera.isRecording {
                Text(camera.elapsedText)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.black.opacity(0.46)))
                    .allowsHitTesting(false)
            }
        }
    }

    private var cameraSettingsPanel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                segmentedSetting(
                    title: L10n.text("teleprompter.camera.countdown"),
                    values: TeleprompterCountdown.allCases,
                    selection: $countdownSelection
                )

                segmentedSetting(
                    title: L10n.text("teleprompter.camera.aspect_ratio"),
                    values: TeleprompterAspectRatio.allCases,
                    selection: $aspectRatio
                )

                segmentedSetting(
                    title: L10n.text("teleprompter.camera.resolution"),
                    values: camera.supportedResolutions.isEmpty ? TeleprompterResolution.allCases : camera.supportedResolutions,
                    selection: $resolution
                )
            }
            .padding(14)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.56))
        )
    }

    private var promptSettingsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            sliderRow(
                title: L10n.text("teleprompter.prompt.speed"),
                leading: L10n.text("teleprompter.prompt.slow"),
                trailing: L10n.text("teleprompter.prompt.fast"),
                value: $scrollSpeed,
                range: 0...50
            )

            sliderRow(
                title: L10n.text("teleprompter.prompt.font_size"),
                leading: L10n.text("teleprompter.prompt.small"),
                trailing: L10n.text("teleprompter.prompt.large"),
                value: $fontSize,
                range: 16...36
            )

            HStack(spacing: 10) {
                Text(L10n.text("teleprompter.prompt.text_color"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 88, alignment: .leading)

                ForEach(TeleprompterTextColor.allCases) { option in
                    Button {
                        textColor = option
                    } label: {
                        Circle()
                            .fill(option.color)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(textColor == option ? Color.white : Color.clear, lineWidth: 3)
                            )
                    }
                    .accessibilityLabel(option.localizedName)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.62))
        )
    }

    private var clipStripAndExport: some View {
        HStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(camera.clips) { clip in
                        TeleprompterClipThumbnailView(
                            clip: clip,
                            onTap: { previewRoute = TeleprompterExportRoute(url: clip.url) },
                            onDelete: { camera.removeClip(clip) }
                        )
                        .onDrag {
                            draggedClip = clip
                            let provider = NSItemProvider()
                            provider.registerDataRepresentation(
                                forTypeIdentifier: TeleprompterDragType.clip.identifier,
                                visibility: .ownProcess
                            ) { completion in
                                completion(clip.id.uuidString.data(using: .utf8), nil)
                                return nil
                            }
                            return provider
                        }
                        .onDrop(
                            of: [TeleprompterDragType.clip],
                            delegate: TeleprompterClipDropDelegate(
                                item: clip,
                                clips: $camera.clips,
                                draggedClip: $draggedClip
                            )
                        )
                    }
                }
                .padding(.top, 10)
                .padding(.trailing, 12)
                .padding(.leading, 2)
            }
            .frame(height: camera.clips.isEmpty ? 0 : 84)

            Spacer(minLength: 0)
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.88), value: camera.clips.map(\.id))
    }

    private var recordControls: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    if camera.isCountingDown {
                        camera.cancelCountdown()
                    } else if camera.isRecording {
                        camera.stopRecording()
                    } else {
                        resetScriptScrollToken = UUID()
                        await camera.startRecording(countdown: countdownSelection)
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 78, height: 78)
                    Image(systemName: camera.isRecording || camera.isCountingDown ? "stop.fill" : "video.fill")
                        .font(.system(size: camera.isRecording || camera.isCountingDown ? 24 : 22, weight: .bold))
                        .foregroundColor(Color.accentPrimary)
                }
            }
            .disabled(camera.isExporting)
            .accessibilityLabel(camera.isRecording ? L10n.text("teleprompter.accessibility.stop_recording") : L10n.text("teleprompter.accessibility.start_recording"))
            .frame(maxWidth: .infinity)
            .overlay(alignment: .trailing) {
                if camera.clips.isEmpty == false {
                    Button {
                        previewClips()
                    } label: {
                        Label(L10n.text("teleprompter.action.preview"), systemImage: "play.rectangle")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .frame(height: 48)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentPrimary))
                    }
                    .disabled(camera.isRecording || camera.isCountingDown || camera.isExporting)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func previewClips() {
        guard camera.isRecording == false, camera.isCountingDown == false, camera.isExporting == false else { return }
        guard !camera.clips.isEmpty else { return }
        Task {
            await camera.exportMergedVideo(aspectRatio: aspectRatio)
        }
    }

    private func resetTeleprompterPosition() {
        camera.resetTeleprompterElapsed()
        resetScriptScrollToken = UUID()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            teleprompterOffset = .zero
            storedTeleprompterOffset = .zero
            teleprompterScale = 1
            storedTeleprompterScale = 1
        }
    }

    private func clampedTeleprompterOffset(_ proposed: CGSize, in container: CGSize) -> CGSize {
        let horizontalLimit = max(container.width * 0.38, 80)
        let verticalLimit = max(container.height * 0.3, 120)
        return CGSize(
            width: min(max(proposed.width, -horizontalLimit), horizontalLimit),
            height: min(max(proposed.height, -verticalLimit), verticalLimit)
        )
    }

    private func teleprompterPanelSize(in container: CGSize) -> CGSize {
        CGSize(
            width: container.width - 32,
            height: min(max(container.height * 0.34, 220), 330)
        )
    }

    private func cameraSettingsTeleprompterOffset(in container: CGSize) -> CGFloat {
        guard showCameraSettings else { return 0 }
        return min(max(container.height * 0.18, 120), 170)
    }

    private var exportingOverlay: some View {
        VStack(spacing: 14) {
            ProgressView(value: camera.exportProgress)
                .tint(.white)
            Text(L10n.text("teleprompter.export.processing"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            Text("\(Int((camera.exportProgress * 100).rounded()))%")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.72))
        }
        .padding(22)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.72)))
    }

    private func sliderRow(
        title: String,
        leading: String,
        trailing: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Text("\(Int(value.wrappedValue.rounded()))")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(minWidth: 34, alignment: .trailing)
            }

            HStack(spacing: 12) {
                Text(leading)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.64))

                Slider(value: value, in: range)
                    .tint(Color.accentPrimary)

                Text(trailing)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.64))
            }
        }
    }

    private func segmentedSetting<T: TeleprompterSettingOption>(
        title: String,
        values: [T],
        selection: Binding<T>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
            HStack(spacing: 6) {
                ForEach(values) { value in
                    Button {
                        selection.wrappedValue = value
                    } label: {
                        Text(value.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(selection.wrappedValue.id == value.id ? .black : .white)
                            .padding(.horizontal, 10)
                            .frame(height: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(selection.wrappedValue.id == value.id ? Color.white : Color.white.opacity(0.14))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(camera.isRecording || camera.isCountingDown)
                }
            }
        }
        .opacity(camera.isRecording || camera.isCountingDown ? 0.45 : 1)
    }
}

@MainActor
private final class TeleprompterCameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    @Published var isRecording = false
    @Published var isCountingDown = false
    @Published var elapsed: TimeInterval = 0
    @Published var clips: [TeleprompterClip] = []
    @Published var countdownValue: Int?
    @Published var errorMessage: String?
    @Published var isExporting = false
    @Published var exportProgress: Double = 0
    @Published var exportedVideoURL: TeleprompterExportRoute?
    @Published var supportedResolutions: [TeleprompterResolution] = TeleprompterResolution.allCases
    @Published var permissionDenied = false

    private let movieOutput = AVCaptureMovieFileOutput()
    private var activeInput: AVCaptureDeviceInput?
    private var currentCameraPosition: AVCaptureDevice.Position = .front
    private var configured = false
    private var recordingStartDate: Date?
    private var elapsedTimer: Timer?
    private var pendingClipURL: URL?
    private var exportedTempURL: URL?
    private var resolution: TeleprompterResolution = .hd1080
    private var flashMode: TeleprompterFlashMode = .off
    private var countdownTask: Task<Void, Never>?
    private var notificationObservers: [NSObjectProtocol] = []
    private var isCleaningUp = false
    private let maxClipCount = 24
    private let minimumFreeDiskBytes: Int64 = 250 * 1024 * 1024
    private let sessionQueue = DispatchQueue(label: "com.chillnote.teleprompter.session", qos: .userInitiated)

    override init() {
        super.init()
        installObservers()
    }

    deinit {
        countdownTask?.cancel()
        elapsedTimer?.invalidate()
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        let session = session
        sessionQueue.async {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    var elapsedText: String {
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func configureIfNeeded(resolution: TeleprompterResolution, flashMode: TeleprompterFlashMode) async {
        guard !configured else { return }
        self.resolution = resolution
        self.flashMode = flashMode
        permissionDenied = false

        let hasCamera = await requestVideoAccess()
        let hasMic = await requestAudioAccess()
        guard hasCamera, hasMic else {
            errorMessage = L10n.text("teleprompter.error.permission_required")
            permissionDenied = true
            return
        }

        configureAudioSession()
        configured = true
        configureSession()
    }

    func startRecording(countdown: TeleprompterCountdown) async {
        guard configured else {
            errorMessage = L10n.text("teleprompter.error.camera_unavailable")
            return
        }
        guard !isRecording else { return }
        guard countdownTask == nil else { return }

        countdownTask = Task { [weak self] in
            guard let self else { return }
            if countdown.seconds > 0 {
                isCountingDown = true
                for value in stride(from: countdown.seconds, through: 1, by: -1) {
                    guard !Task.isCancelled else {
                        self.countdownValue = nil
                        self.isCountingDown = false
                        self.countdownTask = nil
                        return
                    }
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                        self.countdownValue = value
                    }
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
                withAnimation {
                    self.countdownValue = nil
                }
                isCountingDown = false
            }
            countdownTask = nil
            guard !Task.isCancelled else { return }
            beginRecordingNow()
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        movieOutput.stopRecording()
    }

    func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        countdownValue = nil
        isCountingDown = false
    }

    func resetTeleprompterElapsed() {
        elapsed = 0
        recordingStartDate = Date()
    }

    func switchCamera() {
        guard !isRecording, !isCountingDown else { return }
        currentCameraPosition = currentCameraPosition == .front ? .back : .front
        replaceVideoInput()
    }

    func updateResolution(_ next: TeleprompterResolution) {
        guard !isRecording, !isCountingDown else { return }
        guard session.canSetSessionPreset(next.sessionPreset) else {
            supportedResolutions = TeleprompterResolution.allCases.filter { session.canSetSessionPreset($0.sessionPreset) }
            return
        }
        resolution = next
        session.beginConfiguration()
        session.sessionPreset = next.sessionPreset
        session.commitConfiguration()
    }

    func updateFlashMode(_ next: TeleprompterFlashMode) {
        guard !isRecording, !isCountingDown else { return }
        flashMode = next
        applyTorchMode()
    }

    func removeClip(_ clip: TeleprompterClip) {
        clips.removeAll { $0.id == clip.id }
        try? FileManager.default.removeItem(at: clip.url)
    }

    func resetClips() {
        for clip in clips {
            try? FileManager.default.removeItem(at: clip.url)
        }
        clips.removeAll()
    }

    func exportMergedVideo(aspectRatio: TeleprompterAspectRatio) async {
        guard !clips.isEmpty else { return }
        isExporting = true
        exportProgress = 0
        defer { isExporting = false }

        do {
            let url = try await TeleprompterVideoComposer.merge(clips: clips, aspectRatio: aspectRatio) { [weak self] progress in
                Task { @MainActor in
                    self?.exportProgress = progress
                }
            }
            if let exportedTempURL {
                try? FileManager.default.removeItem(at: exportedTempURL)
            }
            exportedTempURL = url
            exportedVideoURL = TeleprompterExportRoute(url: url)
            exportProgress = 1
        } catch {
            errorMessage = L10n.text("teleprompter.error.export_failed")
        }
    }

    func handleAppDeactivation() {
        cancelCountdown()
        if isRecording {
            stopRecording()
            errorMessage = L10n.text("teleprompter.error.recording_interrupted")
        }
    }

    func cleanup() {
        guard !isCleaningUp else { return }
        isCleaningUp = true
        cancelCountdown()
        if isRecording {
            movieOutput.stopRecording()
        }
        stopElapsedTimer()
        let session = session
        sessionQueue.async {
            if session.isRunning {
                session.stopRunning()
            }
        }
        resetClips()
        if let pendingClipURL {
            try? FileManager.default.removeItem(at: pendingClipURL)
            self.pendingClipURL = nil
        }
        if let exportedTempURL {
            try? FileManager.default.removeItem(at: exportedTempURL)
            self.exportedTempURL = nil
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func requestVideoAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    private func requestAudioAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }

    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playAndRecord,
                mode: .videoRecording,
                options: [.defaultToSpeaker, .allowBluetoothHFP, .allowBluetoothA2DP, .mixWithOthers]
            )
            try audioSession.setActive(true)
        } catch {
            errorMessage = L10n.text("teleprompter.error.audio_session_failed")
        }
    }

    private func beginRecordingNow() {
        guard configured, !isRecording else { return }
        guard clips.count < maxClipCount else {
            errorMessage = L10n.text("teleprompter.error.too_many_clips")
            return
        }
        guard hasEnoughTemporaryDiskSpace() else {
            errorMessage = L10n.text("teleprompter.error.low_storage")
            return
        }
        configureAudioSession()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("chillnote-teleprompter-\(UUID().uuidString)")
            .appendingPathExtension("mov")
        pendingClipURL = outputURL

        guard session.isRunning else {
            let session = session
            sessionQueue.async { [weak self] in
                session.startRunning()
                DispatchQueue.main.async {
                    self?.startMovieRecording(to: outputURL)
                }
            }
            return
        }

        startMovieRecording(to: outputURL)
    }

    private func startMovieRecording(to outputURL: URL) {
        guard !isCleaningUp, pendingClipURL == outputURL, movieOutput.isRecording == false else { return }
        if let connection = movieOutput.connection(with: .video), connection.isVideoMirroringSupported {
            connection.isVideoMirrored = currentCameraPosition == .front
        }
        movieOutput.startRecording(to: outputURL, recordingDelegate: self)

        recordingStartDate = Date()
        elapsed = 0
        isRecording = true
        startElapsedTimer()
    }

    private func configureSession() {
        session.beginConfiguration()
        if session.canSetSessionPreset(resolution.sessionPreset) {
            session.sessionPreset = resolution.sessionPreset
        }

        replaceVideoInput()
        addAudioInputIfNeeded()

        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }
        movieOutput.maxRecordedDuration = CMTime.invalid

        session.commitConfiguration()
        let supported = TeleprompterResolution.allCases.filter { session.canSetSessionPreset($0.sessionPreset) }
        supportedResolutions = supported.isEmpty ? TeleprompterResolution.allCases : supported
        let runningSession = session
        sessionQueue.async {
            runningSession.startRunning()
        }
    }

    private func hasEnoughTemporaryDiskSpace() -> Bool {
        let temporaryDirectory = FileManager.default.temporaryDirectory
        guard let values = try? temporaryDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let capacity = values.volumeAvailableCapacityForImportantUsage
        else {
            return true
        }
        return capacity > minimumFreeDiskBytes
    }

    private func replaceVideoInput() {
        session.beginConfiguration()
        if let activeInput {
            session.removeInput(activeInput)
        }

        if let device = cameraDevice(position: currentCameraPosition),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
            activeInput = input
        }

        session.commitConfiguration()
        applyTorchMode()
    }

    private func addAudioInputIfNeeded() {
        guard session.inputs.contains(where: { ($0 as? AVCaptureDeviceInput)?.device.hasMediaType(.audio) == true }) == false,
              let device = AVCaptureDevice.default(for: .audio),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else {
            return
        }
        session.addInput(input)
    }

    private func cameraDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }

    private func applyTorchMode() {
        guard currentCameraPosition == .back,
              let device = activeInput?.device,
              device.hasTorch
        else {
            return
        }

        do {
            try device.lockForConfiguration()
            switch flashMode {
            case .off:
                device.torchMode = .off
            case .on:
                try? device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
            case .auto:
                device.torchMode = .auto
            }
            device.unlockForConfiguration()
        } catch {
            errorMessage = L10n.text("teleprompter.error.flash_unavailable")
        }
    }

    private func startElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let start = self.recordingStartDate else { return }
                self.elapsed = Date().timeIntervalSince(start)
            }
        }
        if let elapsedTimer {
            RunLoop.main.add(elapsedTimer, forMode: .common)
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    private func installObservers() {
        let center = NotificationCenter.default
        notificationObservers.append(
            center.addObserver(
                forName: AVCaptureSession.wasInterruptedNotification,
                object: session,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleCaptureInterruption()
                }
            }
        )
        notificationObservers.append(
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: AVAudioSession.sharedInstance(),
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor in
                    self?.handleAudioInterruption(notification)
                }
            }
        )
    }

    private func handleCaptureInterruption() {
        if isRecording {
            stopRecording()
            errorMessage = L10n.text("teleprompter.error.recording_interrupted")
        }
    }

    private func handleAudioInterruption(_ notification: Notification) {
        guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType)
        else {
            return
        }
        switch type {
        case .began:
            handleAppDeactivation()
        case .ended:
            configureAudioSession()
        @unknown default:
            break
        }
    }
}

extension TeleprompterCameraManager: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor in
            self.isRecording = false
            self.stopElapsedTimer()
            self.pendingClipURL = nil

            if error != nil {
                self.errorMessage = L10n.text("teleprompter.error.record_failed")
                try? FileManager.default.removeItem(at: outputFileURL)
                return
            }

            let thumbnail = TeleprompterVideoComposer.thumbnail(for: outputFileURL)
            let duration = await TeleprompterVideoComposer.duration(for: outputFileURL)
            self.clips.append(TeleprompterClip(url: outputFileURL, thumbnail: thumbnail, duration: duration))
        }
    }
}

private enum TeleprompterVideoComposer {
    static func duration(for url: URL) async -> TimeInterval {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else {
            return 0
        }
        return CMTimeGetSeconds(duration)
    }

    static func thumbnail(for url: URL) -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        guard let image = try? generator.copyCGImage(at: .zero, actualTime: nil) else {
            return nil
        }
        return UIImage(cgImage: image)
    }

    static func merge(
        clips: [TeleprompterClip],
        aspectRatio: TeleprompterAspectRatio,
        onProgress: @escaping (Double) -> Void
    ) async throws -> URL {
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw TeleprompterExportError.cannotCreateTrack
        }
        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        var cursor = CMTime.zero
        var sourceVideoInfos: [TeleprompterSourceVideoInfo] = []
        var frameDuration = CMTime(value: 1, timescale: 30)

        for clip in clips {
            let asset = AVURLAsset(url: clip.url)
            let duration = try await asset.load(.duration)

            if let sourceVideo = try await asset.loadTracks(withMediaType: .video).first {
                try videoTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: sourceVideo,
                    at: cursor
                )
                let nominalFrameRate = try await sourceVideo.load(.nominalFrameRate)
                if nominalFrameRate > 0 {
                    frameDuration = CMTime(value: 1, timescale: CMTimeScale(nominalFrameRate.rounded()))
                }
                sourceVideoInfos.append(
                    TeleprompterSourceVideoInfo(
                        track: sourceVideo,
                        duration: duration,
                        start: cursor
                    )
                )
            }

            if let sourceAudio = try await asset.loadTracks(withMediaType: .audio).first {
                try audioTrack?.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: sourceAudio,
                    at: cursor
                )
            }
            cursor = cursor + duration
        }

        let renderSize = aspectRatio.renderSize
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = frameDuration

        var instructions: [AVMutableVideoCompositionInstruction] = []

        for info in sourceVideoInfos {
            let sourceTrack = info.track
            let sourceSize = try await sourceTrack.load(.naturalSize).applying(try await sourceTrack.load(.preferredTransform))
            let cleanSize = CGSize(width: abs(sourceSize.width), height: abs(sourceSize.height))

            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: info.start, duration: info.duration)
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)

            let preferredTransform = try await sourceTrack.load(.preferredTransform)
            let scale = max(renderSize.width / cleanSize.width, renderSize.height / cleanSize.height)
            let scaledSize = CGSize(width: cleanSize.width * scale, height: cleanSize.height * scale)
            let x = (renderSize.width - scaledSize.width) / 2
            let y = (renderSize.height - scaledSize.height) / 2
            let transform = preferredTransform
                .concatenating(CGAffineTransform(scaleX: scale, y: scale))
                .concatenating(CGAffineTransform(translationX: x, y: y))

            layerInstruction.setTransform(transform, at: info.start)
            instruction.layerInstructions = [layerInstruction]
            instructions.append(instruction)
        }

        videoComposition.instructions = instructions

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("chillnote-teleprompter-export-\(UUID().uuidString)")
            .appendingPathExtension("mp4")

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw TeleprompterExportError.cannotCreateExportSession
        }
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.videoComposition = videoComposition

        let progressTask = Task {
            while !Task.isCancelled {
                onProgress(Double(exportSession.progress))
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
        }

        do {
            if #available(iOS 18.0, *) {
                try await exportSession.export(to: outputURL, as: .mp4)
            } else {
                try await exportLegacy(exportSession)
            }
            progressTask.cancel()
            onProgress(1)
            return outputURL
        } catch {
            progressTask.cancel()
            try? FileManager.default.removeItem(at: outputURL)
            throw error
        }
    }

    private static func exportLegacy(_ exportSession: AVAssetExportSession) async throws {
        let exportBox = TeleprompterExportSessionBox(exportSession)
        try await withCheckedThrowingContinuation { continuation in
            exportBox.session.exportAsynchronously {
                let session = exportBox.session
                switch session.status {
                case .completed:
                    continuation.resume()
                case .failed, .cancelled:
                    continuation.resume(throwing: session.error ?? TeleprompterExportError.exportFailed)
                default:
                    continuation.resume(throwing: TeleprompterExportError.exportFailed)
                }
            }
        }
    }
}

private final class TeleprompterExportSessionBox: @unchecked Sendable {
    let session: AVAssetExportSession

    init(_ session: AVAssetExportSession) {
        self.session = session
    }
}

private struct TeleprompterSourceVideoInfo {
    let track: AVAssetTrack
    let duration: CMTime
    let start: CMTime
}

private protocol TeleprompterSettingOption: Identifiable, Hashable {
    var title: String { get }
}

private enum TeleprompterCountdown: String, CaseIterable, TeleprompterSettingOption {
    case off
    case three
    case five

    var id: String { rawValue }
    var seconds: Int {
        switch self {
        case .off: return 0
        case .three: return 3
        case .five: return 5
        }
    }
    var title: String {
        switch self {
        case .off: return L10n.text("teleprompter.countdown.off")
        case .three: return L10n.text("teleprompter.countdown.three")
        case .five: return L10n.text("teleprompter.countdown.five")
        }
    }
}

private enum TeleprompterAspectRatio: String, CaseIterable, TeleprompterSettingOption {
    case vertical
    case square
    case horizontal

    var id: String { rawValue }
    var title: String {
        switch self {
        case .vertical: return "9:16"
        case .square: return "1:1"
        case .horizontal: return "16:9"
        }
    }
    var value: CGFloat {
        switch self {
        case .vertical: return 9.0 / 16.0
        case .square: return 1
        case .horizontal: return 16.0 / 9.0
        }
    }
    var renderSize: CGSize {
        switch self {
        case .vertical: return CGSize(width: 1080, height: 1920)
        case .square: return CGSize(width: 1080, height: 1080)
        case .horizontal: return CGSize(width: 1920, height: 1080)
        }
    }
}

private enum TeleprompterFlashMode: String, CaseIterable, TeleprompterSettingOption {
    case off
    case on
    case auto

    var id: String { rawValue }
    var title: String {
        switch self {
        case .off: return L10n.text("teleprompter.flash.off")
        case .on: return L10n.text("teleprompter.flash.on")
        case .auto: return L10n.text("teleprompter.flash.auto")
        }
    }
}

private enum TeleprompterResolution: String, CaseIterable, TeleprompterSettingOption {
    case hd720
    case hd1080
    case uhd4K

    var id: String { rawValue }
    var title: String {
        switch self {
        case .hd720: return "720P"
        case .hd1080: return "1080P"
        case .uhd4K: return "4K"
        }
    }
    var sessionPreset: AVCaptureSession.Preset {
        switch self {
        case .hd720: return .hd1280x720
        case .hd1080: return .hd1920x1080
        case .uhd4K: return .hd4K3840x2160
        }
    }
}

private enum TeleprompterTextColor: String, CaseIterable, Identifiable {
    case white
    case yellow
    case black
    case pink
    case green
    case blue
    case purple

    var id: String { rawValue }
    var color: Color {
        switch self {
        case .white: return .white
        case .yellow: return .yellow
        case .black: return .black
        case .pink: return Color(red: 1, green: 0.36, blue: 0.5)
        case .green: return Color(red: 0.35, green: 0.9, blue: 0.42)
        case .blue: return Color(red: 0.27, green: 0.76, blue: 0.95)
        case .purple: return Color(red: 0.58, green: 0.48, blue: 0.9)
        }
    }
    var localizedName: String {
        L10n.text("teleprompter.color.\(rawValue)")
    }
}

struct TeleprompterClip: Identifiable {
    let id = UUID()
    let url: URL
    let thumbnail: UIImage?
    let duration: TimeInterval
}

struct TeleprompterExportRoute: Identifiable, Equatable {
    let id = UUID()
    let url: URL
}

private enum TeleprompterExportError: Error {
    case cannotCreateTrack
    case cannotCreateExportSession
    case exportFailed
}
