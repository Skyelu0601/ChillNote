import Foundation
import AVFoundation
import UIKit

struct TranscriptionEvent: Identifiable, Equatable {
    enum Result: Equatable {
        case success(String)
        case failure(reason: TranscriptionFailureReason, message: String)
    }

    let id: UUID
    let fileURL: URL
    let result: Result
    let createdAt: Date
}

enum TranscriptionFailureReason: Equatable {
    case networkUnavailable
    case timeout
    case authenticationRequired
    case serviceUnavailable
    case serviceConfiguration
    case quotaReached
    case audioEmpty
    case localFileIssue
    case unknown
}

@MainActor
final class SpeechRecognizer: NSObject, ObservableObject {
    // MARK: - Types
    
    enum RecordingState: Equatable {
        case idle
        case recording
        case processing
        case error(String)
    }
    
    enum StopReason: Equatable {
        case user
        case finished
        case interruption
        case error(String)
        case cancelled
    }
    
    // MARK: - Published Properties
    
    @Published var transcript: String = ""
    @Published var permissionGranted: Bool = false
    @Published var recordingState: RecordingState = .idle
    @Published var recordingStartTime: Date?
    @Published var shouldStop: Bool = false
    @Published private(set) var completedTranscriptions: [TranscriptionEvent] = []
    @Published private(set) var processingQueueCount: Int = 0
    @Published private(set) var activeTranscriptionFilePaths: Set<String> = []
    
    // MARK: - Private Properties
    
    private var audioRecorder: AVAudioRecorder?
    private var audioFileURL: URL?
    private var transcriptionCountUsageByFilePath: [String: Bool] = [:]
    private var isStopping = false
    private var activeTranscriptionJobIDs: Set<UUID> = []
    private var lastPrewarmAt: Date?
    private var sessionPrimed = false
    private var primedRecordingURL: URL?
    private var primedRecorder: AVAudioRecorder?
    private var recorderPrimeWorkItem: DispatchWorkItem?
    private var prewarmDeactivateTask: DispatchWorkItem?
    private let maxAudioBytes = 25 * 1024 * 1024 // 25MB limit (plenty for M4A)
    private let fileManager = RecordingFileManager.shared
    
    // MARK: - Computed Properties
    
    var isRecording: Bool {
        recordingState == .recording
    }

    var isProcessing: Bool {
        processingQueueCount > 0
    }
    
