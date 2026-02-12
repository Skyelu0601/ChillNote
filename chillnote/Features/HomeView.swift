import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var syncManager: SyncManager
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var homeViewModel = HomeViewModel()

    private var currentUserId: String {
        authService.currentUserId ?? "unknown"
    }

    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var navigationPath = NavigationPath()
    @State private var showingSettings = false
    @State private var inputText = ""
    @State private var isVoiceMode = true
    @State private var pendingVoiceNoteByPath: [String: UUID] = [:]

    
    // Multi-selection mode for AI context
    @State private var isSelectionMode = false
    @State private var selectedNotes: Set<UUID> = []
    @State private var showAIChat = false
    @State private var showDeleteConfirmation = false
    
    // AI Agent Actions
    @State private var showAgentActionsSheet = false
    @State private var isAgentMenuOpen = false // Controls the custom overlay menu
    @State private var isExecutingAction = false
    @State private var actionProgress: String?
    
    // Merge Action State
    @State private var showMergeSuccessAlert = false
    @State private var notesToDeleteAfterMerge: [Note] = []
    
    // Batch Tagging State
    @State private var showBatchTagSheet = false
    @Query(sort: \Tag.name) private var availableTags: [Tag]
    
    // Agent Action Inputs
    @State private var pendingAgentAction: AIAgentAction?
    @State private var isCustomActionInputPresented = false
    @State private var customActionPrompt = ""
    @State private var isTranslateInputPresented = false
    @State private var translateTargetLanguage = ""
    @StateObject private var recipeManager = RecipeManager.shared
    @State private var showChillRecipes = false
    
    // Selection Limits
    private let askSoftLimit = 10
    private let askHardLimit = 20
    private let recipeSoftLimit = 5
    private let recipeHardLimit = 8
    @State private var showAskSoftLimitAlert = false
    @State private var showAskHardLimitAlert = false
    @State private var showRecipeSoftLimitAlert = false
    @State private var showRecipeHardLimitAlert = false
    @State private var pendingRecipeForConfirmation: AgentRecipe?
    
    // Limits & Upsell
    @State private var showUpgradeSheet = false
    @State private var showSubscription = false
    @State private var upgradeTitle = ""

    private let translateLanguages: [TranslateLanguage] = [
        TranslateLanguage(id: "zh-Hans", name: "Simplified Chinese", displayName: "简体中文", flag: "🇨🇳"),
        TranslateLanguage(id: "zh-Hant", name: "Traditional Chinese", displayName: "繁體中文", flag: "🇭🇰"),
        TranslateLanguage(id: "fr", name: "French", displayName: "Français", flag: "🇫🇷"),
        TranslateLanguage(id: "en", name: "English", displayName: "English", flag: "🇺🇸"),
        TranslateLanguage(id: "de", name: "German", displayName: "Deutsch", flag: "🇩🇪"),
        TranslateLanguage(id: "ja", name: "Japanese", displayName: "日本語", flag: "🇯🇵"),
        TranslateLanguage(id: "es", name: "Spanish", displayName: "Español", flag: "🇪🇸"),
        TranslateLanguage(id: "ko", name: "Korean", displayName: "한국어", flag: "🇰🇷")
    ]
    
    // Sidebar & Filtering
    
    // Sidebar & Filtering
    @State private var isSidebarPresented = false
    @State private var selectedTag: Tag? = nil
    @State private var isTrashSelected = false
    @State private var showEmptyTrashConfirmation = false
    
    // Search
    @State private var searchText = ""
    @State private var isSearchVisible = false
    @FocusState private var isSearchFocused: Bool
    
    // Recording Recovery
    @State private var pendingRecordings: [PendingRecording] = []
    @State private var showRecoveryAlert = false
    @State private var autoOpenPendingRecordings = false

    // Maintenance / Performance
    @State private var hasScheduledInitialMaintenance = false
    @State private var lastMaintenanceAt: Date?
    private let minimumMaintenanceInterval: TimeInterval = 30
    
    // Voice Processing
    // (Handled server-side in /ai/voice-note)
    @ObservedObject private var voiceService = VoiceProcessingService.shared

    private var headerTitle: String {
        if isTrashSelected {
            return "Recycle Bin"
        }
        return selectedTag?.name ?? "ChillNote"
    }
    
    var body: some View {
        homeBodyView
    }

    private var homeBodyView: some View {
        let onToggleSidebar: () -> Void = {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isSidebarPresented.toggle()
            }
        }
        let onOpenSidebar: () -> Void = {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isSidebarPresented = true
            }
        }
        let onToggleSearch: () -> Void = {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isSearchVisible.toggle()
                if !isSearchVisible {
                    searchText = ""
                    hideKeyboard()
                } else {
                    isSearchFocused = true
                }
            }
        }
        let onDeselectAll: () -> Void = { selectedNotes.removeAll() }
        let onShowBatchTagSheet: () -> Void = { showBatchTagSheet = true }
        let onShowDeleteConfirmation: () -> Void = { showDeleteConfirmation = true }
        let onShowEmptyTrashConfirmation: () -> Void = { showEmptyTrashConfirmation = true }
        let onCancelVoice: () -> Void = { speechRecognizer.stopRecording(reason: .cancelled) }
        let onConfirmVoice: () -> Void = { handleVoiceConfirmation() }
        let onDeleteNotesAfterMerge: () -> Void = {
            deleteNotes(notesToDeleteAfterMerge)
            exitSelectionMode()
        }
        let onExecutePendingAgentAction: (String) -> Void = { instruction in
            if let action = pendingAgentAction {
                Task { await executeAgentAction(action, instruction: instruction) }
            }
            pendingAgentAction = nil
            isCustomActionInputPresented = false
        }
        let onTranslateSelect: (String) -> Void = { language in
            let selectedLanguage = language
            translateTargetLanguage = selectedLanguage
            if let action = pendingAgentAction {
                Task { await executeAgentAction(action, instruction: selectedLanguage) }
            }
            translateTargetLanguage = ""
            pendingAgentAction = nil
            isTranslateInputPresented = false
        }
        let onCloseTranslate: () -> Void = {
            translateTargetLanguage = ""
            pendingAgentAction = nil
            isTranslateInputPresented = false
        }
        let onShowSettings: () -> Void = { showingSettings = true }
        let onAIChatDisappear: () -> Void = { exitSelectionMode() }
        let onOpenChillRecipes: () -> Void = { showChillRecipes = true }
        let onCloseChillRecipes: () -> Void = { showChillRecipes = false }

        return HomeBodyView(
            navigationPath: $navigationPath,
            isSelectionMode: $isSelectionMode,
            isSearchFocused: $isSearchFocused,
            searchText: $searchText,
            isSearchVisible: $isSearchVisible,
            isTrashSelected: $isTrashSelected,
            isAgentMenuOpen: $isAgentMenuOpen,
            showChillRecipes: $showChillRecipes,
            showingSettings: $showingSettings,
            autoOpenPendingRecordings: $autoOpenPendingRecordings,
            showAIChat: $showAIChat,
            showAgentActionsSheet: $showAgentActionsSheet,
            isCustomActionInputPresented: $isCustomActionInputPresented,
            customActionPrompt: $customActionPrompt,
            isTranslateInputPresented: $isTranslateInputPresented,
            translateTargetLanguage: $translateTargetLanguage,
            showDeleteConfirmation: $showDeleteConfirmation,
            showMergeSuccessAlert: $showMergeSuccessAlert,
            showEmptyTrashConfirmation: $showEmptyTrashConfirmation,
            showBatchTagSheet: $showBatchTagSheet,
            isSidebarPresented: $isSidebarPresented,
            selectedTag: $selectedTag,
            selectedNotes: $selectedNotes,
            notesToDeleteAfterMerge: $notesToDeleteAfterMerge,
            inputText: $inputText,
            isVoiceMode: $isVoiceMode,
            cachedVisibleNotes: homeViewModel.items,
            availableTags: availableTags,
            translateLanguages: translateLanguages,
            recipeManager: recipeManager,
            speechRecognizer: speechRecognizer,
            syncManager: syncManager,
            headerTitle: headerTitle,
            actionProgress: actionProgress,
            isExecutingAction: isExecutingAction,
            searchBar: AnyView(searchBar),
            getSelectedNotes: { getSelectedNotes() },
            showAskSoftLimitAlert: $showAskSoftLimitAlert,
            showAskHardLimitAlert: $showAskHardLimitAlert,
            showRecipeSoftLimitAlert: $showRecipeSoftLimitAlert,
            showRecipeHardLimitAlert: $showRecipeHardLimitAlert,
            askHardLimit: askHardLimit,
            recipeHardLimit: recipeHardLimit,
            onToggleSidebar: onToggleSidebar,
            onOpenSidebar: onOpenSidebar,
            onEnterSelectionMode: enterSelectionMode,
            onToggleSearch: onToggleSearch,
            onExitSelectionMode: exitSelectionMode,
            onSelectAll: selectAllNotes,
            onDeselectAll: onDeselectAll,
            onShowBatchTagSheet: onShowBatchTagSheet,
            onShowDeleteConfirmation: onShowDeleteConfirmation,
            onShowEmptyTrashConfirmation: onShowEmptyTrashConfirmation,
            onRestoreNote: restoreNote,
            onDeleteNotePermanently: deleteNotePermanently,
            onTogglePin: togglePin,
            onDeleteNote: deleteNote,
            onLoadMoreIfNeeded: { note in
                homeViewModel.loadMoreIfNeeded(currentItem: note)
            },
            onToggleNoteSelection: toggleNoteSelection,
            onHandleAgentActionRequest: handleAgentActionRequest,
            onStartAIChat: startAIChat,
            onHandleTextSubmit: handleTextSubmit,
            onCancelVoice: onCancelVoice,
            onConfirmVoice: onConfirmVoice,
            onCreateBlankNote: createAndOpenBlankNote,
            onDeleteSelectedNotes: deleteSelectedNotes,
            onDeleteNotesAfterMerge: onDeleteNotesAfterMerge,
            onEmptyTrash: emptyTrash,
            onApplyTagToSelected: applyTagToSelected,
            onHideKeyboard: hideKeyboard,
            onExecutePendingAgentAction: onExecutePendingAgentAction,
            onTranslateSelect: onTranslateSelect,
            onCloseTranslate: onCloseTranslate,
            onShowSettings: onShowSettings,
            onAIChatDisappear: onAIChatDisappear,
            onOpenChillRecipes: onOpenChillRecipes,
            onCloseChillRecipes: onCloseChillRecipes,
            onConfirmAskSoftLimit: { showAIChat = true },
            onConfirmRecipeSoftLimit: confirmPendingRecipeOverSoftLimit,
            onCancelRecipeSoftLimit: { pendingRecipeForConfirmation = nil },
            onNoteDetailDisappear: { note in
                if note.deletedAt != nil {
                    homeViewModel.removeNoteLocally(id: note.id)
                }
                Task {
                    await homeViewModel.reload()
                    clampSelectionToCurrentFilter()
                }
            }
        )
        .onChange(of: speechRecognizer.recordingState) { _, newState in
            if case .error(let msg) = newState {
                print("Error recording: \(msg)")
                isVoiceMode = false
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
            await NotesSearchIndexer.shared.rebuildIfNeeded(context: modelContext, userId: currentUserId)
        }
        .overlay {
            if showRecoveryAlert && !pendingRecordings.isEmpty {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { }
                
                PendingRecordingsNotice(
                    pendingCount: pendingRecordings.count,
                    onOpenSettings: {
                        autoOpenPendingRecordings = true
                        showRecoveryAlert = false
                        showingSettings = true
                    },
                    onDismiss: {
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

    
    private func applyTagToSelected(_ tag: Tag) {
        let notes = getSelectedNotes()
        guard !notes.isEmpty else { return }
        
        withAnimation {
            let now = Date()
            for note in notes {
                if !note.tags.contains(where: { $0.id == tag.id }) {
                    note.tags.append(tag)
                }
                note.updatedAt = now
            }
            // Update tag metadata
            touchTag(tag)
        }
        
        persistAndSync()
        
        // Optional: Exit selection mode or give feedback
        exitSelectionMode()
    }

    private func clampSelectionToCurrentFilter() {
        guard !selectedNotes.isEmpty else { return }
        let validIds = fetchFilteredNotes().map(\.id)
        selectedNotes = selectedNotes.intersection(Set(validIds))
    }

    private func fetchFilteredNotes() -> [Note] {
        let userId = currentUserId
        var descriptor = FetchDescriptor<Note>()
        if isTrashSelected {
            descriptor.predicate = #Predicate<Note> { note in
                note.userId == userId && note.deletedAt != nil
            }
        } else {
            descriptor.predicate = #Predicate<Note> { note in
                note.userId == userId && note.deletedAt == nil
            }
        }

        guard let fetched = try? modelContext.fetch(descriptor) else { return [] }

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return fetched.filter { note in
            let passesTag: Bool
            if let selectedTag {
                passesTag = note.tags.contains(where: { $0.id == selectedTag.id })
            } else {
                passesTag = true
            }

            let passesSearch: Bool
            if trimmedQuery.isEmpty {
                passesSearch = true
            } else {
                passesSearch = note.content.localizedCaseInsensitiveContains(trimmedQuery)
                    || note.tags.contains { $0.name.localizedCaseInsensitiveContains(trimmedQuery) }
            }

            return passesTag && passesSearch
        }
    }

    private func handleTextSubmit() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // If we are currently "recording" into a note but user typed instead, we might want to use that?
        // But for now, just save a new note.
        _ = saveNote(text: trimmed)
        inputText = ""
    }

    private func handleVoiceConfirmation() {
        guard speechRecognizer.isRecording else { return }
        guard let fileURL = speechRecognizer.getCurrentAudioFileURL() else {
            speechRecognizer.stopRecording()
            isVoiceMode = false
            return
        }

        let note = Note(content: "", userId: currentUserId)
        applyCurrentTagContext(to: note)
        modelContext.insert(note)
        try? modelContext.save()

        pendingVoiceNoteByPath[fileURL.path] = note.id
        VoiceProcessingService.shared.processingStates[note.id] = .processing(stage: .transcribing)

        if navigationPath.isEmpty {
            navigationPath.append(note)
        }

        Task {
            await homeViewModel.reload()
            clampSelectionToCurrentFilter()
        }

        speechRecognizer.stopRecording()
        isVoiceMode = false
    }

    private func handleCompletedTranscriptions() {
        let events = speechRecognizer.completedTranscriptions
        guard !events.isEmpty else { return }

        for event in events {
            guard let noteID = pendingVoiceNoteByPath[event.fileURL.path] else {
                continue
            }

            speechRecognizer.consumeCompletedTranscription(eventID: event.id)

            switch event.result {
            case .success(let rawText):
                pendingVoiceNoteByPath.removeValue(forKey: event.fileURL.path)
                speechRecognizer.completeRecording(fileURL: event.fileURL)

                let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    VoiceProcessingService.shared.processingStates.removeValue(forKey: noteID)
                    continue
                }
                guard let note = resolveNote(noteID) else {
                    VoiceProcessingService.shared.processingStates.removeValue(forKey: noteID)
                    continue
                }

                Task {
                    await VoiceProcessingService.shared.startProcessing(note: note, rawTranscript: trimmed, context: modelContext)
                    await homeViewModel.reload()
                    clampSelectionToCurrentFilter()
                    await syncManager.syncIfNeeded(context: modelContext)
                }

            case .failure(let message):
                print("⚠️ Home voice transcription failed: \(message)")
                VoiceProcessingService.shared.processingStates[noteID] = .idle
            }
        }
    }

    private func resolveNote(_ noteID: UUID) -> Note? {
        if let note = homeViewModel.note(with: noteID) {
            return note
        }
        let targetID = noteID
        let descriptor = FetchDescriptor<Note>(predicate: #Predicate<Note> { $0.id == targetID })
        return try? modelContext.fetch(descriptor).first
    }

    private func createAndOpenBlankNote() {
        let note = Note(content: "", userId: currentUserId)
        
        // Apply current tag context if active
        applyCurrentTagContext(to: note)
        
        modelContext.insert(note)
        persistAndSync()
        
        // No tag generation needed for empty note
        
        // Navigate
        navigationPath.append(note)
    }

    @discardableResult
    private func saveNote(text: String, shouldNavigate: Bool = false) -> Note? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let note = Note(content: trimmed, userId: currentUserId)
        
        // Apply current tag context if active
        applyCurrentTagContext(to: note)
        
        withAnimation {
            modelContext.insert(note)
            
            // Trigger background tag generation
            Task {
                await generateTags(for: note)
            }
        }
        
        persistAndSync()
        
        if shouldNavigate {
            navigationPath.append(note)
        }
        
        return note
    }
    
    /// Process voice transcript with AI intent recognition before saving
    private func processAndSaveVoiceNote(rawTranscript: String) async {
        let trimmed = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Save an empty note and only reveal the refined result when ready.
        let noteID = await MainActor.run {
            let note = Note(content: "", userId: currentUserId)
            applyCurrentTagContext(to: note)
            modelContext.insert(note)
            try? modelContext.save()
            VoiceProcessingService.shared.processingStates[note.id] = .processing(stage: .refining)
            navigationPath.append(note)
            return note.id
        }

        await homeViewModel.reload()
        clampSelectionToCurrentFilter()

        // Trigger AI processing in background.
        Task {
            // Find the note by ID to avoid Sendable issues
            if let note = resolveNote(noteID) {
                await VoiceProcessingService.shared.startProcessing(note: note, rawTranscript: trimmed, context: modelContext)
                await homeViewModel.reload()
                clampSelectionToCurrentFilter()
                await syncManager.syncIfNeeded(context: modelContext)
            }
        }
    }

    private func generateTags(for note: Note) async {
        do {
            // Fetch all existing tags for context
            let fetchDescriptor = FetchDescriptor<Tag>()
            let allTags = (try? modelContext.fetch(fetchDescriptor))?.map { $0.name } ?? []
            
            let suggestions = try await TagService.shared.suggestTags(for: note.content, existingTags: allTags)
            
            if !suggestions.isEmpty {
                await MainActor.run {
                    note.suggestedTags = suggestions
                    persistAndSync()
                }
            }
        } catch {
            print("⚠️ Failed to generate tags: \(error)")
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // MARK: - Selection Mode Methods
    
    private func enterSelectionMode() {
        guard !isTrashSelected else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isSelectionMode = true
            selectedNotes.removeAll()
        }
    }
    
    private func exitSelectionMode() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isSelectionMode = false
            selectedNotes.removeAll()
        }
    }
    
    private func toggleNoteSelection(_ note: Note) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedNotes.contains(note.id) {
                selectedNotes.remove(note.id)
            } else {
                selectedNotes.insert(note.id)
            }
        }
    }
    
    private func selectAllNotes() {
        let allIDs = Set(fetchFilteredNotes().map(\.id))
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedNotes = allIDs
        }
    }
    
    private func getSelectedNotes() -> [Note] {
        guard !selectedNotes.isEmpty else { return [] }
        let ids = Array(selectedNotes)
        let userId = currentUserId
        var descriptor = FetchDescriptor<Note>()
        descriptor.predicate = #Predicate<Note> { note in
            note.userId == userId && ids.contains(note.id)
        }
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    private func startAIChat() {
        guard !selectedNotes.isEmpty else { return }
        let selectedCount = selectedNotes.count
        if selectedCount > askHardLimit {
            showAskHardLimitAlert = true
            return
        }
        if selectedCount > askSoftLimit {
            showAskSoftLimitAlert = true
            return
        }
        showAIChat = true
    }
    
    // MARK: - Delete Methods
    
    private func deleteNote(_ note: Note) {
        guard note.deletedAt == nil else { return }
        withAnimation {
            note.markDeleted()
        }
        persistAndSync()
        TagService.shared.cleanupEmptyTags(context: modelContext, candidates: Array(note.tags))
    }
    
    private func restoreNote(_ note: Note) {
        guard note.deletedAt != nil else { return }
        let now = Date()
        withAnimation {
            note.deletedAt = nil
            note.updatedAt = now
            for tag in note.tags where tag.deletedAt != nil {
                tag.deletedAt = nil
                tag.updatedAt = now
            }
        }
        persistAndSync()
    }
    
    private func deleteNotePermanently(_ note: Note) {
        let noteId = note.id
        modelContext.delete(note)
        Task { await NotesSearchIndexer.shared.remove(noteIDs: [noteId]) }
        persistAndSync()
        TagService.shared.cleanupEmptyTags(context: modelContext, candidates: Array(note.tags))
    }
    
    private func emptyTrash() {
        let deleted = fetchDeletedNotesForCurrentUser()
        guard !deleted.isEmpty else { return }
        let affectedTags = deleted.flatMap { $0.tags }
        let deletedIds = deleted.map { $0.id }
        withAnimation {
            for note in deleted {
                modelContext.delete(note)
            }
        }
        Task { await NotesSearchIndexer.shared.remove(noteIDs: deletedIds) }
        persistAndSync()
        TagService.shared.cleanupEmptyTags(context: modelContext, candidates: affectedTags)
    }

    private func fetchDeletedNotesForCurrentUser() -> [Note] {
        var descriptor = FetchDescriptor<Note>()
        let userId = currentUserId
        descriptor.predicate = #Predicate<Note> { note in
            note.userId == userId && note.deletedAt != nil
        }
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func togglePin(_ note: Note) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if note.pinnedAt == nil {
                note.pinnedAt = Date()
            } else {
                note.pinnedAt = nil
            }
            note.updatedAt = Date()
        }
        persistAndSync()
    }
    
    private func handleAgentActionRequest(_ action: AIAgentAction) {
        if action.type == .custom {
            pendingAgentAction = action
            isCustomActionInputPresented = true
        } else if action.type == .translate {
            pendingAgentAction = action
            isTranslateInputPresented = true
        } else {
            Task { await executeAgentAction(action) }
        }
    }

    private func handleAgentActionRequest(_ recipe: AgentRecipe) {
        let selectedCount = selectedNotes.count
        if selectedCount > recipeHardLimit {
            pendingRecipeForConfirmation = nil
            showRecipeHardLimitAlert = true
            return
        }
        if selectedCount > recipeSoftLimit {
            pendingRecipeForConfirmation = recipe
            showRecipeSoftLimitAlert = true
            return
        }
        performAgentRecipe(recipe)
    }
    
    private func confirmPendingRecipeOverSoftLimit() {
        guard let recipe = pendingRecipeForConfirmation else { return }
        pendingRecipeForConfirmation = nil
        performAgentRecipe(recipe)
    }
    
    private func performAgentRecipe(_ recipe: AgentRecipe) {
        switch recipe.id {
        case "merge_notes":
            let action = AIAgentAction(
                type: .merge,
                title: recipe.name,
                icon: recipe.systemIcon,
                description: recipe.description,
                requiresConfirmation: true
            )
            Task { await executeAgentAction(action) }
        case "translate":
            let action = AIAgentAction(
                type: .translate,
                title: recipe.name,
                icon: recipe.systemIcon,
                description: recipe.description,
                requiresConfirmation: false
            )
            pendingAgentAction = action
            isTranslateInputPresented = true
        default:
            let action = AIAgentAction(
                type: .custom,
                title: recipe.name,
                icon: recipe.systemIcon,
                description: recipe.description,
                requiresConfirmation: false
            )
            Task { await executeAgentAction(action, instruction: recipe.prompt) }
        }
    }
    
    private func executeAgentAction(_ action: AIAgentAction, instruction: String? = nil) async {
        let notesToProcess = getSelectedNotes()
        guard !notesToProcess.isEmpty else { return }
        
        await MainActor.run {
            isExecutingAction = true
            actionProgress = "Executing \(action.title)..."
        }
        
        do {
            _ = try await action.execute(on: notesToProcess, context: modelContext, userInstruction: instruction)
            
            await MainActor.run {
                persistAndSync()
                
                isExecutingAction = false
                actionProgress = nil
                
                // If it was a merge action, offer to delete original notes
                if action.type == .merge {
                    notesToDeleteAfterMerge = notesToProcess
                    showMergeSuccessAlert = true
                } else {
                    exitSelectionMode()
                }
            }
        } catch {
            print("⚠️ Agent action failed: \(error)")
            await MainActor.run {
                isExecutingAction = false
                actionProgress = nil
                let message = error.localizedDescription
                if message.localizedCaseInsensitiveContains("daily free agent recipe limit reached") {
                    upgradeTitle = "Daily Agent Recipe limit reached"
                    showUpgradeSheet = true
                }
            }
        }
    }

    
    private func deleteSelectedNotes() {
        let notesToDelete = getSelectedNotes()
        deleteNotes(notesToDelete)
        exitSelectionMode()
    }
    
    // Helper to delete specific array of notes
    private func deleteNotes(_ notes: [Note]) {
        withAnimation {
            for note in notes where note.deletedAt == nil {
                note.markDeleted()
            }
        }
        persistAndSync()
        TagService.shared.cleanupEmptyTags(context: modelContext, candidates: notes.flatMap { $0.tags })
    }

    private func persistAndSync() {
        try? modelContext.save()
        Task {
            if FeatureFlags.useLocalFTSSearch {
                await NotesSearchIndexer.shared.syncIncremental(context: modelContext, userId: currentUserId)
            }
            await syncManager.syncIfNeeded(context: modelContext)
            await homeViewModel.reload()
            clampSelectionToCurrentFilter()
        }
    }

    private func touchTag(_ tag: Tag, note: Note? = nil) {
        let now = Date()
        tag.lastUsedAt = now
        tag.updatedAt = now
        note?.updatedAt = now
    }

    private func applyCurrentTagContext(to note: Note) {
        guard let currentTag = selectedTag else { return }
        note.tags.append(currentTag)
        touchTag(currentTag, note: note)
    }
    
    // MARK: - Recording Recovery Methods
    
    private enum MaintenanceReason {
        case initial
        case foreground
    }

    private func scheduleInitialMaintenance() {
        guard !hasScheduledInitialMaintenance else { return }
        hasScheduledInitialMaintenance = true
        Task {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 150_000_000)
            await runMaintenance(reason: .initial)
        }
    }

    private func scheduleMaintenance(reason: MaintenanceReason) {
        Task {
            await runMaintenance(reason: reason)
        }
    }

    @MainActor
    private func runMaintenance(reason: MaintenanceReason) async {
        let now = Date()
        if let lastMaintenanceAt, now.timeIntervalSince(lastMaintenanceAt) < minimumMaintenanceInterval {
            return
        }
        lastMaintenanceAt = now
        TrashPolicy.purgeExpiredNotes(context: modelContext)

        Task {
            await syncManager.syncIfNeeded(context: modelContext)
        }

        await checkForPendingRecordingsAsync()
    }

    private func checkForPendingRecordingsAsync() async {
        guard speechRecognizer.recordingState == .idle else { return }
        let currentPath = speechRecognizer.getCurrentAudioFileURL()?.path
        let pending = await Task.detached(priority: .utility) {
            RecordingFileManager.shared.cleanupOldRecordings()
            var pending = RecordingFileManager.shared.checkForPendingRecordings()
            if let currentPath {
                pending.removeAll { $0.fileURL.path == currentPath }
            }
            return pending
        }.value

        guard !pending.isEmpty else { return }
        await MainActor.run {
            pendingRecordings = pending
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    showRecoveryAlert = true
                }
            }
        }
    }
    
    // MARK: - Search Components
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.textSub)
                .font(.system(size: 16, weight: .semibold))
            
            TextField("home.search.placeholder", text: $searchText)
                .font(.bodyMedium)
                .foregroundColor(.textMain)
                .focused($isSearchFocused)
                .submitLabel(.search)
            
            if !searchText.isEmpty {
                Button(action: {
                    withAnimation {
                        searchText = ""
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
    
    // MARK: - Processing Status Badge
    
    private func processingStage(for note: Note) -> VoiceProcessingStage? {
        guard let state = voiceService.processingStates[note.id],
              case .processing(let stage) = state else {
            return nil
        }
        return stage
    }
    
    @ViewBuilder
    private func processingBadge(for note: Note) -> some View {
        if let stage = processingStage(for: note) {
            VoiceProcessingWorkflowView(currentStage: stage, style: .compact)
                .padding(12)
            .allowsHitTesting(false)
            .transition(.opacity)
        } else {
            EmptyView()
        }
    }

}

struct NoteListTagViewData: Identifiable {
    let id: UUID
    let name: String
    let color: Color
}

struct NoteListItemViewData: Identifiable {
    let id: UUID
    let createdAt: Date
    let pinnedAt: Date?
    let previewText: String
    let isEmpty: Bool
    let tags: [NoteListTagViewData]
    let hiddenTagCount: Int

    init(note: Note, usePlainPreview: Bool = true) {
        id = note.id
        createdAt = note.createdAt
        pinnedAt = note.pinnedAt

        let trimmed = note.content.trimmingCharacters(in: .whitespacesAndNewlines)
        isEmpty = trimmed.isEmpty
        if usePlainPreview {
            previewText = note.displayText
        } else {
            previewText = trimmed
        }

        let prefixTags = Array(note.tags.prefix(3))
        tags = prefixTags.map { tag in
            NoteListTagViewData(id: tag.id, name: tag.name, color: tag.color)
        }
        hiddenTagCount = max(0, note.tags.count - prefixTags.count)
    }
}

struct NoteCard: View {
    let item: NoteListItemViewData
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onSelectionToggle: (() -> Void)? = nil

    private var processingStage: VoiceProcessingStage? {
        guard let state = VoiceProcessingService.shared.processingStates[item.id],
              case .processing(let stage) = state else {
            return nil
        }
        return stage
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isSelectionMode {
                Button(action: {
                    onSelectionToggle?()
                }) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isSelected ? .accentPrimary : .textSub)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 8) {
                // Always show Timestamp
                HStack(alignment: .firstTextBaseline) {
                    Text(item.createdAt.relativeFormatted())
                        .font(.chillCaption)
                        .foregroundColor(.textSub)
                    if item.pinnedAt != nil {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.accentPrimary)
                            .padding(.leading, 4)
                            .accessibilityLabel(Text("Pinned"))
                    }
                    Spacer()
                }

                if let stage = processingStage {
                    VoiceProcessingWorkflowView(currentStage: stage, style: .compact)
                    .padding(.top, 2)
                    
                } else {
                    // Normal Content State
                    if item.isEmpty {
                        EmptyView()
                    } else {
                        Text(item.previewText)
                            .font(.bodyMedium)
                            .foregroundColor(.textMain)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }

                    if !item.tags.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(item.tags) { tag in
                                Text(tag.name)
                                    .font(.chillCaption)
                                    .foregroundColor(tag.color)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(tag.color.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            if item.hiddenTagCount > 0 {
                                Text("+\(item.hiddenTagCount)")
                                    .font(.chillCaption)
                                    .foregroundColor(.textSub)
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.shadowColor, radius: 8, y: 4)
    }
}

#Preview {
    HomeView()
        .modelContainer(DataService.shared.container!)
        .environmentObject(AuthService.shared)
        .environmentObject(SyncManager())
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}
