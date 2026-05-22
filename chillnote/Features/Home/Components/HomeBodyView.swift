import SwiftUI
import SwiftData
import UIKit

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
                onChillRecipesTap: { dispatch(.openChillRecipes) },
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
                            Button(L10n.text("common.close")) {
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
                            Button(L10n.text("common.close")) {
                                dispatch(.closeChillRecipes)
                            }
                        }
                    }
            }
        }
        .alert(L10n.text("home.ask_agent.title"), isPresented: customActionInputPresentedBinding) {
            TextField(L10n.text("home.ask_agent.prompt"), text: customActionPromptBinding)
            Button(L10n.text("common.cancel"), role: .cancel) {
                dispatch(.setCustomActionPrompt(""))
            }
            Button(L10n.text("home.ask_agent.confirm")) {
                dispatch(.executePendingAgentAction(state.customActionPrompt))
                dispatch(.setCustomActionPrompt(""))
            }
        } message: {
            Text(L10n.text("home.ask_agent.message"))
        }
        .alert(L10n.text("home.alert.large_selection.title"), isPresented: Binding(
            get: { state.showAskSoftLimitAlert },
            set: { _ in }
        )) {
            Button(L10n.text("common.cancel"), role: .cancel) { }
            Button(L10n.text("common.continue")) {
                dispatch(.confirmAskSoftLimit)
            }
        } message: {
            Text(L10n.text("home.alert.ask_soft_limit.message", state.selectedNotes.count))
        }
        .alert(L10n.text("home.alert.too_many_notes.title"), isPresented: Binding(
            get: { state.showAskHardLimitAlert },
            set: { _ in }
        )) {
            Button(L10n.text("common.ok"), role: .cancel) { }
        } message: {
            Text(L10n.text("home.alert.ask_hard_limit.message", state.askHardLimit))
        }
        .alert(L10n.text("home.alert.large_selection.title"), isPresented: Binding(
            get: { state.showRecipeSoftLimitAlert },
            set: { _ in }
        )) {
            Button(L10n.text("common.cancel"), role: .cancel) {
                dispatch(.cancelRecipeSoftLimit)
            }
            Button(L10n.text("common.continue")) {
                dispatch(.confirmRecipeSoftLimit)
            }
        } message: {
            Text(L10n.text("home.alert.recipe_soft_limit.message", state.selectedNotes.count))
        }
        .alert(L10n.text("home.alert.too_many_notes.title"), isPresented: Binding(
            get: { state.showRecipeHardLimitAlert },
            set: { _ in }
        )) {
            Button(L10n.text("common.ok"), role: .cancel) { }
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
        .alert(L10n.text("home.alert.delete_notes.title"), isPresented: showDeleteConfirmationBinding) {
            Button(L10n.text("common.cancel"), role: .cancel) { }
            Button(deleteNotesButtonTitle, role: .destructive) {
                dispatch(.deleteSelectedNotes)
            }
        } message: {
            Text(deleteNotesMessage)
        }
        .alert(L10n.text("home.alert.empty_recycle_bin.title"), isPresented: showEmptyTrashConfirmationBinding) {
            Button(L10n.text("common.cancel"), role: .cancel) { }
            Button(L10n.text("home.alert.empty_recycle_bin.confirm"), role: .destructive) {
                dispatch(.emptyTrash)
            }
        } message: {
            Text(L10n.text("home.alert.empty_recycle_bin.message"))
        }
        .sheet(isPresented: showBatchTagSheetBinding) {
            NavigationStack {
                List {
                    if state.availableTags.isEmpty {
                        Text(L10n.text("home.batch_tag.empty"))
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
                                        Text(L10n.text("home.batch_tag.added"))
                                            .font(.caption)
                                            .foregroundColor(.textSub)
                                    } else if tagApplyState == .partial {
                                        Text(L10n.text("home.batch_tag.partial"))
                                            .font(.caption)
                                            .foregroundColor(.textSub)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .navigationTitle(L10n.text("home.batch_tag.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.text("common.cancel")) {
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
                triggerSidebarHaptic()
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

    private func triggerSidebarHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
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
                highlightSelectionEntry: false,
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
                    }

                    HomeNotesListView(
                        cachedVisibleNotes: state.cachedVisibleNotes,
                        searchQuery: state.searchText,
                        isLoading: state.isLoadingNotes,
                        isSyncing: state.isSyncingNotes,
                        hasLoadedAtLeastOnce: state.hasLoadedNotesAtLeastOnce,
                        isTrashSelected: state.isTrashSelected,
                        isSelectionMode: state.isSelectionMode,
                        selectedNotes: state.selectedNotes,
                        showDefaultEmptyStateMessage: true,
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
                    isVoiceMode: voiceModeBinding,
                    speechRecognizer: state.speechRecognizer,
                    onCancelVoice: {
                        dispatch(.cancelVoice)
                    },
                    onConfirmVoice: {
                        dispatch(.confirmVoice)
                    },
                    onPasteLink: {
                        dispatch(.pasteLink($0))
                    },
                    onImportImageText: {
                        dispatch(.importImageText($0))
                    },
                    onCreateBlankNote: {
                        dispatch(.createBlankNote)
                    },
                    recordTriggerMode: .tapToRecord,
                    highlightIdleMic: false
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
            selectedNotesCount: state.selectedNotes.count,
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
