import AVFoundation
import Speech
import Foundation

// Dictation edits the composer only. It never creates or submits a note or message.
@MainActor
final class ChilloDictation: ObservableObject {
    @Published private(set) var recording = false
    @Published private(set) var transcript = ""
    @Published private(set) var error: String?
    private var engine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func start(prefix: String) async {
        let authorization = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        let microphone = await AVAudioApplication.requestRecordPermission()
        guard authorization == .authorized, microphone,
              let recognizer = SFSpeechRecognizer(locale: .current), recognizer.isAvailable else {
            error = L10n.text("chillo.dictate.unavailable"); return
        }
        stop()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true)
            let engine = AVAudioEngine()
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            let node = engine.inputNode
            node.installTap(onBus: 0, bufferSize: 1024, format: node.outputFormat(forBus: 0)) { buffer, _ in request.append(buffer) }
            self.engine = engine; self.request = request
            task = recognizer.recognitionTask(with: request) { [weak self] result, failure in
                let text = result?.bestTranscription.formattedString
                let ended = result?.isFinal == true || failure != nil
                Task { @MainActor [weak self] in
                    guard let self, self.recording else { return }
                    if let text { self.transcript = prefix.isEmpty ? text : prefix + " " + text }
                    if ended { self.stop() }
                }
            }
            engine.prepare(); try engine.start()
            recording = true; error = nil
        } catch { stop(); self.error = L10n.text("chillo.dictate.unavailable") }
    }

    func stop() {
        recording = false
        engine?.stop(); engine?.inputNode.removeTap(onBus: 0)
        request?.endAudio(); task?.cancel()
        engine = nil; request = nil; task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
