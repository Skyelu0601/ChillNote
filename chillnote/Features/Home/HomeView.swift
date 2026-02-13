import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var syncManager: SyncManager
    @Environment(\.scenePhase) var scenePhase
    @StateObject var homeViewModel = HomeViewModel()

    var currentUserId: String {
        authService.currentUserId ?? "unknown"
    }

    @StateObject var speechRecognizer = SpeechRecognizer()
    @State var navigationPath = NavigationPath()
    @State var showingSettings = false
    @State var inputText = ""
    @State var isVoiceMode = true
    @State var pendingVoiceNoteByPath: [String: UUID] = [:]

    @State var isSelectionMode = false
    @State var selectedNotes: Set<UUID> = []
    @State var showAIChat = false
    @State var cachedContextNotes: [Note] = []
    @State var showDeleteConfirmation = false

    @State var showAgentActionsSheet = false
    @State var isAgentMenuOpen = false
    @State var isExecutingAction = false
    @State var actionProgress: String?

    @State var showMergeSuccessAlert = false
    @State var notesToDeleteAfterMerge: [Note] = []

    @State var showBatchTagSheet = false
    @Query(sort: \Tag.name) var availableTags: [Tag]

    @State var pendingAgentAction: AIAgentAction?
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

    @State var showUpgradeSheet = false
    @State var showSubscription = false
    @State var upgradeTitle = ""

    let translateLanguages: [TranslateLanguage] = [
        TranslateLanguage(id: "zh-Hans", name: "Simplified Chinese", displayName: "简体中文", flag: "🇨🇳"),
        TranslateLanguage(id: "zh-Hant", name: "Traditional Chinese", displayName: "繁體中文", flag: "🇭🇰"),
        TranslateLanguage(id: "fr", name: "French", displayName: "Français", flag: "🇫🇷"),
        TranslateLanguage(id: "en", name: "English", displayName: "English", flag: "🇺🇸"),
        TranslateLanguage(id: "de", name: "German", displayName: "Deutsch", flag: "🇩🇪"),
        TranslateLanguage(id: "ja", name: "Japanese", displayName: "日本語", flag: "🇯🇵"),
        TranslateLanguage(id: "es", name: "Spanish", displayName: "Español", flag: "🇪🇸"),
        TranslateLanguage(id: "ko", name: "Korean", displayName: "한국어", flag: "🇰🇷")
    ]

    @State var isSidebarPresented = false
    @State var selectedTag: Tag? = nil
    @State var isTrashSelected = false
    @State var showEmptyTrashConfirmation = false

    @State var searchText = ""
    @State var isSearchVisible = false
    @FocusState var isSearchFocused: Bool

    @State var pendingRecordings: [PendingRecording] = []
    @State var showRecoveryAlert = false
    @State var autoOpenPendingRecordings = false

    @State var hasScheduledInitialMaintenance = false
    @State var lastMaintenanceAt: Date?
    let minimumMaintenanceInterval: TimeInterval = 30

    @ObservedObject var voiceService = VoiceProcessingService.shared

    @AppStorage("lastDismissedRecordingDate") var lastDismissedRecordingDate: Double = 0

    @State var scheduledReloadTask: Task<Void, Never>?

    var headerTitle: String {
        if isTrashSelected {
            return "Recycle Bin"
        }
        return selectedTag?.name ?? "ChillNote"
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
            showAgentActionsSheet: showAgentActionsSheet,
            isCustomActionInputPresented: isCustomActionInputPresented,
            customActionPrompt: customActionPrompt,
            isTranslateInputPresented: isTranslateInputPresented,
            translateTargetLanguage: translateTargetLanguage,
            showDeleteConfirmation: showDeleteConfirmation,
            showMergeSuccessAlert: showMergeSuccessAlert,
            showEmptyTrashConfirmation: showEmptyTrashConfirmation,
            showBatchTagSheet: showBatchTagSheet,
            isSidebarPresented: isSidebarPresented,
            selectedTag: selectedTag,
            selectedNotes: selectedNotes,
            notesToDeleteAfterMerge: notesToDeleteAfterMerge,
            inputText: inputText,
            isVoiceMode: isVoiceMode,
            cachedVisibleNotes: homeViewModel.items,
            availableTags: availableTags,
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
            hasPendingRecordings: !pendingRecordings.isEmpty
        )
    }

    var body: some View {
        HomeBodyView(
            state: screenState,
            dispatch: dispatch,
            isSearchFocused: $isSearchFocused,
            searchBar: AnyView(searchBar)
        )
        .onChange(of: speechRecognizer.recordingState) { _, newState in
            if case .error = newState, isVoiceMode {
                isVoiceMode = false
                speechRecognizer.dismissError()
            }
        }
        .onChange(of: speechRecognizer.completedTranscriptions) { _, _ in
            handleCompletedTranscriptions()
        }
        .onChange(of: authService.isSignedIn) { _, isSignedIn in
            guard !isSignedIn else { return }
            showingSettings = false
            isVoiceMode = false
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
                homeViewModel.configure(context: modelContext, userId: userId)
                await homeViewModel.reload()
                await NotesSearchIndexer.shared.rebuildIfNeeded(context: modelContext, userId: userId)
            }
        }
        .onChange(of: showingSettings) { _, isPresented in
            guard !isPresented else { return }
            Task {
                homeViewModel.configure(context: modelContext, userId: currentUserId)
                await homeViewModel.reload()
                clampSelectionToCurrentFilter()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StartRecording"))) { _ in
            Task {
                let canRecord = await StoreService.shared.checkDailyQuotaOnServer(feature: .voice)
                await MainActor.run {
                    guard canRecord else {
                        upgradeTitle = "Daily voice limit reached"
                        showUpgradeSheet = true
                        return
                    }
                    isVoiceMode = true
                    speechRecognizer.startRecording(countsTowardQuota: true)
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            scheduleMaintenance(reason: .foreground)
        }
        .task {
            scheduleInitialMaintenance()
            homeViewModel.configure(context: modelContext, userId: currentUserId)
            await homeViewModel.switchMode(isTrashSelected ? .trash : .active)
            await homeViewModel.switchTag(selectedTag?.id)
            await homeViewModel.updateSearchQuery(searchText)
            await homeViewModel.reload()
            Task(priority: .utility) {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                await NotesSearchIndexer.shared.rebuildIfNeeded(context: modelContext, userId: currentUserId)
            }
        }
        .overlay {
            if showRecoveryAlert && !pendingRecordings.isEmpty {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { }

                PendingRecordingsNotice(
                    pendingCount: pendingRecordings.count,
                    onOpenSettings: {
                        let maxDate = pendingRecordings.map { $0.createdAt.timeIntervalSince1970 }.max() ?? 0
                        lastDismissedRecordingDate = maxDate
                        autoOpenPendingRecordings = true
                        showRecoveryAlert = false
                        showingSettings = true
                    },
                    onDismiss: {
                        let maxDate = pendingRecordings.map { $0.createdAt.timeIntervalSince1970 }.max() ?? 0
                        lastDismissedRecordingDate = maxDate
                        showRecoveryAlert = false
                    }
                )
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradeBottomSheet(
                title: upgradeTitle,
                message: UpgradeBottomSheet.unifiedMessage,
                primaryButtonTitle: "Upgrade to Pro",
                onUpgrade: {
                    showUpgradeSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showSubscription = true
                    }
                },
                onDismiss: { showUpgradeSheet = false }
            )
            .presentationDetents([.height(350)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
    }

    func dispatch(_ action: HomeScreenAction) {
        switch action {
        case .setNavigationPath(let value):
            navigationPath = value
        case .setSearchText(let value):
            searchText = value
        case .setInputText(let value):
            inputText = value
        case .setVoiceMode(let value):
            isVoiceMode = value
        case .setShowingSettings(let value):
            showingSettings = value
        case .setAutoOpenPendingRecordings(let value):
            autoOpenPendingRecordings = value
        case .setShowAIChat(let value):
            showAIChat = value
        case .setShowAgentActionsSheet(let value):
            showAgentActionsSheet = value
        case .setCustomActionInputPresented(let value):
            isCustomActionInputPresented = value
        case .setCustomActionPrompt(let value):
            customActionPrompt = value
        case .setTranslateInputPresented(let value):
            isTranslateInputPresented = value
        case .setShowDeleteConfirmation(let value):
            showDeleteConfirmation = value
        case .setShowMergeSuccessAlert(let value):
            showMergeSuccessAlert = value
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
        case .submitText:
            handleTextSubmit()
        case .cancelVoice:
            speechRecognizer.stopRecording(reason: .cancelled)
        case .confirmVoice:
            handleVoiceConfirmation()
        case .createBlankNote:
            createAndOpenBlankNote()

        case .deleteSelectedNotes:
            deleteSelectedNotes()
        case .deleteNotesAfterMerge:
            deleteNotes(notesToDeleteAfterMerge)
            exitSelectionMode()
        case .emptyTrash:
            emptyTrash()
        case .applyTagToSelected(let tag):
            applyTagToSelected(tag)
        case .hideKeyboard:
            hideKeyboard()

        case .executePendingAgentAction(let instruction):
            if let action = pendingAgentAction {
                Task { await executeAgentAction(action, instruction: instruction) }
            }
            pendingAgentAction = nil
            isCustomActionInputPresented = false
        case .translateSelect(let language):
            translateTargetLanguage = language
            if let action = pendingAgentAction {
                Task { await executeAgentAction(action, instruction: language) }
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
            if note.deletedAt != nil {
                homeViewModel.removeNoteLocally(id: note.id)
            }
            requestReload()
        }
    }

    var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.textSub)
                .font(.system(size: 16, weight: .semibold))

            TextField("home.search.placeholder", text: Binding(
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

    func requestReload(delayNanoseconds: UInt64 = 120_000_000) {
        scheduledReloadTask?.cancel()
        scheduledReloadTask = Task {
            if delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }
            guard !Task.isCancelled else { return }
            await homeViewModel.reload()
            clampSelectionToCurrentFilter()
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(DataService.shared.container!)
        .environmentObject(AuthService.shared)
        .environmentObject(SyncManager())
}