    func getCurrentAudioFileURL() -> URL? {
        return audioFileURL
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        checkPermissions()
        setupNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    // MARK: - Permissions
    
    func checkPermissions() {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] allowed in
                // Use DispatchQueue to avoid publishing changes during view updates
                DispatchQueue.main.async {
                    self?.permissionGranted = allowed
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] allowed in
                // Use DispatchQueue to avoid publishing changes during view updates
                DispatchQueue.main.async {
                    self?.permissionGranted = allowed
                }
            }
        }
    }
    
    // MARK: - Recording Control
    
    /// Call this after successfully saving the transcription to clean up the recording file
    func completeRecording() {
        guard let fileURL = audioFileURL else { return }
        completeRecording(fileURL: fileURL)
    }

    /// Complete and clean up a specific recording file.
    func completeRecording(fileURL: URL) {
        fileManager.completeRecording(fileURL: fileURL)
        transcriptionCountUsageByFilePath.removeValue(forKey: fileURL.path)
        if audioFileURL?.path == fileURL.path {
            audioFileURL = nil
        }
    }

    func consumeCompletedTranscription(eventID: UUID) {
        completedTranscriptions.removeAll { $0.id == eventID }
    }
    
    func startRecording(countsTowardQuota: Bool = true) {
        print("🎙️ Starting recording...")
        
        // Validation
        guard permissionGranted else {
            checkPermissions()
            setError(String(localized: "Microphone permission required"))
            return
        }
        
        guard recordingState != .recording else {
            print("⚠️ Already recording")
            return
        }
        
        // Reset state
        let shouldClearTranscript = !transcript.isEmpty

        do {
            try startRecordingInternal()
            if let path = audioFileURL?.path {
                transcriptionCountUsageByFilePath[path] = countsTowardQuota
            }
            recordingState = .recording
            recordingStartTime = Date()
            if shouldClearTranscript {
                transcript = ""
            }
            print("✅ Recording started successfully")
        } catch {
            print("❌ Recording failed: \(describeError(error))")
            print(debugAudioSessionSnapshot())
            cleanupRecordingSession()
            setError(
                String(
                    format: String(localized: "Failed to start recording: %@"),
                    error.localizedDescription
                )
            )
        }
    }

    func prewarmRecordingSession() {
        guard permissionGranted else {
            return
        }

        if let lastPrewarmAt, Date().timeIntervalSince(lastPrewarmAt) < 20 {
            if primedRecorder == nil {
                primeRecorderIfNeededAsync()
            }
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.duckOthers, .defaultToSpeaker]
            )
            try? audioSession.setPreferredInputNumberOfChannels(1)
            try? audioSession.setPreferredSampleRate(16_000)
            preferBuiltInMicIfAvailable(audioSession)
            try audioSession.setActive(true)
            primeRecordingURLIfNeeded()
            primeRecorderIfNeededAsync()
            sessionPrimed = true
            lastPrewarmAt = Date()
            schedulePrewarmDeactivation()
        } catch {}
    }
    
    /// Retry transcribing the existing audio file without re-recording
    /// Useful for network errors or timeouts
    func retryTranscription() {
        if let fileURL = audioFileURL {
            retryTranscription(fileURL: fileURL)
            return
        }

        if let failedFileURL = completedTranscriptions.last(where: {
            if case .failure = $0.result { return true }
            return false
        })?.fileURL {
            retryTranscription(fileURL: failedFileURL)
            return
        }

        setError(String(localized: "No recording available to retry"))
    }

    func retryTranscription(fileURL: URL) {
        print("🔄 Retrying transcription for \(fileURL.lastPathComponent)...")
        scheduleTranscription(for: fileURL)
    }

    /// Dismisses the current error state without deleting the recording file.
    /// The recording file remains in the pending recordings list for later recovery
    /// via Settings → Pending Recordings.
    func dismissError() {
        guard case .error = recordingState else { return }
        // Detach the file URL so it becomes a standalone pending recording
        audioFileURL = nil
        recordingState = activeTranscriptionJobIDs.isEmpty ? .idle : .processing
        print("ℹ️ Error dismissed. Recording preserved in pending.")
    }
    
    func stopRecording(reason: StopReason = .user) {
        print("🛑 Stopping recording, reason: \(reason)")
        
        guard !isStopping else { return }
        isStopping = true
        
        let fileURL = audioFileURL

        audioRecorder?.stop()
        audioRecorder = nil
        cleanupRecordingSession()
        recordingStartTime = nil

        isStopping = false

        if recordingState == .recording {
            recordingState = activeTranscriptionJobIDs.isEmpty ? .idle : .processing
        }
        
        // Handle different stop reasons
        switch reason {
        case .cancelled:
            // Clean up the cancelled recording
            if let fileURL = fileURL {
                fileManager.cancelRecording(fileURL: fileURL)
                transcriptionCountUsageByFilePath.removeValue(forKey: fileURL.path)
                audioFileURL = nil
            }
            refreshRecordingStateAfterBackgroundWork()
            return
            
        case .interruption:
            // CRITICAL FIX: Save recording on interruption instead of deleting
            print("⚠️ Interruption received. Saving recording...")
            break // Fall through to processing logic
            
        case .error(let message):
            setError(message)
            // If we have a valid file url, we might want to try to keep it as a pending recording
            // instead of deleting it immediately, depending on the error severity.
            // For now, if it's a recording error, it might be corrupt, but let's be safe.
            if let fileURL = fileURL {
                 // Check if file exists and has data
                 if let attr = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                    let size = attr[.size] as? Int, size > 1024 {
                     print("⚠️ Error occurred but file seems valid. Keeping for recovery.")
                 } else {
                     fileManager.cancelRecording(fileURL: fileURL)
                     transcriptionCountUsageByFilePath.removeValue(forKey: fileURL.path)
                     audioFileURL = nil
                 }
            }
            return
            
        case .user, .finished:
            break
        }
        
        guard let fileURL else {
            refreshRecordingStateAfterBackgroundWork()
            return
        }

        // Give the OS a moment to flush the final audio chunks to disk.
        scheduleTranscription(for: fileURL, initialDelayNanoseconds: 150_000_000)
    }
    
    // MARK: - Transcription
    
    private func transcribeAudio(jobID: UUID, fileURL: URL) async {
        print("🎤 Starting transcription...")
        defer {
            finishTranscriptionJob(jobID, filePath: fileURL.path)
        }

        // Validate file
        guard let fileSize = try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber else {
            // Only discard if we truly can't read it
            discardUnusableRecording(fileURL: fileURL)
            publishFailureEvent(
                fileURL: fileURL,
                reason: .localFileIssue,
                message: String(localized: "Could not read audio file")
            )
            return
        }
        
        let size = fileSize.intValue
        
        if size < 512 {
            discardUnusableRecording(fileURL: fileURL)
            publishFailureEvent(
                fileURL: fileURL,
                reason: .audioEmpty,
                message: String(localized: "No audio captured. Please try again.")
            )
            return
        }
        
        // WARNING: File is huge. We still try to process it,
        // but it might fail at the API level. Better than deleting user data.
        if size > maxAudioBytes {
            print("⚠️ Audio file is large (\(size) bytes). Attempting to process anyway.")
        }
        
        print("📊 Audio file size: \(size) bytes")
        
        // Transcribe using Gemini
        do {
            let countUsage = transcriptionCountUsageByFilePath[fileURL.path] ?? true
            let text = try await withTimeout(seconds: 300) {
                try await GeminiService.shared.transcribeAudio(
                    audioFileURL: fileURL,
                    countUsage: countUsage
                )
            }
            
            print("✅ Transcription complete")
            
            transcript = text.trimmingCharacters(in: .whitespacesAndNewlines)
            completedTranscriptions.append(
                TranscriptionEvent(
                    id: UUID(),
                    fileURL: fileURL,
                    result: .success(transcript),
                    createdAt: Date()
                )
            )
            
        } catch is TimeoutError {
            publishFailureEvent(
                fileURL: fileURL,
                reason: .timeout,
                message: String(localized: "Transcription timed out. Please try again.")
            )
            
        } catch let error as GeminiError {
            let reason: TranscriptionFailureReason
            switch error {
            case .networkError:
                reason = .networkUnavailable
            case .missingAPIKey, .invalidURL:
                reason = .serviceConfiguration
            case .invalidResponse:
                reason = .serviceUnavailable
            case .apiError(let apiMessage):
                reason = classifyAPIErrorMessage(apiMessage)
            }
            publishFailureEvent(fileURL: fileURL, reason: reason, message: message(for: error))
            
        } catch {
            publishFailureEvent(
                fileURL: fileURL,
                reason: .unknown,
                message: String(format: String(localized: "Transcription failed: %@"), error.localizedDescription)
            )
        }
    }
    
    // MARK: - Error Handling

    private func message(for error: GeminiError) -> String {
        switch error {
        case .missingAPIKey:
            return String(localized: "Chillo service key not configured. Please contact support.")
        case .apiError(let apiMessage):
            return String(format: String(localized: "Chillo service error: %@"), apiMessage)
        case .networkError(let networkError):
            return String(format: String(localized: "Network error: %@"), networkError.localizedDescription)
        case .invalidResponse:
            return String(localized: "Invalid response from Chillo.")
        case .invalidURL:
            return String(localized: "Invalid configuration URL.")
        }
    }
    
    private func setError(_ message: String) {
        print("❌ Error: \(message)")
        recordingState = .error(message)
    }

    private func publishFailureEvent(fileURL: URL, reason: TranscriptionFailureReason, message: String) {
        completedTranscriptions.append(
            TranscriptionEvent(
                id: UUID(),
                fileURL: fileURL,
                result: .failure(reason: reason, message: message),
                createdAt: Date()
            )
        )
        if recordingState != .recording {
            setError(message)
        }
    }

    private func classifyAPIErrorMessage(_ message: String) -> TranscriptionFailureReason {
        let lowered = message.lowercased()
        if lowered.contains("network error") {
            return .networkUnavailable
        }
        if lowered.contains("timed out") || lowered.contains("timeout") || lowered.contains("504") {
            return .timeout
        }
        if lowered.contains("sign in required")
            || lowered.contains("missing token")
            || lowered.contains("invalid token")
            || lowered.contains("unauthorized")
            || lowered.contains("session expired")
            || lowered.contains("auth") {
            return .authenticationRequired
        }
        if lowered.contains("daily free voice limit reached")
            || lowered.contains("daily voice limit reached")
            || lowered.contains("too many requests")
            || lowered.contains("rate limit")
            || lowered.contains("quota")
            || lowered.contains("429") {
            return .quotaReached
        }
        if lowered.contains("service key")
            || lowered.contains("api key")
            || lowered.contains("not configured")
            || lowered.contains("invalid configuration") {
            return .serviceConfiguration
        }
        if lowered.contains("no audio captured")
            || lowered.contains("audio empty")
            || lowered.contains("transcription result was empty")
            || TranscriptionContentValidator.looksLikeProviderEmptyResponse(lowered) {
            return .audioEmpty
        }
        if lowered.contains("provider error")
            || lowered.contains("internal server error")
            || lowered.contains("status code: 5")
            || lowered.contains("500")
            || lowered.contains("502")
            || lowered.contains("503") {
            return .serviceUnavailable
        }
        return .unknown
    }

    private func discardUnusableRecording(fileURL: URL) {
        fileManager.cancelRecording(fileURL: fileURL)
        transcriptionCountUsageByFilePath.removeValue(forKey: fileURL.path)
        if audioFileURL?.path == fileURL.path {
            audioFileURL = nil
        }
    }

    private func scheduleTranscription(for fileURL: URL, initialDelayNanoseconds: UInt64 = 0) {
        let jobID = UUID()
        activeTranscriptionJobIDs.insert(jobID)
        activeTranscriptionFilePaths.insert(fileURL.path)
        processingQueueCount = activeTranscriptionJobIDs.count
        if recordingState != .recording {
            recordingState = .processing
        }

        Task { [weak self] in
            guard let self else { return }
            if initialDelayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: initialDelayNanoseconds)
            }
            await self.transcribeAudio(jobID: jobID, fileURL: fileURL)
        }
    }

    private func finishTranscriptionJob(_ jobID: UUID, filePath: String) {
        activeTranscriptionJobIDs.remove(jobID)
        activeTranscriptionFilePaths.remove(filePath)
        processingQueueCount = activeTranscriptionJobIDs.count
        refreshRecordingStateAfterBackgroundWork()
    }

    private func refreshRecordingStateAfterBackgroundWork() {
        if recordingState == .recording {
            return
        }
        if case .error = recordingState, activeTranscriptionJobIDs.isEmpty {
            return
        }
        recordingState = activeTranscriptionJobIDs.isEmpty ? .idle : .processing
    }
    
    // MARK: - Timeout Helper
    
    private struct TimeoutError: Error {}
    
    private func withTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }
    
    // MARK: - Notification Handlers
    
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        if type == .began {
            stopRecording(reason: .interruption)
        }
    }
    
    

    
    @objc private func handleAppDidBecomeActive() {
        checkPermissions()
    }
}

