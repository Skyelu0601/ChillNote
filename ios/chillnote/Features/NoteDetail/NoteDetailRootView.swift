import SwiftUI
import SwiftData

struct NoteDetailView: View {
    private struct VoiceAlertState: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    @Bindable var note: Note
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var syncManager: SyncManager
    @ObservedObject private var firstActionGuide: FirstActionGuideService
    @StateObject private var recipeManager = RecipeManager.shared
    @StateObject private var storeService = StoreService.shared

    @StateObject private var viewModel: NoteDetailViewModel
    @StateObject private var conversation: NoteConversationStore
    @State private var activeVoiceAlert: VoiceAlertState?
    @State private var editorController = RichTextEditorController()
    @State private var workspacePage: NoteDetailWorkspacePage = .script
    @State private var isEditorActive = false
    @State private var pendingLinkImportUpgrade = false

    private var noteContentBinding: Binding<String> {
        Binding(
            get: { note.content },
            set: { note.updateContent($0) }
        )
    }

    private var firstActionSpotlight: FirstActionGuideSpotlightConfiguration? {
        guard firstActionGuide.targetNoteID == note.id else { return nil }

        switch firstActionGuide.stage {
        case .tapCreateTab:
            return FirstActionGuideSpotlightConfiguration(
                target: .createTab,
                message: L10n.text("onboarding.first_action.create_tab"),
                step: 4
            )
        case .tapAISkills:
            return FirstActionGuideSpotlightConfiguration(
                target: .aiSkills,
                message: L10n.text("onboarding.first_action.ai_skills"),
                step: 5
            )
        case .tapRecordTab:
            return FirstActionGuideSpotlightConfiguration(
                target: .recordTab,
                message: L10n.text("onboarding.first_action.record_tab"),
                step: 6
            )
        case .tapTeleprompter:
            return FirstActionGuideSpotlightConfiguration(
                target: .teleprompter,
                message: L10n.text("onboarding.first_action.teleprompter"),
                step: 7
            )
        default:
            return nil
        }
    }

    init(note: Note, isNewBlankDraft: Bool = false,
         conversationStore: NoteConversationStore? = nil,
         firstActionGuide: FirstActionGuideService = .shared,
         initialWorkspace: NoteDetailWorkspacePage = .script) {
        self.note = note
        _firstActionGuide = ObservedObject(wrappedValue: firstActionGuide)
        _viewModel = StateObject(wrappedValue: NoteDetailViewModel(note: note, isNewBlankDraft: isNewBlankDraft))
        _conversation = StateObject(wrappedValue: conversationStore ?? NoteConversationStore(note: note))
        _workspacePage = State(initialValue: initialWorkspace)
    }

