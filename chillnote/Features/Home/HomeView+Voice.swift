import SwiftUI
import SwiftData

extension HomeView {
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
            let recoveredNoteID = pendingVoiceNoteByPath[event.fileURL.path]
                ?? RecordingFileManager.shared.noteID(for: event.fileURL)
            guard let noteID = recoveredNoteID else {
                speechRecognizer.consumeCompletedTranscription(eventID: event.id)
                continue
            }
            pendingVoiceNoteByPath[event.fileURL.path] = noteID

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
                    let didFinishProcessing = await VoiceProcessingService.shared.startProcessing(
                        note: note,
                        rawTranscript: trimmed,
                        context: modelContext
                    )
                    persistAndSync()
                    await MainActor.run {
                        guard didFinishProcessing else { return }
                        VoiceNotePaywallService.shared.registerSuccessfulVoiceNoteSave()
                        if AppRatingService.shared.registerSuccessfulVoiceNoteSave() {
                            Task {
                                try? await Task.sleep(nanoseconds: 3_000_000_000)
                                await MainActor.run {
                                    showAppRatingPrompt = true
                                }
                            }
                        }
                    }
                }

            case .failure(let reason, let message):
                print("⚠️ Home voice transcription failed: \(message)")
                let userFacing = reason.pendingRecoveryMessage
                VoiceProcessingService.shared.processingStates[noteID] = .failed(message: userFacing)
                latestTranscriptionFailureMessage = userFacing
                showTranscriptionFailureAlert = true
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

    func savePastedLink(_ result: QuickCaptureImportService.LinkImportResult) {
        _ = saveNote(text: result.noteText, source: result.source, shouldNavigate: true)
    }

    func createLinkImportNote(_ url: URL) {
        guard let userId = currentUserId else { return }

        let service = QuickCaptureImportService.shared
        let source = service.initialSourceMetadata(for: url)
        let placeholder = service.placeholderNoteText(for: url)
        let note = Note(content: placeholder, userId: userId)
        note.applySourceMetadata(source)
        note.importStatus = .queued
        note.importStartedAt = Date()
        applyCurrentTagContext(to: note)

        withAnimation {
            modelContext.insert(note)
        }
        try? modelContext.save()
        navigationPath.append(note)
        requestReload(delayNanoseconds: 60_000_000, keepItemsWhileLoading: true)

        Task {
            do {
                let job = try await service.startAsyncWebLinkImport(
                    url: url,
                    noteID: note.id,
                    placeholderContent: placeholder,
                    source: source,
                    section: note.section
                )
                await MainActor.run {
                    note.importJobId = job.jobId
                    note.importStatus = job.status == "processing" ? .processing : .queued
                    note.updatedAt = Date()
                    try? modelContext.save()
                }
                await syncLinkImportProgress()
            } catch {
                await MainActor.run {
                    note.importStatus = .failed
                    note.importErrorCode = "job_start_failed"
                    note.importCompletedAt = Date()
                    note.updatedAt = Date()
                    try? modelContext.save()
                    clipboardLinkImportErrorMessage = error.localizedDescription
                    showClipboardLinkImportErrorAlert = true
                    requestReload(keepItemsWhileLoading: true)
                }
            }
        }
    }

    func syncLinkImportProgress() async {
        for delay in [3_000_000_000, 10_000_000_000, 25_000_000_000] as [UInt64] {
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            await syncManager.syncNow(context: modelContext)
            await MainActor.run {
                requestReload(delayNanoseconds: 80_000_000, keepItemsWhileLoading: true)
            }
        }
    }

    func saveImportedImageText(_ text: String) {
        _ = saveNote(text: text, shouldNavigate: true)
    }

    @discardableResult
    func saveNote(text: String, source: NoteSourceMetadata? = nil, shouldNavigate: Bool = false) -> Note? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let userId = currentUserId else { return nil }

        let note = Note(content: trimmed, userId: userId)
        note.applySourceMetadata(source)
        applyCurrentTagContext(to: note)

        withAnimation {
            modelContext.insert(note)
        }

        persistAndSync()

        if shouldNavigate {
            navigationPath.append(note)
        }

        return note
    }
}
