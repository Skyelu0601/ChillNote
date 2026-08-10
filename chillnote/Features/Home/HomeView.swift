import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var syncManager: SyncManager
    @Environment(\.scenePhase) var scenePhase
    @StateObject var homeViewModel = HomeViewModel()
    @StateObject private var storeService = StoreService.shared
    @StateObject var weeklyTopicsStore = WeeklyTopicsStore()
    @StateObject var firstActionGuide = FirstActionGuideService.shared

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

    @State var taggingNote: Note?
    @Query(filter: #Predicate<Tag> { $0.deletedAt == nil }, sort: \Tag.name) var availableTags: [Tag]

    @State var pendingAgentAction: AgentRecipe?
    @State var pendingHomeRecipe: AgentRecipe?
    @State var homeAISkillPreview: HomeAISkillPreview?
    @State var homeRecipeSelectedNoteIDs: Set<UUID> = []
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
    @State private var showWeeklyTopicsPreview = false
    @State private var showCreditGiftPrompt = false

    private let initialFreeCreditGiftAmount = 50
    private let creditGiftPromptSeenKeyPrefix = "home_credit_gift_prompt_seen."

    let translateLanguages: [TranslateLanguage] = TranslateLanguage.defaultLanguages

    @State var isSidebarPresented = false
    @State var selectedTag: Tag? = nil
    @State var selectedSection: NoteSection? = .inbox
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
    @State var lastClipboardLinkPasteboardChangeCount: Int?
    @State var isImportingClipboardLink = false
    @State var recentLinkImportURLs: [String: Date] = [:]
    @State var clipboardLinkImportErrorMessage = ""
    @State var showClipboardLinkImportErrorAlert = false
    @State var showImportNotificationPermissionPrompt = false

    @State var lastMaintenanceAt: Date?
    let minimumMaintenanceInterval: TimeInterval = 30

    @ObservedObject var voiceService = VoiceProcessingService.shared

    @State var scheduledReloadTask: Task<Void, Never>?
    @State var bootstrappingUserId: String?
    @State var lastBootstrappedUserId: String?
    @State var shouldReloadAfterSync = false
    @State var isBootstrappingNotesSync = false

    var pendingLinkImportIDs: [UUID] {
        homeViewModel.items
            .filter(\.isLinkImportInProgress)
            .map(\.id)
            .sorted { $0.uuidString < $1.uuidString }
    }

    var headerTitle: String {
        if isTrashSelected {
            return L10n.text("sidebar.nav.recycle_bin")
        }
        return selectedTag?.name ?? "ChillScript"
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
            taggingNote: taggingNote,
            isSidebarPresented: isSidebarPresented,
            selectedTag: selectedTag,
            selectedSection: selectedSection,
            selectedNotes: selectedNotes,
            isVoiceMode: isVoiceMode,
            cachedVisibleNotes: homeViewModel.items,
            sectionCounts: homeViewModel.sectionCounts,
            isLoadingNotes: homeViewModel.isLoading,
            isInitialNotesSync: isBootstrappingNotesSync
                && currentUserId.map { !syncManager.hasCompletedSync(for: $0) } == true
                && !homeViewModel.sectionCounts.values.contains(where: { $0 > 0 }),
            hasLoadedNotesAtLeastOnce: homeViewModel.hasLoadedAtLeastOnce,
            availableTags: availableTagsForCurrentUser,
            translateLanguages: translateLanguages,
            recipeManager: recipeManager,
            weeklyTopicsStore: weeklyTopicsStore,
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
            searchBar: AnyView(searchBar),
            firstActionGuide: firstActionGuide
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
            firstActionGuide.resetForSignedOutUser()
        }
        .onChange(of: isTrashSelected) { _, newValue in
            if newValue {
                exitSelectionMode()
            }
            Task {
                await homeViewModel.switchMode(newValue ? .trash : .active(section: selectedSection))
                clampSelectionToCurrentFilter()
            }
        }
        .onChange(of: selectedTag) { _, _ in
            Task {
                await homeViewModel.switchTag(selectedTag?.id)
                clampSelectionToCurrentFilter()
            }
        }
        .onChange(of: selectedSection) { _, newValue in
            exitSelectionMode()
            Task {
                await homeViewModel.switchMode(
                    isTrashSelected ? .trash : .active(section: newValue),
                    keepItemsWhileLoading: true
                )
                clampSelectionToCurrentFilter()
            }
        }
        .onChange(of: searchText) { _, _ in
            homeViewModel.scheduleDebouncedSearchUpdate(searchText)
        }
        .onChange(of: authService.currentUserId) { _, newUserId in
            guard let userId = newUserId else { return }
            Task {
                await PushNotificationManager.shared.refreshRegistration()
                await bootstrapHome(for: userId, source: .authChanged)
                configureFirstActionGuide()
                await weeklyTopicsStore.reload()
                await checkForClipboardLinkImport()
                await evaluateImportNotificationPermissionPrompt()
            }
        }
        .onChange(of: authService.currentUser?.createdAt) { _, _ in
            configureFirstActionGuide()
        }
        )
    }

    private var homeViewWithLifecycleHandlers: AnyView {
        AnyView(
            homeViewLifecyclePhaseTwo
        .onChange(of: syncManager.isSyncing) { _, isSyncing in
            guard !isBootstrappingNotesSync else { return }
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
            configureFirstActionGuide()
            importPendingSharedNotes(navigateToLatest: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .pushNotificationDestinationRequested)) { _ in
            handlePendingPushNotificationDestination()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            importPendingSharedNotes(navigateToLatest: false)
            scheduleMaintenance(reason: .foreground)
            Task {
                await PushNotificationManager.shared.refreshRegistration()
                await weeklyTopicsStore.reload()
                await checkForClipboardLinkImport()
            }
        }
        .task {
            await checkForPendingRecordingsAsync()
            guard let userId = currentUserId else { return }
            await PushNotificationManager.shared.refreshRegistration()
            await bootstrapHome(for: userId, source: .initialTask)
            configureFirstActionGuide()
            await weeklyTopicsStore.reload()
            importPendingSharedNotes(navigateToLatest: false)
            await checkForClipboardLinkImport()
            await evaluateImportNotificationPermissionPrompt()
            handlePendingPushNotificationDestination()
        }
        .task(id: pendingLinkImportIDs) {
            reconcileFirstActionGuideImport()
            guard !pendingLinkImportIDs.isEmpty else { return }
            await monitorLinkImportProgress()
        }
        )
    }

    private var homeViewWithModals: some View {
        homeViewWithLifecycleHandlers
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
        .fullScreenCover(isPresented: $showWeeklyTopicsPreview) {
            WeeklyTopicsPreviewView {
                showWeeklyTopicsPreview = false
                DispatchQueue.main.async {
                    showSubscription = true
                }
            }
        }
        .alert(VoiceErrorPresentation.transcriptionFailedTitle, isPresented: $showTranscriptionFailureAlert) {
            Button(L10n.text("sidebar.nav.pending_records")) {
                showPendingRecordings = true
            }
            Button(L10n.text("common.ok"), role: .cancel) { }
        } message: {
            Text(latestTranscriptionFailureMessage)
        }
        .alert(L10n.text("quick_capture.error.title"), isPresented: $showClipboardLinkImportErrorAlert) {
            Button(L10n.text("common.ok"), role: .cancel) { }
        } message: {
            Text(clipboardLinkImportErrorMessage)
        }
        .alert(
            L10n.text("notification.permission.import.title"),
            isPresented: $showImportNotificationPermissionPrompt
        ) {
            Button(L10n.text("notification.permission.import.enable")) {
                markImportNotificationPermissionPromptSeen()
                Task {
                    await PushNotificationManager.shared.requestImportCompletionAlerts()
                }
            }
            Button(L10n.text("notification.permission.import.not_now"), role: .cancel) {
                markImportNotificationPermissionPromptSeen()
            }
        } message: {
            Text(L10n.text("notification.permission.import.message"))
        }
        .sheet(item: $pendingHomeRecipe) { recipe in
            HomeRecipeNotePickerSheet(
                recipe: recipe,
                notes: homeViewModel.items,
                selectedNoteIDs: $homeRecipeSelectedNoteIDs,
                onRun: {
                    runHomeRecipe(recipe)
                },
                onCancel: {
                    pendingHomeRecipe = nil
                    homeRecipeSelectedNoteIDs.removeAll()
                }
            )
        }
        .sheet(item: $homeAISkillPreview) { preview in
            HomeAISkillPreviewSheet(
                preview: preview,
                onApply: { applyHomeAISkillPreview(preview, mode: $0) }
            )
        }
        .overlay {
            if showCreditGiftPrompt {
                HomeCreditGiftPromptOverlay {
                    dismissCreditGiftPrompt()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(20)
            }
        }
        .onChange(of: storeService.hasFetchedCreditBalanceFromBackend) { _, _ in
            evaluateCreditGiftPrompt()
        }
        .onChange(of: storeService.creditBalance) { _, _ in
            evaluateCreditGiftPrompt()
        }
        .onChange(of: storeService.currentTier) { _, _ in
            evaluateCreditGiftPrompt()
        }
        .onChange(of: authService.currentUserId) { _, _ in
            evaluateCreditGiftPrompt()
        }
        .onAppear {
            evaluateCreditGiftPrompt()
        }
    }

    private func evaluateCreditGiftPrompt() {
        guard let userId = currentUserId else { return }
        guard storeService.currentTier == .free else {
            showCreditGiftPrompt = false
            return
        }
        guard storeService.hasFetchedCreditBalanceFromBackend else { return }
        guard storeService.creditBalance == initialFreeCreditGiftAmount else { return }
        guard !UserDefaults.standard.bool(forKey: creditGiftPromptSeenKey(for: userId)) else { return }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            showCreditGiftPrompt = true
        }
    }

    private func dismissCreditGiftPrompt() {
        if let userId = currentUserId {
            UserDefaults.standard.set(true, forKey: creditGiftPromptSeenKey(for: userId))
        }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            showCreditGiftPrompt = false
        }
    }

    private func creditGiftPromptSeenKey(for userId: String) -> String {
        "\(creditGiftPromptSeenKeyPrefix)\(userId)"
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
        case .setTaggingNote(let note):
            taggingNote = note
        case .setSidebarPresented(let value):
            isSidebarPresented = value
        case .setAgentMenuOpen(let value):
            isAgentMenuOpen = value
        case .setShowChillRecipes(let value):
            showChillRecipes = value
        case .setSelectedTag(let value):
            selectedTag = value
        case .setSelectedSection(let value):
            selectedSection = value
        case .setTrashSelected(let value):
            isTrashSelected = value
        case .selectSection(let section):
            selectedTag = nil
            selectedSection = section
            isTrashSelected = false

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
        case .moveNote(let note, let section):
            moveNote(note, to: section)
        case .deleteNote(let note):
            deleteNote(note)
        case .loadMoreIfNeeded(let note):
            homeViewModel.loadMoreIfNeeded(currentItem: note)
        case .toggleNoteSelection(let note):
            toggleNoteSelection(note)

        case .handleAgentRecipeRequest(let recipe):
            handleAgentActionRequest(recipe)
        case .prepareHomeRecipe(let recipe):
            prepareHomeRecipe(recipe)
        case .startAIChat:
            startAIChat()
        case .cancelVoice:
            speechRecognizer.stopRecording(reason: .cancelled)
        case .confirmVoice:
            handleVoiceConfirmation()
        case .pasteLink(let url):
            createLinkImportNote(url)
        case .createBlankNote:
            createAndOpenBlankNote()

        case .deleteSelectedNotes:
            deleteSelectedNotes()
        case .emptyTrash:
            emptyTrash()
        case .toggleTag(let note, let tag):
            toggleTag(tag, for: note)
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
        case .openWeeklyTopics:
            Task { @MainActor in
                await storeService.ensureSubscriptionStatusReadyForFeatureGate()
                if storeService.currentTier == .pro {
                    navigationPath.append(WeeklyTopicsRoute.dashboard)
                } else {
                    showWeeklyTopicsPreview = true
                }
            }
        case .openWeeklyTopicSource(let noteID):
            Task { @MainActor in
                if let note = resolveNote(noteID) {
                    navigationPath.append(note)
                    return
                }
                _ = await syncManager.syncNow(context: modelContext)
                await homeViewModel.reload(keepItemsWhileLoading: true)
                if let note = resolveNote(noteID) {
                    navigationPath.append(note)
                }
            }

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
            let isVisibleInCurrentMode = isNoteVisibleInCurrentMode(note)
            if !isVisibleInCurrentMode {
                homeViewModel.removeNoteLocally(id: note.id)
            }
            requestReload(keepItemsWhileLoading: true)
        }
    }

    func prepareHomeRecipe(_ recipe: AgentRecipe) {
        pendingHomeRecipe = recipe
        if let firstNote = homeViewModel.items.first {
            homeRecipeSelectedNoteIDs = [firstNote.id]
        } else {
            homeRecipeSelectedNoteIDs.removeAll()
        }
    }

    func runHomeRecipe(_ recipe: AgentRecipe) {
        selectedNotes = homeRecipeSelectedNoteIDs
        pendingHomeRecipe = nil
        homeRecipeSelectedNoteIDs.removeAll()
        handleAgentActionRequest(recipe)
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
        await homeViewModel.switchMode(isTrashSelected ? .trash : .active(section: selectedSection))
        await homeViewModel.switchTag(selectedTag?.id)
        await homeViewModel.updateSearchQuery(searchText)
        await homeViewModel.reload()
        clampSelectionToCurrentFilter()

        isBootstrappingNotesSync = true
        await runMaintenance(
            reason: source == .authChanged ? .userChanged : .initial
        )
        await homeViewModel.reload(keepItemsWhileLoading: true)
        clampSelectionToCurrentFilter()
        isBootstrappingNotesSync = false

        await storeService.fetchCreditBalance()
        evaluateCreditGiftPrompt()

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
