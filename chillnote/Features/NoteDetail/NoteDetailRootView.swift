import SwiftUI
import SwiftData

struct NoteDetailView: View {
    private enum VoiceAlertAction {
        case retryTranscription
        case dismissOnly
    }

    private struct VoiceAlertState: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let action: VoiceAlertAction
    }

    @Bindable var note: Note
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var syncManager: SyncManager
    @EnvironmentObject private var speechRecognizer: SpeechRecognizer
    @StateObject private var storeService = StoreService.shared

    @StateObject private var viewModel: NoteDetailViewModel
    @State private var activeVoiceAlert: VoiceAlertState?
    @State private var activePaywallContext: PaywallContext?
    @State private var firstVoiceSuccessTask: Task<Void, Never>?
    @AppStorage("paywall.has_shown_first_voice_success") private var hasShownFirstVoiceSuccessPaywall = false

    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

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
                    isRecording: speechRecognizer.isRecording,
                    recordingTimeString: viewModel.timeString(from: viewModel.recordingDuration),
                    isTidyEnabled: viewModel.isTidyEnabled,
                    onBack: { viewModel.send(.backTapped) },
                    onRestore: { viewModel.send(.restoreTapped) },
                    onStopRecording: { viewModel.send(.stopRecordingTapped) },
                    onTidy: { viewModel.send(.tidyTapped) },
                    onExport: { viewModel.send(.exportTapped) },
                    onDelete: { viewModel.send(.deleteTapped) },
                    onDeletePermanently: { viewModel.send(.deletePermanentlyTapped) }
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
                    noteContent: $note.content,
                    isDeleted: viewModel.isDeleted,
                    isProcessing: viewModel.isProcessing,
                    isVoiceProcessing: viewModel.isVoiceProcessing,
                    onConfirmTag: { viewModel.send(.confirmTagTapped($0)) },
                    onRemoveTag: { viewModel.send(.removeTagTapped($0)) },
                    onAddTagClick: { viewModel.resetNewTagInput() }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            NoteDetailOverlaysView(viewModel: viewModel)
        }
        .navigationBarHidden(true)
        .noteDetailAlertsAndSheets(viewModel: viewModel)
        .onReceive(timer) { _ in
            viewModel.updateRecordingDurationIfNeeded()
        }
        .onChange(of: speechRecognizer.recordingState) { _, newState in
            viewModel.onRecordingStateChange(newState)
        }
        .onChange(of: viewModel.recordingErrorMessage) { _, message in
            guard let message else { return }
            activeVoiceAlert = VoiceAlertState(
                title: VoiceErrorPresentation.transcriptionFailedTitle,
                message: VoiceErrorPresentation.userMessage(for: message),
                action: .retryTranscription
            )
        }
        .onChange(of: viewModel.voiceProcessingErrorMessage) { _, message in
            guard let message else { return }
            activeVoiceAlert = VoiceAlertState(
                title: VoiceErrorPresentation.transcriptionFailedTitle,
                message: VoiceErrorPresentation.userMessage(for: message),
                action: .dismissOnly
            )
        }
        .onChange(of: viewModel.completedOriginalText) { _, value in
            guard value != nil else { return }
            guard !hasShownFirstVoiceSuccessPaywall else { return }
            guard storeService.currentTier == .free else { return }
            guard activeNotesCount(for: note.userId) >= 3 else { return }

            firstVoiceSuccessTask?.cancel()
            firstVoiceSuccessTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                guard !Task.isCancelled else { return }
                guard activeVoiceAlert == nil else { return }
                guard activePaywallContext == nil else { return }
                guard viewModel.activePaywallContext == nil else { return }
                guard !viewModel.showSubscription else { return }
                guard viewModel.completedOriginalText != nil else { return }

                hasShownFirstVoiceSuccessPaywall = true
                PaywallStateStore.hasShownFirstVoiceSuccessPaywall = true
                activePaywallContext = .firstVoiceSuccess
            }
        }
        .alert(item: $activeVoiceAlert) { alert in
            switch alert.action {
            case .retryTranscription:
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text("Retry")) {
                        viewModel.triggerRetryHaptic()
                        viewModel.send(.retryTranscriptionTapped)
                    },
                    secondaryButton: .cancel {
                        viewModel.send(.dismissRecordingErrorTapped)
                    }
                )
            case .dismissOnly:
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK")) {
                        viewModel.send(.dismissVoiceProcessingErrorTapped)
                    }
                )
            }
        }
        .onAppear {
            hasShownFirstVoiceSuccessPaywall = PaywallStateStore.hasShownFirstVoiceSuccessPaywall
            viewModel.configure(
                modelContext: modelContext,
                syncManager: syncManager,
                speechRecognizer: speechRecognizer,
                dismissAction: { dismiss() }
            )
            viewModel.send(.onAppear)
        }
        .onDisappear {
            firstVoiceSuccessTask?.cancel()
        }
        .sheet(item: $activePaywallContext) { context in
            UpgradeBottomSheet(
                content: context.content,
                onUpgrade: {
                    activePaywallContext = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        viewModel.showSubscription = true
                    }
                },
                onDismiss: {
                    activePaywallContext = nil
                }
            )
            .presentationDetents([.height(context.content.preferredSheetHeight), .large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: note.content) { oldValue, newValue in
            viewModel.onContentChange(oldValue: oldValue, newValue: newValue)
        }
    }

    private func activeNotesCount(for userId: String) -> Int {
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate<Note> { note in
                note.userId == userId && note.deletedAt == nil
            }
        )
        return ((try? modelContext.fetch(descriptor)) ?? []).count
    }
}

#Preview {
    NoteDetailView(note: Note(content: "Hello", userId: "preview-user"))
        .environmentObject(SpeechRecognizer())
        .modelContainer(DataService.shared.container!)
        .environmentObject(SyncManager())
}
