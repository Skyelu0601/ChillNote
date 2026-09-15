import Foundation
import OSLog
import SwiftData
import SwiftUI

@MainActor
final class NoteDetailViewModel: ObservableObject {
    private static let logger = Logger(subsystem: "com.chillnote.app", category: "note-detail")

    struct Dependencies {
        var now: () -> Date = Date.init
        var writeFile: (_ content: String, _ url: URL) throws -> Void = { content, url in
            try content.write(to: url, atomically: true, encoding: .utf8)
        }
        var ensureAIConsent: () async -> Bool = {
            await AIConsentManager.shared.ensureConsentIfNeeded(for: .text)
        }
        var generateAISkill: (AgentRecipe, String, String?) async throws -> String = {
            try await $0.generateResult(from: $1, userInstruction: $2)
        }
        var refreshCredits: () async -> Void = { await StoreService.shared.fetchCreditBalance() }
        var capture: @MainActor (String, [String: Any]) -> Void = { ProductAnalytics.shared.capture($0, properties: $1) }
    }

    enum NoteDetailAction {
        case backTapped
        case restoreTapped
        case deleteTapped
        case exportTapped
        case aiSkillsTapped
        case teleprompterTapped
        case aiUndoTapped
        case aiSaveTapped
        case aiRetryTapped
        case removeTagTapped(Tag)
        case confirmTagTapped(String)
        case dismissVoiceProcessingErrorTapped
    }

    @Published var showDeleteConfirmation = false
    @Published var isProcessing = false
    @Published var isAwaitingAIConsent = false
    var queuedAISkill: (recipe: AgentRecipe, instruction: String?)?

    @Published var showAIToolbar = false
    @Published var aiOriginalContent: String?
    @Published var isProgrammaticContentUpdate = false
    @Published var editorSelection = RichTextEditorSelection()
    @Published var showAISkillsSheet = false
    @Published var showAISkillTranslateSheet = false
    @Published var aiSkillPreview: NoteAISkillPreview?
    @Published var aiSkillErrorMessage: String?
    @Published var pendingAISkillRecipe: AgentRecipe?
    var lastAITransformation: NoteAITransformation?

    @Published var initialContent: String = ""
    @Published var initialTags: Set<UUID> = []

    @Published var showAddTagAlert = false
    @Published var newTagColorHex = TagColorService.defaultColorHex

    @Published var showExportSheet = false
    @Published var exportURL: URL?
    @Published var showExportError = false
    @Published var exportErrorMessage = ""

    @Published var showSubscription = false
    @Published var showTeleprompterCamera = false

    let note: Note

    private(set) var modelContext: ModelContext?
    private(set) var syncManager: SyncManager?
    private(set) var voiceService: VoiceProcessingService = .shared

    private var dismissAction: (() -> Void)?
    private var hasPermanentlyDeletedNote = false
    private var canDiscardEmptyDraft: Bool
    private var finalEditorText: (markdown: String, previousMarkdown: String)?

    let dependencies: Dependencies

    init(note: Note, isNewBlankDraft: Bool = false, dependencies: Dependencies = Dependencies()) {
        self.note = note
        self.canDiscardEmptyDraft = isNewBlankDraft && note.isEmptyNote
        self.dependencies = dependencies
    }

