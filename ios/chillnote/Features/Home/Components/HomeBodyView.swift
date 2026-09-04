import SwiftUI
import SwiftData
import UIKit

struct HomeBodyView: View {
    let state: HomeScreenState
    let dispatch: (HomeScreenAction) -> Void
    @FocusState.Binding var isSearchFocused: Bool
    let searchBar: AnyView
    @ObservedObject var firstActionGuide: FirstActionGuideService

    @State private var sectionSlideDirection: Edge = .trailing

    private let sidebarOpenEdgeWidth: CGFloat = 110
    private let sidebarOpenMinTranslation: CGFloat = 36
    private let sidebarOpenHorizontalBias: CGFloat = 12

    private var oppositeSectionSlideDirection: Edge {
        sectionSlideDirection == .trailing ? .leading : .trailing
    }

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

    private var taggingNoteBinding: Binding<Note?> {
        Binding(
            get: { state.taggingNote },
            set: { dispatch(.setTaggingNote($0)) }
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

    private var selectedSectionBinding: Binding<NoteSection?> {
        Binding(
            get: { state.selectedSection },
            set: { dispatch(.setSelectedSection($0)) }
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

    private var firstActionSpotlight: FirstActionGuideSpotlightConfiguration? {
        guard firstActionGuide.stage == .openImportedNote,
              let noteID = firstActionGuide.targetNoteID else {
            return nil
        }

        return FirstActionGuideSpotlightConfiguration(
            target: .importedNote(noteID),
            message: L10n.text("onboarding.first_action.open_note"),
            step: 2
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
        .simultaneousGesture(sidebarOpenGesture)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary.ignoresSafeArea())
        .overlay {
            SidebarView(
                isPresented: sidebarPresentedBinding,
                selectedTag: selectedTagBinding,
                selectedSection: selectedSectionBinding,
                isTrashSelected: trashSelectedBinding,
                hasPendingRecordings: state.hasPendingRecordings,
                pendingRecordingsCount: state.pendingRecordingsCount,
                hasUnreadWeeklyTopicsReport: state.weeklyTopicsStore.hasUnreadReport,
                onSettingsTap: { dispatch(.showSettings) },
                onWeeklyTopicsTap: { dispatch(.openWeeklyTopics) },
                onPendingRecordingsTap: { dispatch(.setShowPendingRecordings(true)) }
            )
        }
        .navigationBarHidden(true)
        .firstActionGuideSpotlight(
            configuration: firstActionSpotlight,
            onSkip: { firstActionGuide.dismiss() }
        )
        .overlay(alignment: .bottom) {
            if firstActionGuide.stage == .sharePrompt {
                FirstActionSharePromptView(
                    onStart: { firstActionGuide.acknowledgeSharePrompt() },
                    onSkip: { firstActionGuide.dismiss() }
                )
                .padding(.horizontal, BrandTokens.Space.s3)
                .padding(.bottom, 104)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: firstActionGuide.stage)
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
        .sheet(item: taggingNoteBinding) { note in
            AddTagSheetView(
                initialColorHex: TagColorService.autoColorHex(
                    for: "",
                    existingTags: state.availableTags
                ),
                onAdd: { name, colorHex in
                    dispatch(.addTag(note, name, colorHex))
                }
            )
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

    private var showsSearchBar: Bool {
        !state.isSelectionMode && state.isSearchVisible
    }

    private var showsSectionPicker: Bool {
        !state.isSelectionMode && !state.isTrashSelected && state.selectedTag == nil
    }

    private var hasPinnedChrome: Bool {
        showsSearchBar || showsSectionPicker
    }

    private var scrollContentTopPadding: CGFloat {
        16
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
                onToggleSearch: { dispatch(.toggleSearch) },
                onExitSelectionMode: { dispatch(.exitSelectionMode) },
                onSelectAll: { dispatch(.selectAll) },
                onDeselectAll: { dispatch(.deselectAll) },
                onShowDeleteConfirmation: { dispatch(.setShowDeleteConfirmation(true)) },
                onShowEmptyTrashConfirmation: { dispatch(.setShowEmptyTrashConfirmation(true)) }
            )
            .background(Color.bgPrimary)
            .zIndex(2)

            pinnedChrome
                .background(Color.bgPrimary)
                .zIndex(1)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    HomeNotesListView(
                        cachedVisibleNotes: state.cachedVisibleNotes,
                        searchQuery: state.searchText,
                        isLoading: state.isLoadingNotes,
                        isInitialSyncing: state.isInitialNotesSync,
                        hasLoadedAtLeastOnce: state.hasLoadedNotesAtLeastOnce,
                        loadErrorMessage: state.notesLoadErrorMessage,
                        isTrashSelected: state.isTrashSelected,
                        selectedSection: state.selectedSection ?? .inbox,
                        isSelectionMode: state.isSelectionMode,
                        selectedNotes: state.selectedNotes,
                        showDefaultEmptyStateMessage: firstActionGuide.stage != .sharePrompt,
                        onReachBottom: { dispatch(.loadMoreIfNeeded($0)) },
                        onRetryLoad: { dispatch(.retryLoadNotes) },
                        onToggleNoteSelection: { dispatch(.toggleNoteSelection($0)) },
                        onEnterSelectionMode: { dispatch(.enterSelectionMode) },
                        onRestoreNote: { dispatch(.restoreNote($0)) },
                        onDeleteNotePermanently: { dispatch(.deleteNotePermanently($0)) },
                        onTogglePin: { dispatch(.togglePin($0)) },
                        onManageTags: { dispatch(.setTaggingNote($0)) },
                        onMoveNote: { dispatch(.moveNote($0, $1)) },
                        onDeleteNote: { dispatch(.deleteNote($0)) },
                        guideTargetNoteID: firstActionGuide.stage == .openImportedNote
                            ? firstActionGuide.targetNoteID
                            : nil,
                        onGuideTargetNoteOpened: { firstActionGuide.markImportedNoteOpened($0) }
                    )
                }
                .padding(.top, scrollContentTopPadding)
                .contentShape(Rectangle())
                .onTapGesture {
                    dispatch(.hideKeyboard)
                }
                .id(state.selectedSection ?? .inbox)
                .transition(.asymmetric(
                    insertion: .move(edge: sectionSlideDirection).combined(with: .opacity),
                    removal: .move(edge: oppositeSectionSlideDirection).combined(with: .opacity)
                ))
                .animation(
                    .spring(response: 0.42, dampingFraction: 0.86),
                    value: state.selectedSection
                )
            }
            .background(Color.bgPrimary)
            .clipped()
            .scrollDismissesKeyboard(.interactively)
            .navigationDestination(for: Note.self) { note in
                NoteDetailView(note: note)
                    .environmentObject(state.speechRecognizer)
                    .onDisappear {
                        dispatch(.noteDetailDisappear(note))
                    }
            }
            .navigationDestination(for: WeeklyTopicsRoute.self) { route in
                switch route {
                case .dashboard:
                    WeeklyTopicsView(
                        store: state.weeklyTopicsStore,
                        onOpenSource: { dispatch(.openWeeklyTopicSource($0)) }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var pinnedChrome: some View {
        VStack(spacing: 12) {
            if showsSearchBar {
                searchBar
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if showsSectionPicker {
                HomeSectionPicker(
                    selectedSection: state.selectedSection ?? .inbox,
                    onSelect: { newSection in
                        let current = state.selectedSection ?? .inbox
                        let oldIdx = NoteSection.allCases.firstIndex(of: current) ?? 0
                        let newIdx = NoteSection.allCases.firstIndex(of: newSection) ?? 0
                        sectionSlideDirection = newIdx >= oldIdx ? .trailing : .leading
                        dispatch(.selectSection(newSection))
                    }
                )
                .padding(.horizontal, 24)
                .transition(.opacity)
            }

        }
        .padding(.top, hasPinnedChrome ? 16 : 0)
        .padding(.bottom, hasPinnedChrome ? 4 : 0)
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
            selectedNotesCount: state.selectedNotes.count,
            onStartAIChat: { dispatch(.startAIChat) }
        )
    }

    private var agentProgressOverlay: some View {
        Group {
            if state.isExecutingAction, let progress = state.actionProgress {
                AgentProgressOverlayView(progress: progress)
            }
        }
    }
}

private struct AgentProgressOverlayView: View {
    let progress: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Color.accentPrimary.opacity(0.08)
                .ignoresSafeArea()

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Color.accentPrimary.opacity(0.12), lineWidth: 3)

                    Circle()
                        .trim(from: 0.08, to: 0.82)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color.accentPrimary.opacity(0.32),
                                    Color.accentPrimary,
                                    Color.accentPrimary
                                ],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .animation(
                            reduceMotion
                                ? nil
                                : .linear(duration: 0.9).repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                }
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

                Text(progress)
                    .font(.bodyMedium.weight(.semibold))
                    .foregroundColor(.textMain)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.accentPrimary.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: Color.shadowColor, radius: 16, y: 8)
            .padding(.horizontal, 28)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(progress)
        .onAppear {
            isAnimating = !reduceMotion
        }
        .onChange(of: reduceMotion) { _, shouldReduceMotion in
            isAnimating = !shouldReduceMotion
        }
    }
}