    var body: some View {
        ZStack {
            Color.bgSecondary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                NoteDetailHeaderView(
                    isDeleted: viewModel.isDeleted,
                    onBack: {
                        editorController.endEditing()
                        sendAfterFlushing(.backTapped)
                    },
                    onRestore: { viewModel.send(.restoreTapped) },
                    onAddTopic: { viewModel.resetNewTagInput() },
                    onExport: { sendAfterFlushing(.exportTapped) },
                    onDelete: { conversation.cancel(); sendAfterFlushing(.deleteTapped) }
                )
                .padding(.horizontal, 20)
                .padding(.top, 12)

                if let trashCountdownText = viewModel.trashCountdownText {
                    HStack(spacing: 10) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.red.opacity(0.8))
                        Text(trashCountdownText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.textSub)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                if shouldShowContextSection {
                    NoteDetailContextSectionView(
                        note: note,
                        isDeleted: viewModel.isDeleted,
                        creditActionTitle: L10n.text(
                            storeService.currentTier == .pro
                                ? "common.try_again"
                                : "sidebar.membership.upgrade"
                        ),
                        onResolveImportCredits: resolveImportCredits,
                        onRemoveTag: { viewModel.send(.removeTagTapped($0)) }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 10)

                    Rectangle()
                        .fill(Color.borderSubtle)
                        .frame(height: 1)
                }

                NoteDetailWorkspacePicker(
                    selection: workspacePage,
                    isCreateEnabled: viewModel.isAISkillsEnabled,
                    guideRequiredPage: guideRequiredWorkspacePage,
                    guideTarget: guideWorkspaceTarget,
                    onSelect: selectWorkspacePage
                )

                GeometryReader { geometry in
                    if workspacePage == .create {
                        NoteConversationView(
                            store: conversation, recipes: workspaceRecipes,
                            enabled: viewModel.isInteractionEnabled,
                            content: note.content, onSkill: startAISkill,
                            save: viewModel.replaceConversationContent
                        )
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            let minimumContentHeight = max(120, geometry.size.height)
                            switch workspacePage {
                            case .script:
                                NoteDetailEditorSectionView(
                                    noteContent: noteContentBinding,
                                    editorController: editorController,
                                    isDeleted: viewModel.isDeleted,
                                    isVoiceProcessing: viewModel.isVoiceProcessing,
                                    minimumHeight: minimumContentHeight,
                                    isEditing: $isEditorActive,
                                    onFinalTextCommit: viewModel.stageFinalEditorText
                                )
                            case .create:
                                EmptyView()
                            case .record:
                                NoteDetailRecordPageView(
                                    script: note.content,
                                    isEnabled: viewModel.isInteractionEnabled,
                                    minimumHeight: minimumContentHeight,
                                    onStartRecording: openTeleprompter
                                )
                            }
                        }
                        .scrollDismissesKeyboard(.interactively)
                    }
                }

            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            NoteDetailOverlaysView(
                viewModel: viewModel,
                onBeforeContentAction: editorController.flush
            )
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if shouldShowTranscriptReviewPrompt {
                FirstActionTranscriptReviewPromptView(
                    onContinue: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            firstActionGuide.markTranscriptReviewed(in: note.id)
                        }
                    },
                    onSkip: { firstActionGuide.dismiss() }
                )
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(Color.bgSecondary)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .firstActionGuideSpotlight(
            configuration: firstActionSpotlight,
            onSkip: { firstActionGuide.dismiss() }
        )
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $viewModel.showTeleprompterCamera) {
            TeleprompterCameraView(initialScript: note.content)
        }
        .noteDetailAlertsAndSheets(
            viewModel: viewModel
        )
        .onChange(of: viewModel.voiceProcessingErrorMessage) { _, message in
            guard let message else { return }
            AppInteractionFeedback.error()
            activeVoiceAlert = VoiceAlertState(
                title: VoiceErrorPresentation.transcriptionFailedTitle,
                message: VoiceErrorPresentation.userMessage(for: message)
            )
        }
        .onChange(of: conversation.busy) { _, busy in
            if !busy { reconcileConversationGuide() }
        }
        .onChange(of: storeService.currentTier) { _, tier in
            guard tier == .pro, pendingLinkImportUpgrade else { return }
            pendingLinkImportUpgrade = false
            viewModel.retryInsufficientCreditsLinkImport()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                editorController.flush()
                viewModel.commitPendingEdits()
            }
        }
        .onChange(of: firstActionGuide.stage) { _, _ in
            syncWorkspaceWithFirstActionGuide()
        }
        .animation(.easeInOut(duration: 0.2), value: isEditorActive)
        .alert(item: $activeVoiceAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text(L10n.text("common.ok"))) {
                    viewModel.send(.dismissVoiceProcessingErrorTapped)
                }
            )
        }
        .onAppear {
            AppInteractionFeedback.prepare()
            viewModel.configure(
                modelContext: modelContext,
                syncManager: syncManager,
                dismissAction: { dismiss() }
            )
            syncWorkspaceWithFirstActionGuide()
            reconcileConversationGuide()
        }
        .onDisappear {
            conversation.cancel()
            editorController.flush()
            viewModel.commitPendingEdits()
        }
    }

    private func sendAfterFlushing(_ action: NoteDetailViewModel.NoteDetailAction) {
        editorController.flush()
        viewModel.send(action)
    }

    private func resolveImportCredits() {
        if storeService.currentTier == .pro {
            viewModel.retryInsufficientCreditsLinkImport()
        } else {
            pendingLinkImportUpgrade = true
            viewModel.showSubscription = true
        }
    }

    private func selectWorkspacePage(_ page: NoteDetailWorkspacePage) {
        guard page != workspacePage else { return }
        guard guideRequiredWorkspacePage == nil || guideRequiredWorkspacePage == page else { return }
        AppInteractionFeedback.selectionChanged()
        if page != .script {
            editorController.endEditing()
            editorController.flush()
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            workspacePage = page
        }

        switch page {
        case .create:
            firstActionGuide.markCreateTabTapped(in: note.id)
        case .record:
            firstActionGuide.markRecordTabTapped(in: note.id)
        case .script:
            break
        }
    }

    private func startAISkill(_ recipe: AgentRecipe) {
        editorController.endEditing()
        editorController.flush()
        firstActionGuide.markAISkillsTapped(in: note.id)
        conversation.send(recipe: recipe)
    }

    private func openTeleprompter() {
        editorController.endEditing()
        editorController.flush()
        firstActionGuide.markTeleprompterTapped(in: note.id)
        viewModel.send(.teleprompterTapped)
    }

    private var workspaceRecipes: [AgentRecipe] {
        let installed = recipeManager.favoriteRecipes

        if !installed.isEmpty {
            return installed
        }

        guard firstActionGuide.targetNoteID == note.id,
              firstActionGuide.stage == .tapAISkills,
              let starterSkill = AgentRecipe.allRecipes.first(where: { $0.id == "hook_generator" }) else {
            return []
        }
        return [starterSkill]
    }

    private var guideRequiredWorkspacePage: NoteDetailWorkspacePage? {
        guard firstActionGuide.targetNoteID == note.id else { return nil }

        switch firstActionGuide.stage {
        case .reviewTranscript:
            return .script
        case .tapCreateTab, .tapAISkills, .waitingForAISkillsDismissal, .reviewAIReply:
            return .create
        case .tapRecordTab, .tapTeleprompter:
            return .record
        default:
            return nil
        }
    }

    private var guideWorkspaceTarget: FirstActionGuideTarget? {
        switch firstActionGuide.stage {
        case .tapCreateTab:
            return .createTab
        case .tapRecordTab:
            return .recordTab
        default:
            return nil
        }
    }

    private var shouldShowContextSection: Bool {
        note.sourceMetadata != nil
            || note.importStatus == .queued
            || note.importStatus == .processing
            || note.importStatus == .failed
            || note.tags.contains { $0.deletedAt == nil }
    }

    private var shouldShowTranscriptReviewPrompt: Bool {
        firstActionGuide.targetNoteID == note.id
            && firstActionGuide.stage == .reviewTranscript
    }

    private func reconcileConversationGuide() {
        guard !conversation.busy else { return }
        firstActionGuide.reconcileConversation(in: note.id, hasReply: conversation.turns.contains { $0.answer != nil })
    }

    private func syncWorkspaceWithFirstActionGuide() {
        guard firstActionGuide.targetNoteID == note.id else { return }

        let page: NoteDetailWorkspacePage?
        switch firstActionGuide.stage {
        case .reviewTranscript:
            page = .script
        case .tapAISkills, .waitingForAISkillsDismissal, .reviewAIReply:
            page = .create
        case .tapRecordTab:
            // Leave the reply visible until the user chooses Record.
            page = nil
        case .tapTeleprompter:
            page = .record
        default:
            page = nil
        }

        guard let page, workspacePage != page else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            workspacePage = page
        }
    }

}

