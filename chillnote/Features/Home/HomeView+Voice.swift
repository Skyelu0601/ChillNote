import SwiftUI
import SwiftData

extension HomeView {
    func handleTextSubmit() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        _ = saveNote(text: trimmed)
        inputText = ""
    }

    func handleVoiceConfirmation() {
        guard speechRecognizer.isRecording else { return }
        guard let fileURL = speechRecognizer.getCurrentAudioFileURL() else {
            speechRecognizer.stopRecording()
            isVoiceMode = false
            return
        }
        guard let userId = currentUserId else {
            speechRecognizer.stopRecording()
            isVoiceMode = false
            return
        }

        let note = Note(content: "", userId: userId)
        applyCurrentTagContext(to: note)
        modelContext.insert(note)
        try? modelContext.save()

        pendingVoiceNoteByPath[fileURL.path] = note.id
        // Persist the link so PendingRecordingsView can find this Note after a crash/restart
        RecordingFileManager.shared.setNoteID(note.id, for: fileURL)
        VoiceProcessingService.shared.processingStates[note.id] = .processing(stage: .transcribing)

        if navigationPath.isEmpty {
            navigationPath.append(note)
        }

        requestReload()

        speechRecognizer.stopRecording()
        isVoiceMode = false
    }

    func handleCompletedTranscriptions() {
        let events = speechRecognizer.completedTranscriptions
        guard !events.isEmpty else { return }

        for event in events {
            guard let noteID = pendingVoiceNoteByPath[event.fileURL.path] else {
                continue
            }

            speechRecognizer.consumeCompletedTranscription(eventID: event.id)

            switch event.result {
            case .success(let rawText):
                pendingVoiceNoteByPath.removeValue(forKey: event.fileURL.path)
                speechRecognizer.completeRecording(fileURL: event.fileURL)

                let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    VoiceProcessingService.shared.processingStates.removeValue(forKey: noteID)
                    continue
                }
                guard let note = resolveNote(noteID) else {
                    VoiceProcessingService.shared.processingStates.removeValue(forKey: noteID)
                    continue
                }

                Task {
                    await VoiceProcessingService.shared.startProcessing(note: note, rawTranscript: trimmed, context: modelContext)
                    requestReload()
                    await syncManager.syncIfNeeded(context: modelContext)
                }

            case .failure(let message):
                print("⚠️ Home voice transcription failed: \(message)")
                let guidance = String(localized: "Transcription failed. Audio was saved to Pending Records.")
                VoiceProcessingService.shared.processingStates[noteID] = .failed(message: guidance)
                Task { @MainActor in
                    await checkForPendingRecordingsAsync()
                }
            }
        }
    }

    func resolveNote(_ noteID: UUID) -> Note? {
        if let note = homeViewModel.note(with: noteID) {
            return note
        }
        let targetID = noteID
        let descriptor = FetchDescriptor<Note>(predicate: #Predicate<Note> { $0.id == targetID })
        return try? modelContext.fetch(descriptor).first
    }

    func createAndOpenBlankNote() {
        guard let userId = currentUserId else { return }
        let note = Note(content: "", userId: userId)
        applyCurrentTagContext(to: note)
        modelContext.insert(note)
        persistAndSync()
        navigationPath.append(note)
    }

    @discardableResult
    func saveNote(text: String, shouldNavigate: Bool = false) -> Note? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let userId = currentUserId else { return nil }

        let note = Note(content: trimmed, userId: userId)
        applyCurrentTagContext(to: note)

        withAnimation {
            modelContext.insert(note)
            Task {
                await generateTags(for: note)
            }
        }

        persistAndSync()

        if shouldNavigate {
            navigationPath.append(note)
        }

        return note
    }

    func generateTags(for note: Note) async {
        do {
            let fetchDescriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.deletedAt == nil })
            let allTags = (try? modelContext.fetch(fetchDescriptor))?.map { $0.name } ?? []

            let suggestions = try await TagService.shared.suggestTags(for: note.content, existingTags: allTags)

            if !suggestions.isEmpty {
                await MainActor.run {
                    note.suggestedTags = suggestions
                    persistAndSync()
                }
            }
        } catch {
            print("⚠️ Failed to generate tags: \(error)")
        }
    }
}