    func configure(
        modelContext: ModelContext,
        syncManager: SyncManager,
        voiceService: VoiceProcessingService? = nil,
        dismissAction: @escaping () -> Void
    ) {
        if self.modelContext == nil {
            self.initialContent = note.content
            self.initialTags = Set(note.tags.map { $0.id })
        }

        self.modelContext = modelContext
        self.syncManager = syncManager
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
        hasPermanentlyDeletedNote || note.deletedAt != nil
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

    var trashCountdownText: String? {
        guard let deletedAt = note.deletedAt else { return nil }
        let daysRemaining = TrashPolicy.daysRemaining(from: deletedAt)
        if daysRemaining == 0 {
            return L10n.text("note_detail.trash.deleted_today")
        }
        return L10n.text("note_detail.trash.deleted_in_days", Int64(daysRemaining))
    }

    var isInteractionEnabled: Bool {
        !isDeleted && !isProcessing && !isAwaitingAIConsent && !isVoiceProcessing
    }

    var isAISkillsEnabled: Bool {
        isInteractionEnabled
    }

    func send(_ action: NoteDetailAction) {
        switch action {
        case .backTapped:
            updateTimestampAndDismiss()
        case .restoreTapped:
            restoreNote()
        case .deleteTapped:
            showDeleteConfirmation = true
        case .exportTapped:
            exportMarkdown()
        case .aiSkillsTapped:
            ProductAnalytics.shared.capture("skill_picker_viewed", properties: ["entry_point": "note_detail"])
            showAISkillsSheet = true
        case .teleprompterTapped:
            showTeleprompterCamera = true
        case .aiUndoTapped:
            undoAIContent()
        case .aiSaveTapped:
            saveAIContentAndDismissToolbar()
        case .aiRetryTapped:
            Task { await retryLastAITransformation() }
        case .removeTagTapped(let tag):
            removeTag(tag)
        case .confirmTagTapped(let tagName):
            confirmTag(tagName)
        case .dismissVoiceProcessingErrorTapped:
            voiceService.processingStates.removeValue(forKey: note.id)
        }
    }

    func resetNewTagInput() {
        if let modelContext {
            let fetchDescriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.deletedAt == nil })
            let allTags: [Tag]
            do {
                allTags = try modelContext.fetch(fetchDescriptor)
            } catch {
                Self.logger.error("Failed to fetch tags for new tag color: \(error.localizedDescription, privacy: .public)")
                newTagColorHex = TagColorService.defaultColorHex
                showAddTagAlert = true
                return
            }
            newTagColorHex = TagColorService.autoColorHex(for: "", existingTags: allTags)
        } else {
            newTagColorHex = TagColorService.defaultColorHex
        }
        showAddTagAlert = true
    }

    func updateTimestampAndDismiss() {
        if isDeleted {
            dismissAction?()
            return
        }

        _ = commitPendingEdits(discardEmptyDraft: true)
        dismissAction?()
    }

    /// Commits editor mutations without requiring a particular navigation path.
    /// The baseline advances only after the local save succeeds, which makes the
    /// background, disappearance and explicit-back hooks safe to call together.
    /// Only explicit back navigation may discard a newly created blank draft.
    @discardableResult
    func commitPendingEdits(discardEmptyDraft: Bool = false) -> Bool {
        guard !isDeleted else { return false }

        if let finalEditorText {
            self.finalEditorText = nil
            // A newer external change wins over an editor that already detached.
            if note.content == finalEditorText.previousMarkdown {
                note.updateContent(finalEditorText.markdown)
            }
        }

        let currentTags = Set(note.tags.map { $0.id })
        // Eligibility only moves from disposable to retained. A later blank
        // autosave must never make a previously saved note disposable again.
        if !note.isEmptyNote || note.sourceURL != nil || note.importStatus != .none
            || note.importJobId != nil || voiceService.processingStates[note.id] != nil
            || currentTags != initialTags {
            canDiscardEmptyDraft = false
        }

        if discardEmptyDraft && canDiscardEmptyDraft && note.isEmptyNote {
            return deleteNotePermanently(shouldDismiss: false)
        }

        let hasChanged = note.content != initialContent || currentTags != initialTags
        guard hasChanged else { return false }

        if let modelContext {
            note.syncContentStructure(with: modelContext)
        }
        note.updatedAt = dependencies.now()
        if let modelContext {
            TagService.shared.cleanupEmptyTags(context: modelContext, candidates: Array(note.tags))
        }
        guard persistAndSync() else { return false }

        initialContent = note.content
        initialTags = currentTags
        return true
    }

    func confirmDeleteNote() {
        deleteNote()
    }

    /// Called during UIKit teardown. Stage plain data only; do not publish view
    /// state here. onDisappear can drain this before deciding an empty note is
    /// disposable, and the queued save also covers workspace-page replacement.
    func stageFinalEditorText(_ markdown: String, _ previousMarkdown: String) {
        guard !hasPermanentlyDeletedNote else { return }
        finalEditorText = (markdown, previousMarkdown)
        DispatchQueue.main.async {
            // onDisappear may already have saved (or deleted) the model. Do not
            // touch its SwiftData backing after the staged edit has been drained.
            guard self.finalEditorText != nil else { return }
            self.commitPendingEdits()
        }
    }

    @discardableResult
    func persistAndSync(hardDeletedNoteIDs: [UUID] = []) -> Bool {
        guard let modelContext else { return false }
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Failed to save note detail changes before sync: \(error.localizedDescription, privacy: .public)")
            return false
        }
        if !hardDeletedNoteIDs.isEmpty {
            HardDeleteQueueStore.enqueue(noteIDs: hardDeletedNoteIDs, for: note.userId)
            Task { await NotesSearchIndexer.shared.remove(noteIDs: hardDeletedNoteIDs) }
        }
        if let syncManager {
            Task { await syncManager.syncNow(context: modelContext) }
        }
        return true
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

    @discardableResult
    private func deleteNotePermanently(shouldDismiss: Bool = true) -> Bool {
        guard !hasPermanentlyDeletedNote, let modelContext else { return false }
        let candidateTags = Array(note.tags)
        modelContext.delete(note)
        TagService.shared.cleanupEmptyTags(context: modelContext, candidates: candidateTags)
        guard persistAndSync(hardDeletedNoteIDs: [note.id]) else { return false }
        hasPermanentlyDeletedNote = true
        if shouldDismiss {
            dismissAction?()
        }
        return true
    }

    func dismissAIToolbar() {
        withAnimation {
            showAIToolbar = false
            aiOriginalContent = nil
        }
    }

    func retryInsufficientCreditsLinkImport() {
        guard note.importStatus == .failed,
              note.importErrorCode == "insufficient_credits",
              let source = note.sourceMetadata,
              let url = URL(string: source.url) else { return }

        note.importStatus = .queued
        note.importErrorCode = nil
        note.importJobId = nil
        note.importStartedAt = dependencies.now()
        note.importCompletedAt = nil
        note.updatedAt = dependencies.now()
        guard persistAndSync() else { return }

        Task {
            do {
                let job = try await QuickCaptureImportService.shared.startAsyncWebLinkImport(
                    url: url,
                    noteID: note.id,
                    placeholderContent: note.content,
                    source: source,
                    section: note.section
                )
                StoreService.shared.applyBackendCreditBalance(job.balance, tier: job.tier)
                note.importJobId = job.jobId
                note.importStatus = job.status == "processing" ? .processing : .queued
                note.updatedAt = dependencies.now()
                _ = persistAndSync()
            } catch {
                note.importStatus = .failed
                note.importErrorCode = if case QuickCaptureImportError.insufficientCredits = error {
                    "insufficient_credits"
                } else {
                    "job_start_failed"
                }
                note.importCompletedAt = dependencies.now()
                note.updatedAt = dependencies.now()
                _ = persistAndSync()
                if case QuickCaptureImportError.insufficientCredits = error {
                    showSubscription = true
                } else {
                    aiSkillErrorMessage = error.localizedDescription
                }
            }
        }
    }
}
