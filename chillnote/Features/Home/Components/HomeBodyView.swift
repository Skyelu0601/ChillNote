import SwiftUI
import SwiftData

struct HomeBodyView: View {
    let state: HomeScreenState
    let dispatch: (HomeScreenAction) -> Void
    @FocusState.Binding var isSearchFocused: Bool
    let searchBar: AnyView

    private var navigationPathBinding: Binding<NavigationPath> {
        Binding(
            get: { state.navigationPath },
            set: { dispatch(.setNavigationPath($0)) }
        )
    }

    private var showingSettingsBinding: Binding<Bool> {
        Binding(
            get: { state.showingSettings },
            set: { dispatch(.setShowingSettings($0)) }
        )
    }

    private var showAIChatBinding: Binding<Bool> {
        Binding(
            get: { state.showAIChat },
            set: { dispatch(.setShowAIChat($0)) }
        )
    }

    private var showChillRecipesBinding: Binding<Bool> {
        Binding(
            get: { state.showChillRecipes },
            set: { dispatch(.setShowChillRecipes($0)) }
        )
    }

    private var showPendingRecordingsBinding: Binding<Bool> {
        Binding(
            get: { state.showPendingRecordings },
            set: { dispatch(.setShowPendingRecordings($0)) }
        )
    }

    private var customActionInputPresentedBinding: Binding<Bool> {
        Binding(
            get: { state.isCustomActionInputPresented },
            set: { dispatch(.setCustomActionInputPresented($0)) }
        )
    }

    private var customActionPromptBinding: Binding<String> {
        Binding(
            get: { state.customActionPrompt },
            set: { dispatch(.setCustomActionPrompt($0)) }
        )
    }

    private var translateInputPresentedBinding: Binding<Bool> {
        Binding(
            get: { state.isTranslateInputPresented },
            set: { dispatch(.setTranslateInputPresented($0)) }
        )
    }

