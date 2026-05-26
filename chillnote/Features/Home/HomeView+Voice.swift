import SwiftUI
import SwiftData
import OSLog

private let homeVoiceLogger = Logger(subsystem: "com.chillnote.app", category: "home-voice")

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
        guard saveHomeVoiceContext(reason: "creating voice note") else {
            modelContext.delete(note)
            speechRecognizer.stopRecording()
            isVoiceMode = false
            return
        }

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
                homeVoiceLogger.error("Home voice transcription failed: \(message, privacy: .public)")
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
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            homeVoiceLogger.error("Failed to resolve voice note: \(error.localizedDescription, privacy: .public)")
            return nil
        }
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
        guard !shouldSkipDuplicateLinkImport(sourceURL: source.url, userId: userId) else { return }
        rememberRecentLinkImport(sourceURL: source.url)

        let placeholder = service.placeholderNoteText(for: url)
        let note = Note(content: placeholder, userId: userId)
        note.applySourceMetadata(source)
        note.importStatus = .queued
        note.importStartedAt = Date()
        applyCurrentTagContext(to: note)

        withAnimation {
            modelContext.insert(note)
        }
        guard saveHomeVoiceContext(reason: "creating link import note") else { return }
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
                let didSaveJob = await MainActor.run {
                    note.importJobId = job.jobId
                    note.importStatus = job.status == "processing" ? .processing : .queued
                    note.updatedAt = Date()
                    return saveHomeVoiceContext(reason: "saving link import job")
                }
                guard didSaveJob else { return }
                await syncLinkImportProgress()
            } catch {
                await MainActor.run {
                    note.importStatus = .failed
                    note.importErrorCode = "job_start_failed"
                    note.importCompletedAt = Date()
                    note.updatedAt = Date()
                    _ = saveHomeVoiceContext(reason: "saving failed link import")
                    clipboardLinkImportErrorMessage = error.localizedDescription
                    showClipboardLinkImportErrorAlert = true
                    requestReload(keepItemsWhileLoading: true)
                }
            }
        }
    }

    func shouldSkipDuplicateLinkImport(sourceURL: String, userId: String) -> Bool {
        let now = Date()
        recentLinkImportURLs = recentLinkImportURLs.filter { now.timeIntervalSince($0.value) < 60 }

        if let recentDate = recentLinkImportURLs[sourceURL],
           now.timeIntervalSince(recentDate) < 20 {
            return true
        }

        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate<Note> {
                $0.userId == userId
                && $0.sourceURL == sourceURL
                && $0.deletedAt == nil
            }
        )
        let existingNotes: [Note]
        do {
            existingNotes = try modelContext.fetch(descriptor)
        } catch {
            homeVoiceLogger.error("Failed to check duplicate link import: \(error.localizedDescription, privacy: .public)")
            return true
        }
        return existingNotes.contains { $0.isLinkImportInProgress }
    }

    func rememberRecentLinkImport(sourceURL: String) {
        recentLinkImportURLs[sourceURL] = Date()
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
    func saveHomeVoiceContext(reason: String) -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            homeVoiceLogger.error("Failed to save home voice context while \(reason, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
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
