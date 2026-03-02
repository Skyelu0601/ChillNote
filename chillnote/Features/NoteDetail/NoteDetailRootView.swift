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

    @StateObject private var viewModel: NoteDetailViewModel
    @State private var activeVoiceAlert: VoiceAlertState?

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
            viewModel.configure(
                modelContext: modelContext,
                syncManager: syncManager,
                speechRecognizer: speechRecognizer,
                dismissAction: { dismiss() }
            )
            viewModel.send(.onAppear)
        }
        .onChange(of: note.content) { oldValue, newValue in
            viewModel.onContentChange(oldValue: oldValue, newValue: newValue)
        }
    }
}

#Preview {
    NoteDetailView(note: Note(content: "Hello", userId: "preview-user"))
        .environmentObject(SpeechRecognizer())
        .modelContainer(DataService.shared.container!)
        .environmentObject(SyncManager())
}
