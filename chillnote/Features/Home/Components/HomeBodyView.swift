import SwiftUI
import SwiftData

struct HomeBodyView: View {
    private enum TagApplyState {
        case none
        case partial
        case all
    }

    let state: HomeScreenState
    let dispatch: (HomeScreenAction) -> Void
    @FocusState.Binding var isSearchFocused: Bool
    let searchBar: AnyView
    
    private let sidebarOpenEdgeWidth: CGFloat = 110
    private let sidebarOpenMinTranslation: CGFloat = 36
    private let sidebarOpenHorizontalBias: CGFloat = 12

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

    private var selectedVisibleNotes: [Note] {
        state.cachedVisibleNotes.filter { state.selectedNotes.contains($0.id) }
    }

    private func applyState(for tag: Tag) -> TagApplyState {
        guard !selectedVisibleNotes.isEmpty else { return .none }
        let matchedCount = selectedVisibleNotes.filter { note in
            note.tags.contains(where: { $0.id == tag.id })
        }.count

        if matchedCount == 0 {
            return .none
        }
        if matchedCount == selectedVisibleNotes.count {
            return .all
        }
        return .partial
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
        .simultaneousGesture(sidebarOpenGesture)
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
            Text(L10n.text("home.alert.ask_soft_limit.message", state.selectedNotes.count))
        }
        .alert("Too Many Notes", isPresented: Binding(
            get: { state.showAskHardLimitAlert },
            set: { _ in }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(L10n.text("home.alert.ask_hard_limit.message", state.askHardLimit))
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
            Text(L10n.text("home.alert.recipe_soft_limit.message", state.selectedNotes.count))
        }
        .alert("Too Many Notes", isPresented: Binding(
            get: { state.showRecipeHardLimitAlert },
            set: { _ in }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(L10n.text("home.alert.recipe_hard_limit.message", state.recipeHardLimit))
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
            Button(deleteNotesButtonTitle, role: .destructive) {
                dispatch(.deleteSelectedNotes)
            }
        } message: {
            Text(deleteNotesMessage)
        }
        .alert("Merge Successful", isPresented: showMergeSuccessAlertBinding) {
            Button("Keep Original Notes", role: .cancel) { }
            Button("Delete Originals", role: .destructive) {
                dispatch(.deleteNotesAfterMerge)
            }
        } message: {
            Text(L10n.text("home.alert.merge_success.message", state.notesToDeleteAfterMerge.count))
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
                            let tagApplyState = applyState(for: tag)
                            Button {
                                if tagApplyState != .all {
                                    dispatch(.applyTagToSelected(tag))
                                }
                                dispatch(.setShowBatchTagSheet(false))
                            } label: {
                                HStack {
                                    Image(systemName: tagApplyState == .all ? "checkmark.circle.fill" : (tagApplyState == .partial ? "minus.circle.fill" : "tag.fill"))
                                        .foregroundColor(tagApplyState == .all ? .green : .accentPrimary)
                                    Text(tag.name)
                                        .font(.bodyMedium)
                                        .foregroundColor(.textMain)
                                    Spacer()
                                    if tagApplyState == .all {
                                        Text("Added")
                                            .font(.caption)
                                            .foregroundColor(.textSub)
                                    } else if tagApplyState == .partial {
                                        Text("Partial")
                                            .font(.caption)
                                            .foregroundColor(.textSub)
                                    }
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

    private var sidebarOpenGesture: some Gesture {
        DragGesture(minimumDistance: 16)
            .onEnded { value in
                guard shouldOpenSidebar(from: value) else { return }
                dispatch(.openSidebar)
            }
    }

    private func shouldOpenSidebar(from value: DragGesture.Value) -> Bool {
        guard !state.isSidebarPresented else { return false }
        guard value.startLocation.x <= sidebarOpenEdgeWidth else { return false }

        let horizontal = value.translation.width
        let vertical = abs(value.translation.height)
        let predictedHorizontal = value.predictedEndTranslation.width

        let hasEnoughHorizontalDistance =
            horizontal >= sidebarOpenMinTranslation ||
            predictedHorizontal >= sidebarOpenMinTranslation * 1.3
        let isMostlyHorizontal = horizontal > vertical + sidebarOpenHorizontalBias

        return hasEnoughHorizontalDistance && isMostlyHorizontal
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
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
                onCreateBlankNote: { dispatch(.createBlankNote) },
                onEnterSelectionMode: { dispatch(.enterSelectionMode) },
                onToggleSearch: { dispatch(.toggleSearch) },
                onExitSelectionMode: { dispatch(.exitSelectionMode) },
                onSelectAll: { dispatch(.selectAll) },
                onDeselectAll: { dispatch(.deselectAll) },
                onShowBatchTagSheet: { dispatch(.setShowBatchTagSheet(true)) },
                onShowDeleteConfirmation: { dispatch(.setShowDeleteConfirmation(true)) },
                onShowEmptyTrashConfirmation: { dispatch(.setShowEmptyTrashConfirmation(true)) }
            )
            .background(Color.bgPrimary)
            .zIndex(1)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !state.isSelectionMode && state.isSearchVisible {
                        searchBar
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                    }

                    HomeNotesListView(
                        cachedVisibleNotes: state.cachedVisibleNotes,
                        isLoading: state.isLoadingNotes,
                        isSyncing: state.isSyncingNotes,
                        hasLoadedAtLeastOnce: state.hasLoadedNotesAtLeastOnce,
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
                .padding(.top, 16)
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

    private var deleteNotesButtonTitle: String {
        if state.selectedNotes.count == 1 {
            return L10n.text("home.alert.delete_notes.button.one")
        }
        return L10n.text("home.alert.delete_notes.button.other", state.selectedNotes.count)
    }

    private var deleteNotesMessage: String {
        if state.selectedNotes.count == 1 {
            return L10n.text("home.alert.delete_notes.message.one")
        }
        return L10n.text("home.alert.delete_notes.message.other", state.selectedNotes.count)
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
                    recordTriggerMode: .tapToRecord
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
