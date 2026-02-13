import SwiftUI
import SwiftData
import AVFoundation

@MainActor
final class PendingRecordingPlaybackController: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var playingPath: String?

    private var player: AVAudioPlayer?

    func togglePlayback(fileURL: URL) throws {
        let path = fileURL.path
        if playingPath == path {
            stop()
            return
        }

        stop()

        let player = try AVAudioPlayer(contentsOf: fileURL)
        player.delegate = self
        guard player.prepareToPlay() else {
            throw NSError(
                domain: "PendingRecordingPlaybackController",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to prepare recording playback."]
            )
        }
        guard player.play() else {
            throw NSError(
                domain: "PendingRecordingPlaybackController",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Unable to start recording playback."]
            )
        }

        self.player = player
        playingPath = path
    }

    func stop() {
        player?.stop()
        player = nil
        playingPath = nil
    }

    func stopIfPlaying(path: String) {
        guard playingPath == path else { return }
        stop()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.player = nil
            self?.playingPath = nil
        }
    }
}

struct PendingRecordingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authService: AuthService
    @State private var recordings: [PendingRecording] = []
    @State private var processingPaths: Set<String> = []
    @State private var alertMessage: String?
    @State private var showAlert = false
    @StateObject private var playbackController = PendingRecordingPlaybackController()

    private var currentUserId: String {
        authService.currentUserId ?? "unknown"
    }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 16) {
                if recordings.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(recordings) { recording in
                            recordingRow(recording)
                                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                                .listRowBackground(Color.bgPrimary)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .navigationTitle("Pending Recordings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshRecordings()
        }
        .onDisappear {
            playbackController.stop()
        }
        .alert("Transcription Failed", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage ?? "An unknown error occurred.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 44))
                .foregroundColor(.textSub.opacity(0.6))
            Text("No pending recordings")
                .font(.bodyMedium)
                .foregroundColor(.textSub)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 40)
    }

    private func recordingRow(_ recording: PendingRecording) -> some View {
        let isProcessing = processingPaths.contains(recording.fileURL.path)
        let isPlaying = playbackController.playingPath == recording.fileURL.path

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "mic.fill")
                    .font(.bodyMedium)
                    .foregroundColor(.textSub)
                    .padding(10)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Voice Memo")
                        .font(.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(.textMain)
                    Text(recording.durationText)
                        .font(.bodySmall)
                        .foregroundColor(.textSub)
                }
                Spacer()
            }

            HStack(spacing: 12) {
                Button(action: { togglePlayback(recording) }) {
                    Text(isPlaying ? "Pause" : "Play")
                        .font(.bodySmall)
                        .foregroundColor(.textMain)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.12))
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)

                Button(action: { deleteRecording(recording) }) {
                    Text("Delete")
                        .font(.bodySmall)
                        .foregroundColor(.red.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)

                Button(action: { transcribeRecording(recording) }) {
                    Text(isProcessing ? "Processing..." : "Transcribe")
                        .font(.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isProcessing ? Color.gray.opacity(0.5) : Color.accentPrimary)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)
            }
        }
        .padding(16)
        .background(Color.bgSecondary)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }

    private func refreshRecordings() {
        RecordingFileManager.shared.cleanupOldRecordings()
        recordings = RecordingFileManager.shared.checkForPendingRecordings()
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func deleteRecording(_ recording: PendingRecording) {
        playbackController.stopIfPlaying(path: recording.fileURL.path)
        RecordingFileManager.shared.cancelRecording(fileURL: recording.fileURL)
        recordings.removeAll { $0.id == recording.id }
    }

    private func togglePlayback(_ recording: PendingRecording) {
        do {
            try playbackController.togglePlayback(fileURL: recording.fileURL)
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func transcribeRecording(_ recording: PendingRecording) {
        let path = recording.fileURL.path
        guard !processingPaths.contains(path) else { return }

        playbackController.stopIfPlaying(path: path)
        processingPaths.insert(path)
        Task {
            do {
                let text = try await GeminiService.shared.transcribeAudio(
                    audioFileURL: recording.fileURL
                )
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    throw NSError(
                        domain: "PendingRecordingsView",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "Transcription result was empty. Please retry."]
                    )
                }

                await MainActor.run {
                    let note = Note(content: trimmed, userId: currentUserId)
                    modelContext.insert(note)
                    try? modelContext.save()
                    VoiceProcessingService.shared.processingStates[note.id] = .processing(stage: .refining)

                    Task {
                        await VoiceProcessingService.shared.startProcessing(note: note, rawTranscript: trimmed, context: modelContext)
                    }

                    RecordingFileManager.shared.completeRecording(fileURL: recording.fileURL)
                    recordings.removeAll { $0.id == recording.id }
                    processingPaths.remove(path)
                }
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showAlert = true
                    processingPaths.remove(path)
                }
            }
        }
    }
}

#Preview {
    PendingRecordingsView()
}
