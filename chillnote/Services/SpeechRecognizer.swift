import Foundation
import AVFoundation
import UIKit

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
    
    // MARK: - Private Properties
    
    private var audioRecorder: AVAudioRecorder?
    private var audioFileURL: URL?
    private var isStopping = false
    private var isTranscribing = false
    private let maxAudioBytes = 25 * 1024 * 1024 // 25MB limit (plenty for M4A)
    private let fileManager = RecordingFileManager.shared
    
    // MARK: - Computed Properties
    
    var isRecording: Bool {
        recordingState == .recording
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
        if let fileURL = audioFileURL {
            fileManager.completeRecording(fileURL: fileURL)
            audioFileURL = nil
        }
    }
    
    func startRecording() {
        print("🎙️ Starting recording...")
        
        // Validation
        guard permissionGranted else {
            setError("Microphone permission required")
            return
        }
        
        guard recordingState != .recording else {
            print("⚠️ Already recording")
            return
        }
        
        // Reset state
        isTranscribing = false
        transcript = ""

        do {
            try startRecordingInternal()
            recordingState = .recording
            recordingStartTime = Date()
            print("✅ Recording started successfully")
        } catch {
            print("❌ Recording failed: \(describeError(error))")
            print(debugAudioSessionSnapshot())
            cleanupRecordingSession()
            setError("Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    /// Retry transcribing the existing audio file without re-recording
    /// Useful for network errors or timeouts
    func retryTranscription() {
        guard let fileURL = audioFileURL else {
            setError("No recording available to retry")
            return
        }
        
        print("🔄 Retrying transcription...")
        recordingState = .processing
        isTranscribing = true
        
        Task {
            await transcribeAudio(fileURL: fileURL)
        }
    }
    
    func stopRecording(reason: StopReason = .user) {
        print("🛑 Stopping recording, reason: \(reason)")
        
        guard !isStopping else { return }
        isStopping = true
        
        let fileURL = audioFileURL

        audioRecorder?.stop()
        audioRecorder = nil
        cleanupRecordingSession()

        isStopping = false
        
        // Handle different stop reasons
        switch reason {
        case .cancelled:
            recordingState = .idle
            recordingStartTime = nil
            isTranscribing = false
            // Clean up the cancelled recording
            if let fileURL = fileURL {
                fileManager.cancelRecording(fileURL: fileURL)
                audioFileURL = nil
            }
            return
            
        case .interruption:
            // CRITICAL FIX: Save recording on interruption instead of deleting
            print("⚠️ Interruption received. Saving recording...")
            break // Fall through to processing logic
            
        case .error(let message):
            isTranscribing = false
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
                     audioFileURL = nil
                 }
            }
            return
            
        case .user, .finished:
            break
        }
        
        // Start transcription
        recordingState = .processing
        
        guard !isTranscribing, let fileURL = fileURL else {
            recordingState = .idle
            return
        }
        
        isTranscribing = true
        Task { [weak self] in
            // Give the OS a moment to flush the final audio chunks to disk.
            try? await Task.sleep(nanoseconds: 150_000_000)
            await self?.transcribeAudio(fileURL: fileURL)
        }
    }
    
    // MARK: - Transcription
    
    private func transcribeAudio(fileURL: URL) async {
        print("🎤 Starting transcription...")
        
        // Validate file
        guard let fileSize = try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber else {
            // Only discard if we truly can't read it
            discardUnusableRecording(fileURL: fileURL)
            setError("Could not read audio file")
            return
        }
        
        let size = fileSize.intValue
        
        if size < 512 {
            discardUnusableRecording(fileURL: fileURL)
            setError("No audio captured. Please try again.")
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
            let text = try await withTimeout(seconds: 300) {
                try await GeminiService.shared.transcribeAndPolish(
                    audioFileURL: fileURL,
                    locale: Locale.current.identifier
                )
            }
            
            print("✅ Transcription complete")
            
            isTranscribing = false
            transcript = text.trimmingCharacters(in: .whitespacesAndNewlines)
            recordingState = .idle
            recordingStartTime = nil
            
        } catch is TimeoutError {
            await handleTranscriptionError("Transcription timed out. Please try again.")
            
        } catch let error as GeminiError {
            await handleGeminiError(error)
            
        } catch {
            await handleTranscriptionError("Transcription failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Error Handling
    
    private func handleTranscriptionError(_ message: String) async {
        isTranscribing = false
        clearRecoveryFlagForCurrentRecording()
        setError(message)
    }
    
    private func handleGeminiError(_ error: GeminiError) async {
        let message: String
        
        switch error {
        case .missingAPIKey:
            message = "Chillo service key not configured. Please contact support."
        case .apiError(let apiMessage):
            message = "Chillo service error: \(apiMessage)"
        case .networkError(let networkError):
            message = "Network error: \(networkError.localizedDescription)"
        case .invalidResponse:
            message = "Invalid response from Chillo."
        case .invalidURL:
            message = "Invalid configuration URL."
        }
        
        isTranscribing = false
        clearRecoveryFlagForCurrentRecording()
        setError(message)
    }
    
    private func setError(_ message: String) {
        print("❌ Error: \(message)")
        recordingState = .error(message)
    }

    private func clearRecoveryFlagForCurrentRecording() {
        if let fileURL = audioFileURL {
            fileManager.clearPendingReference(fileURL: fileURL)
        }
    }
    
    private func discardUnusableRecording(fileURL: URL) {
        fileManager.cancelRecording(fileURL: fileURL)
        if audioFileURL?.path == fileURL.path {
            audioFileURL = nil
        }
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
        cleanupRecordingSession()

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.duckOthers, .defaultToSpeaker, .allowBluetoothHFP]
        )
        try? audioSession.setPreferredInputNumberOfChannels(1)
        // 16kHz mono is sufficient for speech and keeps uploads small (important for server/proxy limits).
        // Note: `setPreferredSampleRate` is a best-effort hint; we still set the recorder sample rate below.
        try? audioSession.setPreferredSampleRate(16_000)
        try audioSession.setActive(true)

        guard audioSession.isInputAvailable else {
            throw NSError(
                domain: "SpeechRecognizer",
                code: 10,
                userInfo: [NSLocalizedDescriptionKey: "No microphone available"]
            )
        }

        let fileURL = makeTempAudioURL(ext: "m4a")
        print("📁 Recording to: \(fileURL.path)")
        try? FileManager.default.removeItem(at: fileURL)

        // AAC (M4A) compression for much smaller file sizes while maintaining quality.
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true

        guard recorder.prepareToRecord() else {
            throw NSError(
                domain: "SpeechRecognizer",
                code: 11,
                userInfo: [NSLocalizedDescriptionKey: "Failed to prepare recorder"]
            )
        }
        guard recorder.record() else {
            throw NSError(
                domain: "SpeechRecognizer",
                code: 12,
                userInfo: [NSLocalizedDescriptionKey: "Failed to start recording"]
            )
        }

        audioRecorder = recorder
        audioFileURL = fileURL
    }

    func cleanupRecordingSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
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
