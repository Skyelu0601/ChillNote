import SwiftUI
import SwiftData
import AVFoundation

// MARK: - Playback Controller

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
                userInfo: [NSLocalizedDescriptionKey: String(localized: "Unable to prepare recording playback.")]
            )
        }
        guard player.play() else {
            throw NSError(
                domain: "PendingRecordingPlaybackController",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "Unable to start recording playback.")]
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

// MARK: - Row Save State

private enum RowSaveState: Equatable {
    case idle
    case saving
    case saved
}

// MARK: - Toast Model

private struct ToastMessage: Equatable {
    let id: UUID
    let text: String
    let isSuccess: Bool

    init(text: String, isSuccess: Bool = true) {
        self.id = UUID()
        self.text = text
        self.isSuccess = isSuccess
    }
}

// MARK: - PendingRecordingsView

struct PendingRecordingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authService: AuthService

    @State private var recordings: [PendingRecording] = []
    @State private var processingPaths: Set<String> = []
    /// Per-row save display state (separate from processingPaths so animation can linger)
    @State private var rowSaveStates: [String: RowSaveState] = [:]
    /// IDs of rows playing the "saved" animation before removal
    @State private var savedRows: Set<String> = []

    @State private var alertMessage: String?
    @State private var showAlert = false

    @State private var toastMessage: ToastMessage?
    @State private var toastTask: Task<Void, Never>?

    @StateObject private var playbackController = PendingRecordingPlaybackController()

    private var currentUserId: String? {
        authService.currentUserId
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
                                .transition(
                                    .asymmetric(
                                        insertion: .opacity.combined(with: .move(edge: .top)),
                                        removal: .opacity.combined(with: .scale(scale: 0.95))
                                    )
                                )
                        }
                    }
                    .listStyle(.plain)
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: recordings.map(\.id))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            // MARK: Toast Overlay
            VStack {
                if let toast = toastMessage {
                    toastView(toast)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            )
                        )
                        .id(toast.id)
                }
                Spacer()
            }
            .padding(.top, 8)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: toastMessage)
            .allowsHitTesting(false)
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

    // MARK: - Empty State

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

    // MARK: - Recording Row

    private func recordingRow(_ recording: PendingRecording) -> some View {
        let path = recording.fileURL.path
        let saveState = rowSaveStates[path] ?? .idle
        let isPlaying = playbackController.playingPath == path

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button(action: { togglePlayback(recording) }) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(isPlaying ? .accentPrimary : .textSub)
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(saveState != .idle)

                Text(recording.durationText)
                    .font(.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(.textMain)

                Spacer()
            }

            HStack(spacing: 10) {
                Button(action: { deleteRecording(recording) }) {
                    Text("Delete")
                        .font(.bodySmall)
                        .foregroundColor(.red.opacity(0.85))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(saveState != .idle)

                saveButton(for: recording, state: saveState)
            }
        }
        .padding(16)
        .background(saveState == .saved ? Color.green.opacity(0.06) : Color.bgSecondary)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    saveState == .saved ? Color.green.opacity(0.3) : Color.gray.opacity(0.1),
                    lineWidth: saveState == .saved ? 1.5 : 1
                )
        )
        .animation(.easeInOut(duration: 0.25), value: saveState == .saved)
    }

    @ViewBuilder
    private func saveButton(for recording: PendingRecording, state: RowSaveState) -> some View {
        switch state {
        case .idle:
            Button(action: { transcribeRecording(recording) }) {
                Text("Save as Note")
                    .font(.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentPrimary)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)

        case .saving:
            HStack(spacing: 6) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
                Text("Saving...")
                    .font(.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.gray.opacity(0.45))
            .cornerRadius(10)

        case .saved:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text("Saved!")
                    .font(.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.green.opacity(0.85))
            .cornerRadius(10)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
    }

    // MARK: - Toast View

    private func toastView(_ toast: ToastMessage) -> some View {
        HStack(spacing: 8) {
            Image(systemName: toast.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(toast.isSuccess ? .green : .red)

            Text(toast.text)
                .font(.bodySmall)
                .fontWeight(.semibold)
                .foregroundColor(.textMain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.bgSecondary)
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        )
    }

    // MARK: - Actions

    private func refreshRecordings() {
        recordings = RecordingFileManager.shared.pendingRecordings(sortedByNewest: true)
    }

    private func showToast(_ message: String, isSuccess: Bool = true) {
        toastTask?.cancel()
        withAnimation {
            toastMessage = ToastMessage(text: message, isSuccess: isSuccess)
        }
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation {
                    toastMessage = nil
                }
            }
        }
    }

    private func deleteRecording(_ recording: PendingRecording) {
        playbackController.stopIfPlaying(path: recording.fileURL.path)
        RecordingFileManager.shared.cancelRecording(fileURL: recording.fileURL)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            recordings.removeAll { $0.id == recording.id }
        }
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
        guard (rowSaveStates[path] ?? .idle) == .idle else { return }

        playbackController.stopIfPlaying(path: path)

        withAnimation(.easeInOut(duration: 0.2)) {
            rowSaveStates[path] = .saving
        }
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
                        userInfo: [NSLocalizedDescriptionKey: String(localized: "Transcription result was empty. Please retry.")]
                    )
                }
                let userId = try await MainActor.run { () throws -> String in
                    guard let userId = currentUserId else {
                        throw NSError(
                            domain: "PendingRecordingsView",
                            code: 4,
                            userInfo: [NSLocalizedDescriptionKey: String(localized: "Sign in required.")]
                        )
                    }
                    return userId
                }

                await MainActor.run {
                    // 1. Resolve note: update existing linked Note, or create a new one
                    let note: Note
                    if let existingID = RecordingFileManager.shared.noteID(for: recording.fileURL),
                       let existingNote = fetchNote(id: existingID) {
                        // Restore from trash if needed and update content
                        existingNote.deletedAt = nil
                        existingNote.content = trimmed
                        existingNote.updatedAt = Date()
                        note = existingNote
                    } else {
                        // Fallback: no prior Note found, create a fresh one
                        note = Note(content: trimmed, userId: userId)
                        modelContext.insert(note)
                    }
                    try? modelContext.save()

                    VoiceProcessingService.shared.processingStates[note.id] = .processing(stage: .refining)
                    Task {
                        await VoiceProcessingService.shared.startProcessing(
                            note: note,
                            rawTranscript: trimmed,
                            context: modelContext
                        )
                    }

                    RecordingFileManager.shared.completeRecording(fileURL: recording.fileURL)
                    processingPaths.remove(path)

                    // 2. Show "Saved!" state on the row
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        rowSaveStates[path] = .saved
                    }

                    // 3. Notify HomeView immediately so it reloads & can navigate to the new note
                    NotificationCenter.default.post(
                        name: .pendingRecordingNoteCreated,
                        object: nil,
                        userInfo: ["noteID": note.id]
                    )

                    // 4. Show toast
                    showToast(String(localized: "Note saved!"))

                    // 5. Remove the row after a short delay so user sees the "Saved!" confirmation
                    Task {
                        try? await Task.sleep(nanoseconds: 900_000_000) // 0.9s
                        await MainActor.run {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                rowSaveStates.removeValue(forKey: path)
                                recordings.removeAll { $0.id == recording.id }
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showAlert = true
                    withAnimation {
                        rowSaveStates[path] = .idle
                    }
                    processingPaths.remove(path)
                    showToast(String(localized: "Save failed. Please retry."), isSuccess: false)
                }
            }
        }
    }

    // MARK: - Helpers

    /// Fetches a Note by its UUID from the current model context.
    private func fetchNote(id: UUID) -> Note? {
        let targetID = id
        let descriptor = FetchDescriptor<Note>(predicate: #Predicate<Note> { $0.id == targetID })
        return try? modelContext.fetch(descriptor).first
    }
}

#Preview {
    PendingRecordingsView()
}
