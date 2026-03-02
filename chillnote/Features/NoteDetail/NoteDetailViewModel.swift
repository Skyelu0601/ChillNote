import Foundation
import SwiftData
import SwiftUI

@MainActor
final class NoteDetailViewModel: ObservableObject {
    struct Dependencies {
        var now: () -> Date = Date.init
        var checkDailyQuota: (DailyQuotaFeature) async -> Bool = { feature in
            await StoreService.shared.checkDailyQuotaOnServer(feature: feature)
        }
        var executeTidy: (String) async throws -> String = { content in
            let action = AIQuickAction.ActionType.smartFormat.defaultAction
            return try await action.execute(on: content)
        }
        var generateAIEdit: (_ noteContent: String, _ userInput: String) async throws -> String = { content, userInput in
            let languageRule = LanguageDetection.languagePreservationRule(for: userInput + "\n" + content)
            let systemInstruction = """
            You are a professional writing assistant helping the user edit a note.
            Rules:
            \(languageRule)
            - Respond and update the note using the language derived from the user's request and context.
            - Preserve the original structure and formatting (including markdown, code blocks, and line breaks) unless the user explicitly requests changes.
            - Return only the updated note content, without any explanations or meta-commentary.
            """

            let prompt = """
            The user is editing a note with the following content:

            \(content)

            The user wants to: \(userInput)

            Please update the note based on the user's request.
            """

            return try await GeminiService.shared.generateContent(
                prompt: prompt,
                systemInstruction: systemInstruction
            )
        }
        var suggestTags: (_ content: String, _ existingTags: [String]) async throws -> [String] = { content, existingTags in
            try await TagService.shared.suggestTags(for: content, existingTags: existingTags)
        }
        var writeFile: (_ content: String, _ url: URL) throws -> Void = { content, url in
            try content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    enum NoteDetailAction {
        case onAppear
        case backTapped
        case tidyTapped
        case stopRecordingTapped
        case restoreTapped
        case deleteTapped
        case deletePermanentlyTapped
        case exportTapped
        case aiUndoTapped
        case aiSaveTapped
        case aiRetryTapped
        case removeTagTapped(Tag)
        case confirmTagTapped(String)
        case retryTranscriptionTapped
        case dismissRecordingErrorTapped
        case dismissVoiceProcessingErrorTapped
    }

    @Published var showDeleteConfirmation = false
    @Published var showPermanentDeleteConfirmation = false
    @Published var inputText = ""
    @Published var isVoiceMode = false
    @Published var isProcessing = false

    @Published var showAIToolbar = false
    @Published var aiOriginalContent: String?
    @Published var isProgrammaticContentUpdate = false

    @Published var initialContent: String = ""
    @Published var initialTags: Set<UUID> = []

    @Published var showAddTagAlert = false
    @Published var newTagName = ""
    @Published var newTagColorHex = TagColorService.defaultColorHex

    @Published var showExportSheet = false
    @Published var exportURL: URL?
    @Published var showExportError = false
    @Published var exportErrorMessage = ""

    @Published var showUpgradeSheet = false
    @Published var showSubscription = false
    @Published var upgradeTitle = ""

    @Published var recordingDuration: TimeInterval = 0
    @Published var awaitingVoiceEditResult = false
    @Published private(set) var noteInitiatedRecording = false

    let note: Note

    private(set) var modelContext: ModelContext?
    private(set) var syncManager: SyncManager?
    private(set) var speechRecognizer: SpeechRecognizer?
    private(set) var voiceService: VoiceProcessingService = .shared

    private var dismissAction: (() -> Void)?
    var hasRequestedTagSuggestions = false

    let dependencies: Dependencies

    init(note: Note, dependencies: Dependencies = Dependencies()) {
        self.note = note
        self.dependencies = dependencies
    }

    func configure(
        modelContext: ModelContext,
        syncManager: SyncManager,
        speechRecognizer: SpeechRecognizer,
        voiceService: VoiceProcessingService? = nil,
        dismissAction: @escaping () -> Void
    ) {
        if self.modelContext == nil {
            self.initialContent = note.content
            self.initialTags = Set(note.tags.map { $0.id })
        }

        self.modelContext = modelContext
        self.syncManager = syncManager
        self.speechRecognizer = speechRecognizer
        self.voiceService = voiceService ?? .shared
        self.dismissAction = dismissAction
    }

    func configureForTesting(
        modelContext: ModelContext,
        dismissAction: @escaping () -> Void = {}
    ) {
        if self.modelContext == nil {
            self.initialContent = note.content
            self.initialTags = Set(note.tags.map { $0.id })
        }

        self.modelContext = modelContext
        self.dismissAction = dismissAction
    }

    var isDeleted: Bool {
        note.deletedAt != nil
    }

    var isVoiceProcessing: Bool {
        guard let state = voiceService.processingStates[note.id], case .processing = state else {
            return false
        }
        return true
    }

    var processingStage: VoiceProcessingStage? {
        guard let state = voiceService.processingStates[note.id],
              case .processing(let stage) = state else {
            return nil
        }
        return stage
    }

    var completedOriginalText: String? {
        guard let state = voiceService.processingStates[note.id],
              case .completed(let originalText) = state else {
            return nil
        }
        return originalText
    }

    var voiceProcessingErrorMessage: String? {
        guard let state = voiceService.processingStates[note.id],
              case .failed(let message) = state else {
            return nil
        }
        return message
    }

    var recordingErrorMessage: String? {
        // Only show recording errors if this note initiated the recording
        guard noteInitiatedRecording else { return nil }
        guard case let .error(message) = speechRecognizer?.recordingState else {
            return nil
        }
        return message
    }

    var trashCountdownText: String? {
        guard let deletedAt = note.deletedAt else { return nil }
        let daysRemaining = TrashPolicy.daysRemaining(from: deletedAt)
        if daysRemaining == 0 {
            return String(localized: "This note will be permanently deleted today.")
        }
        return String(
            format: String(localized: "This note will be permanently deleted in %lld days."),
            Int64(daysRemaining)
        )
    }

    var isInteractionEnabled: Bool {
        !isDeleted && !isProcessing && !isVoiceProcessing
    }

    var isTidyEnabled: Bool {
        isInteractionEnabled && !note.content.isEmpty
    }

    func send(_ action: NoteDetailAction) {
        switch action {
        case .onAppear:
            onAppear()
        case .backTapped:
            updateTimestampAndDismiss()
        case .tidyTapped:
            Task { await executeTidyAction() }
        case .stopRecordingTapped:
            stopRecording()
        case .restoreTapped:
            restoreNote()
        case .deleteTapped:
            showDeleteConfirmation = true
        case .deletePermanentlyTapped:
            showPermanentDeleteConfirmation = true
        case .exportTapped:
            exportMarkdown()
        case .aiUndoTapped:
            undoAIContent()
        case .aiSaveTapped:
            saveAIContentAndDismissToolbar()
        case .aiRetryTapped:
            Task { await executeTidyAction() }
        case .removeTagTapped(let tag):
            removeTag(tag)
        case .confirmTagTapped(let tagName):
            confirmTag(tagName)
        case .retryTranscriptionTapped:
            awaitingVoiceEditResult = true
            speechRecognizer?.retryTranscription()
        case .dismissRecordingErrorTapped:
            noteInitiatedRecording = false
            speechRecognizer?.dismissError()
        case .dismissVoiceProcessingErrorTapped:
            voiceService.processingStates.removeValue(forKey: note.id)
        }
    }

    func onAppear() {
        guard modelContext != nil else { return }
        if note.tags.isEmpty && note.suggestedTags.isEmpty && !note.content.isEmpty {
            Task { await generateTagsIfNeeded(force: true) }
        }
    }

    func onContentChange(oldValue: String, newValue: String) {
        guard modelContext != nil else { return }
        if oldValue.isEmpty && !newValue.isEmpty && note.tags.isEmpty && note.suggestedTags.isEmpty {
            Task { await generateTagsIfNeeded(force: true) }
        }
    }

    func onRecordingStateChange(_ newState: SpeechRecognizer.RecordingState) {
        switch newState {
        case .processing:
            if awaitingVoiceEditResult {
                isProcessing = true
            }
        case .idle:
            noteInitiatedRecording = false
            guard awaitingVoiceEditResult else { return }
            isVoiceMode = false
            if let transcript = speechRecognizer?.transcript, !transcript.isEmpty {
                Task { await handleAIInput(voiceInput: transcript) }
            } else {
                isProcessing = false
            }
            awaitingVoiceEditResult = false
        case .error:
            if awaitingVoiceEditResult {
                isVoiceMode = false
                isProcessing = false
                awaitingVoiceEditResult = false
            }
        case .recording:
            isProcessing = false
        }
    }

    func updateRecordingDurationIfNeeded() {
        guard let speechRecognizer, speechRecognizer.isRecording, let startTime = speechRecognizer.recordingStartTime else {
            return
        }
        recordingDuration = Date().timeIntervalSince(startTime)
    }

    func startRecording() {
        Task {
            let canRecord = await dependencies.checkDailyQuota(.voice)
            guard canRecord else {
                upgradeTitle = "Daily voice limit reached"
                showUpgradeSheet = true
                return
            }

            guard let speechRecognizer else { return }
            noteInitiatedRecording = true
            isVoiceMode = true
            recordingDuration = 0
            awaitingVoiceEditResult = false
            speechRecognizer.transcript = ""
            speechRecognizer.startRecording(countsTowardQuota: true)
        }
    }

    func stopRecording() {
        awaitingVoiceEditResult = true
        speechRecognizer?.stopRecording()
    }

    func timeString(from interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func resetNewTagInput() {
        newTagName = ""
        if let modelContext {
            let fetchDescriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.deletedAt == nil })
            let allTags = (try? modelContext.fetch(fetchDescriptor)) ?? []
            newTagColorHex = TagColorService.autoColorHex(for: "", existingTags: allTags)
        } else {
            newTagColorHex = TagColorService.defaultColorHex
        }
        showAddTagAlert = true
    }

