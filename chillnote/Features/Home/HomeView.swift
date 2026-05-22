import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var syncManager: SyncManager
    @Environment(\.scenePhase) var scenePhase
    @StateObject var homeViewModel = HomeViewModel()

    var currentUserId: String? {
        authService.currentUserId
    }

    var availableTagsForCurrentUser: [Tag] {
        guard let userId = currentUserId else { return [] }
        return availableTags.filter { $0.userId == userId }
    }

    @StateObject var speechRecognizer = SpeechRecognizer()
    @State var navigationPath = NavigationPath()
    @State var showingSettings = false
    @State var isVoiceMode = true
    @State var pendingVoiceNoteByPath: [String: UUID] = [:]

    @State var isSelectionMode = false
    @State var selectedNotes: Set<UUID> = []
    @State var showAIChat = false
    @State var cachedContextNotes: [Note] = []
    @State var showDeleteConfirmation = false

    @State var isAgentMenuOpen = false
    @State var isExecutingAction = false
    @State var actionProgress: String?

    @State var showBatchTagSheet = false
    @Query(filter: #Predicate<Tag> { $0.deletedAt == nil }, sort: \Tag.name) var availableTags: [Tag]

    @State var pendingAgentAction: AgentRecipe?
    @State var isCustomActionInputPresented = false
    @State var customActionPrompt = ""
    @State var isTranslateInputPresented = false
    @State var translateTargetLanguage = ""
    @StateObject var recipeManager = RecipeManager.shared
    @State var showChillRecipes = false

    let askSoftLimit = 10
    let askHardLimit = 20
    let recipeSoftLimit = 5
    let recipeHardLimit = 8
    @State var showAskSoftLimitAlert = false
    @State var showAskHardLimitAlert = false
    @State var showRecipeSoftLimitAlert = false
    @State var showRecipeHardLimitAlert = false
    @State var pendingRecipeForConfirmation: AgentRecipe?

    @State var showSubscription = false

    let translateLanguages: [TranslateLanguage] = TranslateLanguage.defaultLanguages

    @State var isSidebarPresented = false
    @State var selectedTag: Tag? = nil
    @State var isTrashSelected = false
    @State var showEmptyTrashConfirmation = false

    @State var searchText = ""
    @State var isSearchVisible = false
    @FocusState var isSearchFocused: Bool

    @State var pendingRecordings: [PendingRecording] = []
    @State var showPendingRecordings = false
    @State var autoOpenPendingRecordings = false
    @State var latestTranscriptionFailureMessage = ""
    @State var showTranscriptionFailureAlert = false
    @State var showAppRatingPrompt = false

    @State var hasScheduledInitialMaintenance = false
    @State var lastMaintenanceAt: Date?
    let minimumMaintenanceInterval: TimeInterval = 30

    @ObservedObject var voiceService = VoiceProcessingService.shared

    @State var scheduledReloadTask: Task<Void, Never>?
    @State var bootstrappingUserId: String?
    @State var lastBootstrappedUserId: String?
    @State var shouldReloadAfterSync = false

    var headerTitle: String {
        if isTrashSelected {
            return L10n.text("sidebar.nav.recycle_bin")
        }
        return selectedTag?.name ?? "ChillNote"
    }

    var hasPendingRecordings: Bool {
        !pendingRecordings.isEmpty
    }

    var screenState: HomeScreenState {
        HomeScreenState(
            navigationPath: navigationPath,
            isSelectionMode: isSelectionMode,
            searchText: searchText,
            isSearchVisible: isSearchVisible,
            isTrashSelected: isTrashSelected,
            isAgentMenuOpen: isAgentMenuOpen,
            showChillRecipes: showChillRecipes,
            showingSettings: showingSettings,
            autoOpenPendingRecordings: autoOpenPendingRecordings,
            showAIChat: showAIChat,
            isCustomActionInputPresented: isCustomActionInputPresented,
            customActionPrompt: customActionPrompt,
            isTranslateInputPresented: isTranslateInputPresented,
            translateTargetLanguage: translateTargetLanguage,
            showDeleteConfirmation: showDeleteConfirmation,
            showEmptyTrashConfirmation: showEmptyTrashConfirmation,
            showBatchTagSheet: showBatchTagSheet,
            isSidebarPresented: isSidebarPresented,
            selectedTag: selectedTag,
            selectedNotes: selectedNotes,
            isVoiceMode: isVoiceMode,
            cachedVisibleNotes: homeViewModel.items,
            isLoadingNotes: homeViewModel.isLoading,
            isSyncingNotes: syncManager.isSyncing,
            hasLoadedNotesAtLeastOnce: homeViewModel.hasLoadedAtLeastOnce,
            availableTags: availableTagsForCurrentUser,
            translateLanguages: translateLanguages,
            recipeManager: recipeManager,
            speechRecognizer: speechRecognizer,
            syncManager: syncManager,
            headerTitle: headerTitle,
            actionProgress: actionProgress,
            isExecutingAction: isExecutingAction,
            cachedContextNotes: cachedContextNotes,
            showAskSoftLimitAlert: showAskSoftLimitAlert,
            showAskHardLimitAlert: showAskHardLimitAlert,
            showRecipeSoftLimitAlert: showRecipeSoftLimitAlert,
            showRecipeHardLimitAlert: showRecipeHardLimitAlert,
            askHardLimit: askHardLimit,
            recipeHardLimit: recipeHardLimit,
            hasPendingRecordings: hasPendingRecordings,
            pendingRecordingsCount: pendingRecordings.count,
            showPendingRecordings: showPendingRecordings
        )
    }

    var body: some View {
        homeViewWithModals
    }

    private var homeRootView: some View {
        HomeBodyView(
            state: screenState,
            dispatch: dispatch,
            isSearchFocused: $isSearchFocused,
            searchBar: AnyView(searchBar)
        )
    }

    private var homeViewLifecyclePhaseOne: AnyView {
        AnyView(
            homeRootView
        .onChange(of: speechRecognizer.recordingState) { _, newState in
            if case .error = newState, isVoiceMode {
                isVoiceMode = false
                speechRecognizer.dismissError()
            }

            if case .recording = newState {
                return
            }

            Task { @MainActor in
                await checkForPendingRecordingsAsync()
            }
        }
        .onChange(of: speechRecognizer.completedTranscriptions) { _, _ in
            handleCompletedTranscriptions()
        }
        .onReceive(NotificationCenter.default.publisher(for: .pendingRecordingsDidChange)) { _ in
            Task { @MainActor in
                await checkForPendingRecordingsAsync()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pendingRecordingNoteCreated)) { notification in
            // 1. Close the pending recordings sheet immediately
            showPendingRecordings = false

            // 2. Reload the home feed right away (keep existing items visible while loading)
            Task { @MainActor in
                await homeViewModel.reload(keepItemsWhileLoading: true)

                // 3. Navigate to the new note's detail page once the list has refreshed
                if let noteID = notification.userInfo?["noteID"] as? UUID,
                   let note = homeViewModel.note(with: noteID) {
                    // Small delay so the sheet dismiss animation completes first
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    navigationPath.append(note)
                }
            }
        }
        )
    }

    private var homeViewLifecyclePhaseTwo: AnyView {
        AnyView(
            homeViewLifecyclePhaseOne
        .onChange(of: authService.isSignedIn) { _, isSignedIn in
            guard !isSignedIn else { return }
            showingSettings = false
            isVoiceMode = false
            bootstrappingUserId = nil
            lastBootstrappedUserId = nil
        }
        .onChange(of: isTrashSelected) { _, newValue in
            if newValue {
                exitSelectionMode()
            }
            Task {
                await homeViewModel.switchMode(newValue ? .trash : .active)
                clampSelectionToCurrentFilter()
            }
        }
        .onChange(of: selectedTag) { _, _ in
            Task {
                await homeViewModel.switchTag(selectedTag?.id)
                clampSelectionToCurrentFilter()
            }
        }
        .onChange(of: searchText) { _, _ in
            homeViewModel.scheduleDebouncedSearchUpdate(searchText)
        }
        .onChange(of: authService.currentUserId) { _, newUserId in
            guard let userId = newUserId else { return }
            Task {
                await bootstrapHome(for: userId, source: .authChanged)
            }
        }
        )
    }

    private var homeViewWithLifecycleHandlers: AnyView {
        AnyView(
            homeViewLifecyclePhaseTwo
        .onChange(of: syncManager.isSyncing) { _, isSyncing in
            if isSyncing {
                shouldReloadAfterSync = true
                return
            }
            guard shouldReloadAfterSync else { return }
            shouldReloadAfterSync = false
            requestReload(delayNanoseconds: 60_000_000, keepItemsWhileLoading: true)
        }
        .onChange(of: showingSettings) { _, isPresented in
            guard !isPresented else { return }
            guard let userId = currentUserId else { return }
            Task {
                homeViewModel.configure(context: modelContext, userId: userId)
                await homeViewModel.reload()
                clampSelectionToCurrentFilter()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StartRecording"))) { _ in
            Task {
                let hasConsent = await AIConsentManager.shared.ensureConsentIfNeeded(for: .audio)
                guard hasConsent else { return }

                let authorized = await StoreService.shared.authorizeVoiceRecordingStart()
                guard authorized else {
                    await MainActor.run {
                        showSubscription = true
                    }
                    return
                }
                await MainActor.run {
                    isVoiceMode = true
                }
                speechRecognizer.startRecording(countsTowardQuota: false)
                let started = speechRecognizer.isRecording
                if !started {
                    await MainActor.run {
                        isVoiceMode = false
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sharedImportsRequested)) { _ in
            importPendingSharedNotes(navigateToLatest: true)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            importPendingSharedNotes(navigateToLatest: false)
            scheduleMaintenance(reason: .foreground)
        }
        .task {
            await checkForPendingRecordingsAsync()
            guard let userId = currentUserId else { return }
            await bootstrapHome(for: userId, source: .initialTask)
            importPendingSharedNotes(navigateToLatest: false)
            scheduleInitialMaintenance()
        }
        )
    }

    private var homeViewWithModals: some View {
        homeViewWithLifecycleHandlers
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
        .alert(VoiceErrorPresentation.transcriptionFailedTitle, isPresented: $showTranscriptionFailureAlert) {
            Button(L10n.text("sidebar.nav.pending_records")) {
                showPendingRecordings = true
            }
            Button(L10n.text("common.ok"), role: .cancel) { }
        } message: {
            Text(latestTranscriptionFailureMessage)
        }
        .alert(L10n.text("home.rating_prompt.title"), isPresented: $showAppRatingPrompt) {
            Button(L10n.text("home.rating_prompt.action.dislike")) {
                AppRatingService.shared.openFeedbackEmail()
            }
            Button(L10n.text("home.rating_prompt.action.like")) {
                AppRatingService.shared.requestInAppReview()
            }
        } message: {
            Text(L10n.text("home.rating_prompt.message"))
        }
    }

    func dispatch(_ action: HomeScreenAction) {
        switch action {
        case .setNavigationPath(let value):
            navigationPath = value
        case .setSearchText(let value):
            searchText = value
        case .setVoiceMode(let value):
            isVoiceMode = value
        case .setShowingSettings(let value):
            showingSettings = value
        case .setAutoOpenPendingRecordings(let value):
            autoOpenPendingRecordings = value
        case .setShowPendingRecordings(let value):
            showPendingRecordings = value
        case .setShowAIChat(let value):
            showAIChat = value
        case .setCustomActionInputPresented(let value):
            isCustomActionInputPresented = value
        case .setCustomActionPrompt(let value):
            customActionPrompt = value
        case .setTranslateInputPresented(let value):
            isTranslateInputPresented = value
        case .setShowDeleteConfirmation(let value):
            showDeleteConfirmation = value
        case .setShowEmptyTrashConfirmation(let value):
            showEmptyTrashConfirmation = value
        case .setShowBatchTagSheet(let value):
            showBatchTagSheet = value
        case .setSidebarPresented(let value):
            isSidebarPresented = value
        case .setAgentMenuOpen(let value):
            isAgentMenuOpen = value
        case .setShowChillRecipes(let value):
            showChillRecipes = value
        case .setSelectedTag(let value):
            selectedTag = value
        case .setTrashSelected(let value):
            isTrashSelected = value

        case .toggleSidebar:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isSidebarPresented.toggle()
            }
        case .openSidebar:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isSidebarPresented = true
            }
        case .enterSelectionMode:
            enterSelectionMode()
        case .toggleSearch:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isSearchVisible.toggle()
                if !isSearchVisible {
                    searchText = ""
                    hideKeyboard()
                } else {
                    isSearchFocused = true
                }
            }
        case .exitSelectionMode:
            exitSelectionMode()
        case .selectAll:
            selectAllNotes()
        case .deselectAll:
            selectedNotes.removeAll()

        case .restoreNote(let note):
            restoreNote(note)
        case .deleteNotePermanently(let note):
            deleteNotePermanently(note)
        case .togglePin(let note):
            togglePin(note)
        case .deleteNote(let note):
            deleteNote(note)
        case .loadMoreIfNeeded(let note):
            homeViewModel.loadMoreIfNeeded(currentItem: note)
        case .toggleNoteSelection(let note):
            toggleNoteSelection(note)

        case .handleAgentRecipeRequest(let recipe):
            handleAgentActionRequest(recipe)
        case .startAIChat:
            startAIChat()
        case .cancelVoice:
            speechRecognizer.stopRecording(reason: .cancelled)
        case .confirmVoice:
            handleVoiceConfirmation()
        case .pasteLink(let link):
            savePastedLink(link)
        case .importImageText(let text):
            saveImportedImageText(text)
        case .createBlankNote:
            createAndOpenBlankNote()

        case .deleteSelectedNotes:
            deleteSelectedNotes()
        case .emptyTrash:
            emptyTrash()
        case .applyTagToSelected(let tag):
            applyTagToSelected(tag)
        case .hideKeyboard:
            hideKeyboard()

        case .executePendingAgentAction(let instruction):
            if let recipe = pendingAgentAction {
                Task { await executeAgentAction(recipe, instruction: instruction) }
            }
            pendingAgentAction = nil
            isCustomActionInputPresented = false
        case .translateSelect(let language):
            translateTargetLanguage = language
            if let recipe = pendingAgentAction {
                Task { await executeAgentAction(recipe, instruction: language) }
            }
            translateTargetLanguage = ""
            pendingAgentAction = nil
            isTranslateInputPresented = false
        case .closeTranslate:
            translateTargetLanguage = ""
            pendingAgentAction = nil
            isTranslateInputPresented = false

        case .showSettings:
            showingSettings = true
        case .aiChatDisappear:
            exitSelectionMode()
        case .openChillRecipes:
            showChillRecipes = true
        case .closeChillRecipes:
            showChillRecipes = false

        case .confirmAskSoftLimit:
            cachedContextNotes = getSelectedNotes()
            showAIChat = true
            showAskSoftLimitAlert = false
        case .confirmRecipeSoftLimit:
            showRecipeSoftLimitAlert = false
            confirmPendingRecipeOverSoftLimit()
        case .cancelRecipeSoftLimit:
            pendingRecipeForConfirmation = nil
            showRecipeSoftLimitAlert = false
        case .noteDetailDisappear(let note):
            let isVisibleInCurrentMode = isTrashSelected ? (note.deletedAt != nil) : (note.deletedAt == nil)
            if !isVisibleInCurrentMode {
                homeViewModel.removeNoteLocally(id: note.id)
            }
            requestReload(keepItemsWhileLoading: true)
        }
    }

    var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.textSub)
                .font(.system(size: 16, weight: .semibold))

            TextField(L10n.text("home.search.placeholder"), text: Binding(
                get: { searchText },
                set: { dispatch(.setSearchText($0)) }
            ))
            .font(.bodyMedium)
            .foregroundColor(.textMain)
            .focused($isSearchFocused)
            .submitLabel(.search)

            if !searchText.isEmpty {
                Button(action: {
                    withAnimation {
                        dispatch(.setSearchText(""))
                        hideKeyboard()
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.textSub)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.03), lineWidth: 1)
        )
    }

    func requestReload(delayNanoseconds: UInt64 = 120_000_000, keepItemsWhileLoading: Bool = false) {
        scheduledReloadTask?.cancel()
        scheduledReloadTask = Task {
            if delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }
            guard !Task.isCancelled else { return }
            await homeViewModel.reload(keepItemsWhileLoading: keepItemsWhileLoading)
            clampSelectionToCurrentFilter()
        }
    }

    enum HomeBootstrapSource {
        case initialTask
        case authChanged
    }

    @MainActor
    func bootstrapHome(for userId: String, source: HomeBootstrapSource) async {
        if bootstrappingUserId == userId { return }
        if source == .initialTask, lastBootstrappedUserId == userId { return }

        bootstrappingUserId = userId
        defer {
            bootstrappingUserId = nil
            lastBootstrappedUserId = userId
        }

        homeViewModel.configure(context: modelContext, userId: userId)
        await homeViewModel.switchMode(isTrashSelected ? .trash : .active)
        await homeViewModel.switchTag(selectedTag?.id)
        await homeViewModel.updateSearchQuery(searchText)
        await homeViewModel.reload()
        clampSelectionToCurrentFilter()

        if source == .authChanged {
            scheduleMaintenance(reason: .userChanged)
        }

        Task(priority: .utility) {
            let delay: UInt64 = source == .initialTask ? 1_200_000_000 : 300_000_000
            try? await Task.sleep(nanoseconds: delay)
            await NotesSearchIndexer.shared.rebuildIfNeeded(context: modelContext, userId: userId)
        }
    }

}

#Preview {
    HomeView()
        .modelContainer(DataService.shared.container!)
        .environmentObject(AuthService.shared)
        .environmentObject(SyncManager())
}