    private var showDeleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { state.showDeleteConfirmation },
            set: { dispatch(.setShowDeleteConfirmation($0)) }
        )
    }

    private var showMergeSuccessAlertBinding: Binding<Bool> {
        Binding(
            get: { state.showMergeSuccessAlert },
            set: { dispatch(.setShowMergeSuccessAlert($0)) }
        )
    }

    private var showEmptyTrashConfirmationBinding: Binding<Bool> {
        Binding(
            get: { state.showEmptyTrashConfirmation },
            set: { dispatch(.setShowEmptyTrashConfirmation($0)) }
        )
    }

    private var showBatchTagSheetBinding: Binding<Bool> {
        Binding(
            get: { state.showBatchTagSheet },
            set: { dispatch(.setShowBatchTagSheet($0)) }
        )
    }

    private var sidebarPresentedBinding: Binding<Bool> {
        Binding(
            get: { state.isSidebarPresented },
            set: { dispatch(.setSidebarPresented($0)) }
        )
    }

    private var selectedTagBinding: Binding<Tag?> {
        Binding(
            get: { state.selectedTag },
            set: { dispatch(.setSelectedTag($0)) }
        )
    }

    private var trashSelectedBinding: Binding<Bool> {
        Binding(
            get: { state.isTrashSelected },
            set: { dispatch(.setTrashSelected($0)) }
        )
    }

    private var inputTextBinding: Binding<String> {
        Binding(
            get: { state.inputText },
            set: { dispatch(.setInputText($0)) }
        )
    }

    private var voiceModeBinding: Binding<Bool> {
        Binding(
            get: { state.isVoiceMode },
            set: { dispatch(.setVoiceMode($0)) }
        )
    }

    var body: some View {
        NavigationStack(path: navigationPathBinding) {
            rootContainer
        }
    }

    private var rootContainer: some View {
        ZStack(alignment: .bottom) {
            mainContent
            floatingVoiceInput
            selectionModeOverlay
            agentProgressOverlay
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.startLocation.x < 50 && value.translation.width > 60 {
                        dispatch(.openSidebar)
                    }
                }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary.ignoresSafeArea())
        .overlay {
            SidebarView(
                isPresented: sidebarPresentedBinding,
                selectedTag: selectedTagBinding,
                isTrashSelected: trashSelectedBinding,
                hasPendingRecordings: state.hasPendingRecordings,
                pendingRecordingsCount: state.pendingRecordingsCount,
                onSettingsTap: { dispatch(.showSettings) },
                onPendingRecordingsTap: { dispatch(.setShowPendingRecordings(true)) }
            )
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: showingSettingsBinding, onDismiss: {
            dispatch(.setAutoOpenPendingRecordings(false))
        }) {
            SettingsView()
        }
        .sheet(isPresented: showPendingRecordingsBinding) {
            NavigationStack {
                PendingRecordingsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                dispatch(.setShowPendingRecordings(false))
                            }
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: showAIChatBinding) {
            AIContextChatView(contextNotes: state.cachedContextNotes)
                .environmentObject(state.syncManager)
                .onDisappear {
                    dispatch(.aiChatDisappear)
                }
        }
        .sheet(isPresented: showChillRecipesBinding) {
            NavigationStack {
                ChillRecipesView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Close") {
                                dispatch(.closeChillRecipes)
                            }
                        }
                    }
            }
        }
        .alert("Ask Agent", isPresented: customActionInputPresentedBinding) {
            TextField("What should I do?", text: customActionPromptBinding)
            Button("Cancel", role: .cancel) {
                dispatch(.setCustomActionPrompt(""))
            }
            Button("Do it") {
                dispatch(.executePendingAgentAction(state.customActionPrompt))
                dispatch(.setCustomActionPrompt(""))
            }
        } message: {
            Text("Enter your instruction for these notes.")
        }
        .alert("Large Selection", isPresented: Binding(
            get: { state.showAskSoftLimitAlert },
            set: { _ in }
        )) {
            Button("Cancel", role: .cancel) { }
            Button("Continue") {
                dispatch(.confirmAskSoftLimit)
            }
        } message: {
            Text("You selected \(state.selectedNotes.count) notes. Asking AI with many notes may be slower and less accurate.")
        }
        .alert("Too Many Notes", isPresented: Binding(
            get: { state.showAskHardLimitAlert },
            set: { _ in }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You can ask AI about up to \(state.askHardLimit) notes at a time. Please reduce your selection.")
        }
        .alert("Large Selection", isPresented: Binding(
            get: { state.showRecipeSoftLimitAlert },
            set: { _ in }
        )) {
            Button("Cancel", role: .cancel) {
                dispatch(.cancelRecipeSoftLimit)
            }
            Button("Continue") {
                dispatch(.confirmRecipeSoftLimit)
            }
        } message: {
            Text("You selected \(state.selectedNotes.count) notes. This may take a while to process.")
        }
        .alert("Too Many Notes", isPresented: Binding(
            get: { state.showRecipeHardLimitAlert },
            set: { _ in }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Chill Recipes can process up to \(state.recipeHardLimit) notes at a time. Please reduce your selection.")
        }
        .sheet(isPresented: translateInputPresentedBinding) {
            TranslateSheetView(
                translateLanguages: state.translateLanguages,
                onSelect: { dispatch(.translateSelect($0)) },
                onCancel: { dispatch(.closeTranslate) }
            )
        }
        .alert("Delete Notes", isPresented: showDeleteConfirmationBinding) {
            Button("Cancel", role: .cancel) { }
            Button("Delete \(state.selectedNotes.count) Note\(state.selectedNotes.count == 1 ? "" : "s")", role: .destructive) {
                dispatch(.deleteSelectedNotes)
            }
        } message: {
            Text("Are you sure you want to delete \(state.selectedNotes.count) note\(state.selectedNotes.count == 1 ? "" : "s")? This action cannot be undone.")
        }
        .alert("Merge Successful", isPresented: showMergeSuccessAlertBinding) {
            Button("Keep Original Notes", role: .cancel) { }
            Button("Delete Originals", role: .destructive) {
                dispatch(.deleteNotesAfterMerge)
            }
        } message: {
            Text("The notes have been merged into a new note. Would you like to delete the original \(state.notesToDeleteAfterMerge.count) notes?")
        }
        .alert("Empty Recycle Bin", isPresented: showEmptyTrashConfirmationBinding) {
            Button("Cancel", role: .cancel) { }
            Button("Empty", role: .destructive) {
                dispatch(.emptyTrash)
            }
        } message: {
            Text("This will permanently delete all notes in the recycle bin.")
        }
        .sheet(isPresented: showBatchTagSheetBinding) {
            NavigationStack {
                List {
                    if state.availableTags.isEmpty {
                        Text("No tags available")
                            .foregroundColor(.textSub)
                    } else {
                        ForEach(state.availableTags) { tag in
                            Button {
                                dispatch(.applyTagToSelected(tag))
                                dispatch(.setShowBatchTagSheet(false))
                            } label: {
                                HStack {
                                    Image(systemName: "tag.fill")
                                        .foregroundColor(.accentPrimary)
                                    Text(tag.name)
                                        .font(.bodyMedium)
                                        .foregroundColor(.textMain)
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .navigationTitle("Add Tag")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dispatch(.setShowBatchTagSheet(false))
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HomeHeaderView(
                        isSelectionMode: state.isSelectionMode,
                        isTrashSelected: state.isTrashSelected,
                        isSearchVisible: state.isSearchVisible,
                        isRecording: state.speechRecognizer.isRecording,
                        headerTitle: state.headerTitle,
                        selectedNotesCount: state.selectedNotes.count,
                        visibleNotesCount: state.cachedVisibleNotes.count,
                        hasPendingRecordings: state.hasPendingRecordings,
                        onToggleSidebar: { dispatch(.toggleSidebar) },
                        onEnterSelectionMode: { dispatch(.enterSelectionMode) },
                        onToggleSearch: { dispatch(.toggleSearch) },
                        onExitSelectionMode: { dispatch(.exitSelectionMode) },
                        onSelectAll: { dispatch(.selectAll) },
                        onDeselectAll: { dispatch(.deselectAll) },
                        onShowBatchTagSheet: { dispatch(.setShowBatchTagSheet(true)) },
                        onShowDeleteConfirmation: { dispatch(.setShowDeleteConfirmation(true)) },
                        onShowEmptyTrashConfirmation: { dispatch(.setShowEmptyTrashConfirmation(true)) }
                    )

                    if !state.isSelectionMode && state.isSearchVisible {
                        searchBar
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                    }

                    HomeNotesListView(
                        cachedVisibleNotes: state.cachedVisibleNotes,
                        isTrashSelected: state.isTrashSelected,
                        isSelectionMode: state.isSelectionMode,
                        selectedNotes: state.selectedNotes,
                        onReachBottom: { dispatch(.loadMoreIfNeeded($0)) },
                        onToggleNoteSelection: { dispatch(.toggleNoteSelection($0)) },
                        onRestoreNote: { dispatch(.restoreNote($0)) },
                        onDeleteNotePermanently: { dispatch(.deleteNotePermanently($0)) },
                        onTogglePin: { dispatch(.togglePin($0)) },
                        onDeleteNote: { dispatch(.deleteNote($0)) }
                    )
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    dispatch(.hideKeyboard)
                }
            }
            .background(Color.bgPrimary)
            .scrollDismissesKeyboard(.interactively)
            .navigationDestination(for: Note.self) { note in
                NoteDetailView(note: note)
                    .environmentObject(state.speechRecognizer)
                    .onDisappear {
                        dispatch(.noteDetailDisappear(note))
                    }
            }
        }
    }

    private var floatingVoiceInput: some View {
        Group {
            if !state.isSelectionMode && !isSearchFocused && state.searchText.isEmpty && !state.isTrashSelected {
                ChatInputBar(
                    text: inputTextBinding,
                    isVoiceMode: voiceModeBinding,
                    speechRecognizer: state.speechRecognizer,
                    onSendText: {
                        dispatch(.submitText)
                    },
                    onCancelVoice: {
                        dispatch(.cancelVoice)
                    },
                    onConfirmVoice: {
                        dispatch(.confirmVoice)
                    },
                    onCreateBlankNote: {
                        dispatch(.createBlankNote)
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var selectionModeOverlay: some View {
        HomeSelectionOverlayView(
            isSelectionMode: state.isSelectionMode,
            isAgentMenuOpen: state.isAgentMenuOpen,
            recipeManager: state.recipeManager,
            onStartAIChat: { dispatch(.startAIChat) },
            onToggleAgentMenu: {
                dispatch(.setAgentMenuOpen(!state.isAgentMenuOpen))
            },
            onCloseMenu: {
                dispatch(.setAgentMenuOpen(false))
            },
            onOpenChillRecipes: { dispatch(.openChillRecipes) },
            onHandleAgentActionRequest: { dispatch(.handleAgentRecipeRequest($0)) }
        )
    }

    private var agentProgressOverlay: some View {
        Group {
            if state.isExecutingAction, let progress = state.actionProgress {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)

                        Text(progress)
                            .font(.bodyMedium)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(20)
                }
            }
        }
    }
}