// MARK: - Recording Internals

private extension SpeechRecognizer {
    func startRecordingInternal() throws {
        prewarmDeactivateTask?.cancel()
        prewarmDeactivateTask = nil

        let audioSession = AVAudioSession.sharedInstance()
        if !sessionPrimed {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.duckOthers, .defaultToSpeaker]
            )
        }

        if !sessionPrimed {
            try? audioSession.setPreferredInputNumberOfChannels(1)
            // 16kHz mono is sufficient for speech and keeps uploads small (important for server/proxy limits).
            // Note: `setPreferredSampleRate` is a best-effort hint; we still set the recorder sample rate below.
            try? audioSession.setPreferredSampleRate(16_000)
            preferBuiltInMicIfAvailable(audioSession)
            try audioSession.setActive(true)
        }

        guard audioSession.isInputAvailable else {
            throw NSError(
                domain: "SpeechRecognizer",
                code: 10,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "No microphone available")]
            )
        }

        let fileURL: URL
        if let primed = primedRecordingURL {
            fileURL = primed
            primedRecordingURL = nil
        } else {
            fileURL = makeTempAudioURL(ext: "m4a")
        }
        print("📁 Recording to: \(fileURL.path)")
        let recorder: AVAudioRecorder
        if let primedRecorder {
            recorder = primedRecorder
            self.primedRecorder = nil
            recorderPrimeWorkItem?.cancel()
            recorderPrimeWorkItem = nil
        } else {
            // Safe cleanup only when creating a brand-new recorder.
            // If we unlink a file already opened by a primed recorder, the final path disappears
            // after stop (first-recording race in onboarding).
            try? FileManager.default.removeItem(at: fileURL)
            recorder = try Self.makeRecorder(fileURL: fileURL)
            recorder.delegate = self
            recorder.isMeteringEnabled = true

            guard recorder.prepareToRecord() else {
                throw NSError(
                    domain: "SpeechRecognizer",
                    code: 11,
                    userInfo: [NSLocalizedDescriptionKey: String(localized: "Failed to prepare recorder")]
                )
            }
        }

        guard recorder.record() else {
            throw NSError(
                domain: "SpeechRecognizer",
                code: 12,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "Failed to start recording")]
            )
        }

        audioRecorder = recorder
        fileManager.markPending(fileURL: fileURL)
        audioFileURL = fileURL
        sessionPrimed = true
    }

    func cleanupRecordingSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        sessionPrimed = false
        primedRecorder = nil
        recorderPrimeWorkItem?.cancel()
        recorderPrimeWorkItem = nil
    }

    func schedulePrewarmDeactivation() {
        prewarmDeactivateTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.recordingState == .idle else { return }
            if let primedURL = self.primedRecordingURL {
                try? FileManager.default.removeItem(at: primedURL)
                self.primedRecordingURL = nil
            }
            self.primedRecorder = nil
            self.recorderPrimeWorkItem?.cancel()
            self.recorderPrimeWorkItem = nil
            self.cleanupRecordingSession()
        }
        prewarmDeactivateTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 12, execute: task)
    }

    func preferBuiltInMicIfAvailable(_ audioSession: AVAudioSession) {
        guard let inputs = audioSession.availableInputs else { return }
        if let builtInMic = inputs.first(where: { $0.portType == .builtInMic }) {
            try? audioSession.setPreferredInput(builtInMic)
        }
    }

    func primeRecordingURLIfNeeded() {
        guard primedRecordingURL == nil else {
            return
        }
        do {
            let url = try fileManager.createRecordingURL(ext: "m4a", markPending: false)
            primedRecordingURL = url
        } catch {}
    }

    func primeRecorderIfNeededAsync() {
        guard primedRecorder == nil else {
            return
        }
        guard recorderPrimeWorkItem == nil else {
            return
        }
        guard let primedRecordingURL else {
            return
        }

        let targetPath = primedRecordingURL.path
        var workItem: DispatchWorkItem?
        workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            do {
                let url = URL(fileURLWithPath: targetPath)
                let recorder = try Self.makeRecorder(fileURL: url)
                guard recorder.prepareToRecord() else {
                    DispatchQueue.main.async {
                        guard let workItem, !workItem.isCancelled else { return }
                        self.recorderPrimeWorkItem = nil
                    }
                    return
                }
                DispatchQueue.main.async {
                    guard let workItem, !workItem.isCancelled else { return }
                    defer { self.recorderPrimeWorkItem = nil }
                    guard self.recordingState == .idle else { return }
                    guard self.primedRecordingURL?.path == targetPath else { return }
                    if self.primedRecorder == nil {
                        recorder.delegate = self
                        recorder.isMeteringEnabled = true
                        self.primedRecorder = recorder
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    guard let workItem, !workItem.isCancelled else { return }
                    self.recorderPrimeWorkItem = nil
                    self.primedRecorder = nil
                }
            }
        }
        if let workItem {
            recorderPrimeWorkItem = workItem
            DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
        }
    }

    nonisolated static func makeRecorder(fileURL: URL) throws -> AVAudioRecorder {
        // AAC (M4A) compression for much smaller file sizes while maintaining quality.
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        return try AVAudioRecorder(url: fileURL, settings: settings)
    }

    func makeTempAudioURL(ext: String) -> URL {
        // Use the file manager's safe directory instead of temp
        do {
            return try fileManager.createRecordingURL(ext: ext)
        } catch {
            print("⚠️ Failed to create recording URL: \(error), falling back to temp")
            // Fallback to temp if something goes wrong
            let tempPath = NSTemporaryDirectory()
            let fileName = "\(UUID().uuidString).\(ext)"
            let filePath = (tempPath as NSString).appendingPathComponent(fileName)
            return URL(fileURLWithPath: filePath)
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension SpeechRecognizer: AVAudioRecorderDelegate {
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        let message = error?.localizedDescription ?? "Unknown audio encoder error"
        Task { @MainActor in
            self.audioRecorder = nil
            if let error {
                print("❌ Recorder encode error: \(self.describeError(error))")
                print(self.debugAudioSessionSnapshot())
            }
            self.cleanupRecordingSession()
            self.setError("Recording failed: \(message)")
        }
    }
}

// MARK: - Debug Helpers

private extension SpeechRecognizer {
    func describeError(_ error: Error) -> String {
        let ns = error as NSError
        return "\(type(of: error)) domain=\(ns.domain) code=\(ns.code) desc=\(ns.localizedDescription)"
    }

    func debugAudioSessionSnapshot() -> String {
        let s = AVAudioSession.sharedInstance()

        let recordPermission: String = {
            if #available(iOS 17.0, *) {
                switch AVAudioApplication.shared.recordPermission {
                case .undetermined: return "undetermined"
                case .denied: return "denied"
                case .granted: return "granted"
                @unknown default: return "unknown"
                }
            } else {
                switch s.recordPermission {
                case .undetermined: return "undetermined"
                case .denied: return "denied"
                case .granted: return "granted"
                @unknown default: return "unknown"
                }
            }
        }()

        let routeInputs = s.currentRoute.inputs.map { "\($0.portType.rawValue)(\($0.portName))" }.joined(separator: ", ")
        let routeOutputs = s.currentRoute.outputs.map { "\($0.portType.rawValue)(\($0.portName))" }.joined(separator: ", ")
        let availableInputs = s.availableInputs?.map { "\($0.portType.rawValue)(\($0.portName))" }.joined(separator: ", ") ?? "(nil)"

        return [
            "🔎 AudioSession snapshot:",
            "   recordPermission=\(recordPermission) inputAvailable=\(s.isInputAvailable) otherAudioPlaying=\(s.isOtherAudioPlaying)",
            "   category=\(s.category.rawValue) mode=\(s.mode.rawValue)",
            "   sampleRate=\(String(format: "%.0f", s.sampleRate))Hz ioBuffer=\(String(format: "%.4f", s.ioBufferDuration))s",
            "   routeIn=[\(routeInputs)] routeOut=[\(routeOutputs)]",
            "   availableInputs=[\(availableInputs)]"
        ].joined(separator: "\n")
    }
}