#Preview {
    NoteDetailView(note: Note(content: "Hello", userId: "preview-user"))
        .environmentObject(SpeechRecognizer())
        .modelContainer(DataService.shared.container!)
        .environmentObject(SyncManager())
}

#if DEBUG
struct NoteDetailWorkspaceDesignPreview: View {
    @StateObject private var model = NoteDetailPreviewModel()

    var body: some View {
        NavigationStack {
            NoteDetailView(note: model.note, conversationStore: model.conversation,
                           firstActionGuide: model.guide,
                           initialWorkspace: model.guidePreview ? .script : (model.chatPreview ? .create : .script))
        }
        .modelContainer(model.container)
        .environmentObject(SyncManager())
    }
}

@MainActor
private final class NoteDetailPreviewModel: ObservableObject {
    let note: Note
    let container: ModelContainer
    let conversation: NoteConversationStore?
    let guide: FirstActionGuideService
    let guidePreview = ProcessInfo.processInfo.arguments.contains("-note-chat-guide-preview")
    let chatPreview = ProcessInfo.processInfo.arguments.contains("-note-chat-design-preview")

    init() {
        let previewContent = "Tier three countries tend to be the cheapest with the most purchasing power. If you want to optimize your budget, start with tier two and tier three countries and keep testing.\n\nToday's guest runs multiple apps, and one of them just reached more than $10,000 in the last month."
        let content = ProcessInfo.processInfo.arguments.contains("-note-detail-design-preview-long")
            ? Array(repeating: previewContent, count: 6).joined(separator: "\n\n")
            : previewContent
        let previewNote = Note(
            content: content,
            userId: "design-preview-user"
        )

        if ProcessInfo.processInfo.arguments.contains("-note-detail-design-preview-video") {
            previewNote.applySourceMetadata(
                NoteSourceMetadata(
                    url: "https://www.youtube.com/watch?v=preview",
                    title: "I Built a $10K/Month App With Only Apple Ads",
                    platformID: "youtube",
                    platformName: "YouTube",
                    host: "youtube.com",
                    authorName: "Arthur Spalanzani"
                )
            )
        }

        note = previewNote
        container = try! ModelContainer(for: Note.self, Tag.self, ChecklistItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        container.mainContext.insert(previewNote)
        guide = FirstActionGuideService(defaults: UserDefaults(suiteName: "guide-preview-" + UUID().uuidString)!)
        if guidePreview {
            guide.configure(userId: "preview", accountCreatedAt: Date())
            guide.registerSharedVideoImport(noteID: previewNote.id)
            guide.updateTargetImportStatus(.completed)
            guide.markImportedNoteOpened(previewNote.id)
        }
        if chatPreview {
            var dependencies = NoteConversationStore.Dependencies()
            dependencies.consent = { true }
            dependencies.authorized = { _ in true }
            dependencies.refreshCredits = {}
            dependencies.generate = { prompt, _, _ in
                try await Task.sleep(for: .milliseconds(200))
                if ProcessInfo.processInfo.arguments.contains("-note-chat-long-reply-preview") {
                    return (1...12).map { index in
                        "Section \(index). Capture the thought before it disappears. A quick voice note is enough. You can shape it into a story later. Keep the original meaning while making the script natural and easy to follow."
                    }.joined(separator: "\n\n")
                }
                return prompt.contains("Make it shorter")
                    ? "Capture your idea now. Shape it into a script later."
                    : "Great ideas rarely arrive on schedule.\n\nCapture the thought before it disappears. A quick voice note is enough.\n\nYou can shape it into a story later."
            }
            conversation = NoteConversationStore(note: previewNote,
                directory: FileManager.default.temporaryDirectory.appendingPathComponent("note-chat-preview-" + UUID().uuidString),
                dependencies: dependencies)
        } else { conversation = nil }
    }

}

#endif
