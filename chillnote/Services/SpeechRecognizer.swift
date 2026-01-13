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
    @Published var shouldStop: Bool = false
    
    // MARK: - Private Properties
    
    private var audioRecorder: AVAudioRecorder?
    private var audioFileURL: URL?
    private var isStopping = false
    private var isTranscribing = false
    private let maxAudioBytes = 14 * 1024 * 1024 // 14MB limit for Gemini
    
    // MARK: - Computed Properties
    
    var isRecording: Bool {
        recordingState == .recording
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
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
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
                Task { @MainActor in
                    self?.permissionGranted = allowed
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] allowed in
                Task { @MainActor in
                    self?.permissionGranted = allowed
                }
            }
        }
    }
    
    // MARK: - Recording Control
    
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
            print("✅ Recording started successfully")
        } catch {
            print("❌ Recording failed: \(describeError(error))")
            print(debugAudioSessionSnapshot())
            cleanupRecordingSession()
            setError("Failed to start recording: \(error.localizedDescription)")
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
            isTranscribing = false
            return
            
        case .interruption:
            isTranscribing = false
            setError("Recording was interrupted")
            return
            
        case .error(let message):
            isTranscribing = false
            setError(message)
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
            setError("Could not read audio file")
            return
        }
        
        let size = fileSize.intValue
        
        if size < 512 {
            setError("No audio captured. Please try again.")
            return
        }
        
        if size > maxAudioBytes {
            setError("Audio too long. Please record a shorter note.")
            return
        }
        
        print("📊 Audio file size: \(size) bytes")
        
        // Transcribe using Gemini
        do {
            let polishedText = try await withTimeout(seconds: 45) {
                try await GeminiService.shared.transcribeAndPolish(
                    audioFileURL: fileURL,
                    locale: Locale.current.identifier
                )
            }
            
            print("✅ Transcription complete")
            
            isTranscribing = false
            transcript = polishedText.trimmingCharacters(in: .whitespacesAndNewlines)
            recordingState = .idle
            
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
        setError(message)
    }
    
    private func handleGeminiError(_ error: GeminiError) async {
        let message: String
        
        switch error {
        case .missingAPIKey:
            message = "Gemini API key not configured. Please set GEMINI_API_KEY in Environment Variables."
        case .apiError(let apiMessage):
            message = "Gemini API error: \(apiMessage)"
        case .networkError(let networkError):
            message = "Network error: \(networkError.localizedDescription)"
        case .invalidResponse:
            message = "Invalid response from Gemini service."
        case .invalidURL:
            message = "Invalid configuration URL."
        }
        
        isTranscribing = false
        setError(message)
    }
    
    private func setError(_ message: String) {
        print("❌ Error: \(message)")
        recordingState = .error(message)
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
    
    @objc private func handleAppWillResignActive() {
        if recordingState == .recording {
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
            options: [.duckOthers, .defaultToSpeaker, .allowBluetooth]
        )
        try? audioSession.setPreferredInputNumberOfChannels(1)
        try audioSession.setActive(true)

        guard audioSession.isInputAvailable else {
            throw NSError(
                domain: "SpeechRecognizer",
                code: 10,
                userInfo: [NSLocalizedDescriptionKey: "No microphone available"]
            )
        }

        let fileURL = makeTempAudioURL(ext: "wav")
        print("📁 Recording to: \(fileURL.path)")
        try? FileManager.default.removeItem(at: fileURL)

        // Linear PCM WAV is much more reliable across devices/simulators than AAC at low sample rates.
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
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
        let tempPath = NSTemporaryDirectory()
        let fileName = "\(UUID().uuidString).\(ext)"
        let filePath = (tempPath as NSString).appendingPathComponent(fileName)
        return URL(fileURLWithPath: filePath)
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
            switch s.recordPermission {
            case .undetermined: return "undetermined"
            case .denied: return "denied"
            case .granted: return "granted"
            @unknown default: return "unknown"
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