    func confirmNewTagFromAlert() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        confirmTag(trimmed, preferredColorHex: newTagColorHex)
        showAddTagAlert = false
    }

    func updateTimestampAndDismiss() {
        if isDeleted {
            dismissAction?()
            return
        }

        let currentTags = Set(note.tags.map { $0.id })
        let hasChanged = note.content != initialContent || currentTags != initialTags

        if note.isEmptyNote && !isVoiceProcessing {
            deleteNote()
            return
        }

        if hasChanged {
            note.updatedAt = dependencies.now()
            if let modelContext {
                TagService.shared.cleanupEmptyTags(context: modelContext, candidates: Array(note.tags))
            }
            persistAndSync()
        }

        dismissAction?()
    }

    func confirmDeleteNote() {
        deleteNote()
    }

    func confirmDeleteNotePermanently() {
        deleteNotePermanently()
    }

    func persistAndSync() {
        guard let modelContext else { return }
        try? modelContext.save()
        if let syncManager {
            Task { await syncManager.syncNow(context: modelContext) }
        }
    }

    private func deleteNote() {
        guard note.deletedAt == nil else {
            dismissAction?()
            return
        }

        if note.isEmptyNote {
            deleteNotePermanently()
            return
        }

        note.markDeleted()
        if let modelContext {
            TagService.shared.cleanupEmptyTags(context: modelContext, candidates: Array(note.tags))
        }
        persistAndSync()

        dismissAction?()
    }

    private func restoreNote() {
        guard note.deletedAt != nil else { return }
        let now = dependencies.now()
        note.deletedAt = nil
        note.updatedAt = now
        for tag in note.tags where tag.deletedAt != nil {
            tag.deletedAt = nil
            tag.updatedAt = now
        }
        persistAndSync()
    }

    private func deleteNotePermanently() {
        guard let modelContext else { return }
        let candidateTags = Array(note.tags)
        HardDeleteQueueStore.enqueue(noteIDs: [note.id], for: note.userId)
        modelContext.delete(note)
        TagService.shared.cleanupEmptyTags(context: modelContext, candidates: candidateTags)
        persistAndSync()
        dismissAction?()
    }

    func dismissAIToolbar() {
        withAnimation {
            showAIToolbar = false
            aiOriginalContent = nil
        }
    }
}
