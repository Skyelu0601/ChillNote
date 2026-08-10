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
    @Published var newTagName = ""
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

    let dependencies: Dependencies

    init(note: Note, dependencies: Dependencies = Dependencies()) {
        self.note = note
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

    var trashCountdownText: String? {
        guard let deletedAt = note.deletedAt else { return nil }
        let daysRemaining = TrashPolicy.daysRemaining(from: deletedAt)
        if daysRemaining == 0 {
            return L10n.text("note_detail.trash.deleted_today")
        }
        return L10n.text("note_detail.trash.deleted_in_days", Int64(daysRemaining))
    }

    var isInteractionEnabled: Bool {
        !isDeleted && !isProcessing && !isVoiceProcessing
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
        newTagName = ""
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
            if let modelContext {
                note.syncContentStructure(with: modelContext)
            }
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

    func persistAndSync() {
        guard let modelContext else { return }
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Failed to save note detail changes before sync: \(error.localizedDescription, privacy: .public)")
            return
        }
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
