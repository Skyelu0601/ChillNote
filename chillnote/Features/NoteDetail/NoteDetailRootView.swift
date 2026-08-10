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
    @ObservedObject private var firstActionGuide = FirstActionGuideService.shared

    @StateObject private var viewModel: NoteDetailViewModel
    @State private var activeVoiceAlert: VoiceAlertState?
    @State private var editorController = RichTextEditorController()

    private var noteContentBinding: Binding<String> {
        Binding(
            get: { note.content },
            set: { note.updateContent($0) }
        )
    }

    private var firstActionSpotlight: FirstActionGuideSpotlightConfiguration? {
        guard firstActionGuide.targetNoteID == note.id else { return nil }

        switch firstActionGuide.stage {
        case .tapAISkills:
            return FirstActionGuideSpotlightConfiguration(
                target: .aiSkills,
                message: L10n.text("onboarding.first_action.ai_skills"),
                step: 3
            )
        case .tapTeleprompter:
            return FirstActionGuideSpotlightConfiguration(
                target: .teleprompter,
                message: L10n.text("onboarding.first_action.teleprompter"),
                step: 4
            )
        default:
            return nil
        }
    }

    init(note: Note) {
        self.note = note
        _viewModel = StateObject(wrappedValue: NoteDetailViewModel(note: note))
    }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                NoteDetailHeaderView(
                    isDeleted: viewModel.isDeleted,
                    isAISkillsEnabled: viewModel.isAISkillsEnabled,
                    onBack: { sendAfterFlushing(.backTapped) },
                    onRestore: { viewModel.send(.restoreTapped) },
                    onAISkills: {
                        firstActionGuide.markAISkillsTapped(in: note.id)
                        sendAfterFlushing(.aiSkillsTapped)
                    },
                    onTeleprompter: {
                        firstActionGuide.markTeleprompterTapped(in: note.id)
                        sendAfterFlushing(.teleprompterTapped)
                    },
                    onExport: { sendAfterFlushing(.exportTapped) },
                    onDelete: { sendAfterFlushing(.deleteTapped) }
                )
                .padding(.horizontal, 16)
                .padding(.top, 10)

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

                NoteDetailEditorSectionView(
                    note: note,
                    noteContent: noteContentBinding,
                    editorSelection: $viewModel.editorSelection,
                    editorController: editorController,
                    isDeleted: viewModel.isDeleted,
                    isProcessing: viewModel.isProcessing,
                    isVoiceProcessing: viewModel.isVoiceProcessing,
                    onRemoveTag: { viewModel.send(.removeTagTapped($0)) },
                    onAddTagClick: { viewModel.resetNewTagInput() }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            NoteDetailOverlaysView(
                viewModel: viewModel,
                onBeforeContentAction: editorController.flush
            )
        }
        .firstActionGuideSpotlight(
            configuration: firstActionSpotlight,
            onSkip: { firstActionGuide.dismiss() }
        )
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $viewModel.showTeleprompterCamera) {
            TeleprompterCameraView(initialScript: note.content)
        }
        .noteDetailAlertsAndSheets(viewModel: viewModel)
        .onChange(of: viewModel.voiceProcessingErrorMessage) { _, message in
            guard let message else { return }
            activeVoiceAlert = VoiceAlertState(
                title: VoiceErrorPresentation.transcriptionFailedTitle,
                message: VoiceErrorPresentation.userMessage(for: message)
            )
        }
        .onChange(of: viewModel.showAISkillsSheet) { _, _ in
            advanceFirstActionGuideAfterAISkillsIfReady()
        }
        .onChange(of: viewModel.showAISkillTranslateSheet) { _, _ in
            advanceFirstActionGuideAfterAISkillsIfReady()
        }
        .onChange(of: viewModel.aiSkillPreview?.id) { _, _ in
            advanceFirstActionGuideAfterAISkillsIfReady()
        }
        .onChange(of: viewModel.isProcessing) { _, _ in
            advanceFirstActionGuideAfterAISkillsIfReady()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                editorController.flush()
            }
        }
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
            viewModel.configure(
                modelContext: modelContext,
                syncManager: syncManager,
                dismissAction: { dismiss() }
            )
            advanceFirstActionGuideAfterAISkillsIfReady()
        }
        .onDisappear {
            editorController.flush()
        }
    }

    private func sendAfterFlushing(_ action: NoteDetailViewModel.NoteDetailAction) {
        editorController.flush()
        viewModel.send(action)
    }

    private func advanceFirstActionGuideAfterAISkillsIfReady() {
        guard !viewModel.showAISkillsSheet,
              !viewModel.showAISkillTranslateSheet,
              viewModel.aiSkillPreview == nil,
              !viewModel.isProcessing else {
            return
        }
        firstActionGuide.markAISkillsFlowDismissed(in: note.id)
    }

}

#Preview {
    NoteDetailView(note: Note(content: "Hello", userId: "preview-user"))
        .environmentObject(SpeechRecognizer())
        .modelContainer(DataService.shared.container!)
        .environmentObject(SyncManager())
}
