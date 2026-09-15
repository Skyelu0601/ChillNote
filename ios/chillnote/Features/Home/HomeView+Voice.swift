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
                let analyticsOperationID = speechRecognizer.analyticsOperationID(for: event.fileURL)
                    ?? noteID.uuidString.lowercased()
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
                        ProductAnalytics.shared.captureCreationCompleted(
                            operationID: analyticsOperationID,
                            type: "audio_transcript",
                            entryPoint: "home_voice"
                        )
                        if AppRatingService.shared.registerSuccessfulVoiceNoteSave() {
                            requestAppRating()
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
        navigationPath.append(NewBlankNoteRoute(note: note))
    }

    @discardableResult
    func createLinkImportNote(
        _ url: URL,
        noteID: UUID? = nil,
        source sharedSource: NoteSourceMetadata? = nil,
        shouldNavigate: Bool = false
    ) -> Note? {
        guard let userId = currentUserId else { return nil }

        let service = QuickCaptureImportService.shared
        let source = sharedSource ?? service.initialSourceMetadata(for: url)
        let existingNote = noteID
            .flatMap(resolveNote)
            .flatMap { $0.userId == userId ? $0 : nil }
        if let existingNote, !existingNote.isLinkImportInProgress || existingNote.importJobId != nil {
            if shouldNavigate { navigationPath.append(existingNote) }
            return existingNote
        }
        if existingNote == nil {
            guard !shouldSkipDuplicateLinkImport(sourceURL: source.url, userId: userId) else { return nil }
        }
        rememberRecentLinkImport(sourceURL: source.url)

        let placeholder = service.placeholderNoteText(for: url)
        let note: Note
        if let existingNote {
            note = existingNote
        } else {
            note = Note(content: placeholder, userId: userId)
            if let noteID {
                note.id = noteID
            }
        }
        note.applySourceMetadata(source)
        if existingNote == nil {
            note.importStatus = .queued
        }

        if existingNote == nil {
            note.importStartedAt = Date()
            applyCurrentTagContext(to: note)
            withAnimation {
                modelContext.insert(note)
            }
        }
        guard saveHomeVoiceContext(reason: "creating link import note") else { return nil }
        if shouldNavigate {
            navigationPath.append(note)
        }
        requestReload(delayNanoseconds: 60_000_000, keepItemsWhileLoading: true)

        let shouldStartJob = note.importJobId == nil
            && (note.importStatus == .queued || note.importStatus == .processing)
        if !shouldStartJob {
            return note
        }

        note.importStartedAt = Date()
        note.updatedAt = Date()
        guard saveHomeVoiceContext(reason: "starting link import job") else { return nil }

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
                    StoreService.shared.applyBackendCreditBalance(job.balance, tier: job.tier)
                    guard note.isLinkImportInProgress else { return true }
                    note.importJobId = job.jobId
                    note.importStatus = job.status == "processing" ? .processing : .queued
                    note.updatedAt = Date()
                    return saveHomeVoiceContext(reason: "saving link import job")
                }
                guard didSaveJob else { return }
                await MainActor.run {
                    ProductAnalytics.shared.capture("video_transcription_started", properties: [
                        "operation_id": note.id.uuidString.lowercased(),
                        "source_platform": note.sourcePlatformID ?? "unknown",
                        "attempt_id": job.jobId
                    ])
                }
            } catch {
                await MainActor.run {
                    guard note.isLinkImportInProgress else { return }
                    note.importStatus = .failed
                    note.importErrorCode = ifInsufficientCredits(error) ? "insufficient_credits" : "job_start_failed"
                    note.importCompletedAt = Date()
                    note.updatedAt = Date()
                    _ = saveHomeVoiceContext(reason: "saving failed link import")
                    if case QuickCaptureImportError.insufficientCredits(let balance) = error {
                        StoreService.shared.applyBackendCreditBalance(balance, tier: SubscriptionTier.free.rawValue)
                        pendingLinkImportUpgradeNoteID = note.id
                        showSubscription = true
                    } else {
                        clipboardLinkImportErrorMessage = error.localizedDescription
                        showClipboardLinkImportErrorAlert = true
                    }
                    requestReload(keepItemsWhileLoading: true)
                }
            }
        }

        return note
    }

    private func ifInsufficientCredits(_ error: Error) -> Bool {
        if case QuickCaptureImportError.insufficientCredits = error {
            return true
        }
        return false
    }

    @MainActor
    func retryInsufficientCreditsLinkImport(noteID: UUID) {
        guard let note = resolveNote(noteID),
              note.importStatus == .failed,
              note.importErrorCode == "insufficient_credits",
              let source = note.sourceMetadata,
              let url = URL(string: source.url) else { return }

        note.importStatus = .queued
        note.importErrorCode = nil
        note.importJobId = nil
        note.importStartedAt = Date()
        note.importCompletedAt = nil
        note.updatedAt = Date()
        guard saveHomeVoiceContext(reason: "retrying link import after credit recovery") else { return }
        _ = createLinkImportNote(url, noteID: note.id, source: source)
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

    func monitorLinkImportProgress() async {
        var delayNanoseconds: UInt64 = 3_000_000_000

        while !Task.isCancelled {
            guard scenePhase == .active else {
                delayNanoseconds = 3_000_000_000
                do {
                    try await Task.sleep(nanoseconds: 10_000_000_000)
                } catch {
                    return
                }
                continue
            }

            resumeOrphanedLinkImportsIfNeeded()

            // Sync before sleeping so opening/foregrounding Home can consume a
            // completion that has already produced a push notification.
            let didSync = await syncManager.syncNow(context: modelContext)
            guard !Task.isCancelled else { return }
            if didSync {
                registerCompletedLinkImportsForRating()
            }
            await homeViewModel.reload(keepItemsWhileLoading: true)
            clampSelectionToCurrentFilter()
            reconcileFirstActionGuideImport()

            do {
                try await Task.sleep(nanoseconds: delayNanoseconds)
            } catch {
                return
            }
            delayNanoseconds = min(delayNanoseconds * 2, 10_000_000_000)
        }
    }

    func resumeOrphanedLinkImportsIfNeeded() {
        let recoveryCutoff = Date().addingTimeInterval(-30)
        let orphanedNotes = homeViewModel.items.filter { note in
            note.isLinkImportInProgress
                && note.importJobId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
                && (note.importStartedAt ?? note.updatedAt) <= recoveryCutoff
                && note.sourceMetadata != nil
        }

        for note in orphanedNotes {
            guard let source = note.sourceMetadata,
                  let url = URL(string: source.url) else { continue }
            _ = createLinkImportNote(
                url,
                noteID: note.id,
                source: source,
                shouldNavigate: false
            )
        }
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
