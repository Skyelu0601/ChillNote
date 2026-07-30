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
                selectedSection: selectedSectionBinding,
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

    private var showsSearchBar: Bool {
        !state.isSelectionMode && state.isSearchVisible
    }

    private var showsSectionPicker: Bool {
        !state.isSelectionMode && !state.isTrashSelected && state.selectedTag == nil
    }

    private var hasPinnedChrome: Bool {
        showsSearchBar || showsSectionPicker
    }

    private var showsCreatorSkillsRail: Bool {
        !state.isSelectionMode
            && !state.isTrashSelected
            && state.selectedTag == nil
            && !state.recipeManager.savedRecipes.isEmpty
    }

    private var scrollContentTopPadding: CGFloat {
        showsCreatorSkillsRail ? 8 : 16
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
            .zIndex(2)

            pinnedChrome
                .background(Color.bgPrimary)
                .zIndex(1)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if showsCreatorSkillsRail {
                        HomeCreatorSkillsRailView(
                            recipes: state.recipeManager.savedRecipes,
                            onRecipeTap: { dispatch(.prepareHomeRecipe($0)) },
                            onAddMoreTap: { dispatch(.openChillRecipes) }
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 2)
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
                        onMoveNote: { dispatch(.moveNote($0, $1)) },
                        onDeleteNote: { dispatch(.deleteNote($0)) }
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
