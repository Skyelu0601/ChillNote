import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var syncManager: SyncManager
    @Environment(\.scenePhase) private var scenePhase

    private var currentUserId: String {
        authService.currentUserId ?? "unknown"
    }

    @Query(filter: #Predicate<Note> { $0.deletedAt == nil }, sort: [SortDescriptor(\Note.createdAt, order: .reverse)])
    private var allNotes: [Note]
    
    @Query(filter: #Predicate<Note> { $0.deletedAt != nil }, sort: [SortDescriptor(\Note.deletedAt, order: .reverse)])
    private var deletedNotes: [Note]
    
    private var userNotes: [Note] {
        allNotes.filter { $0.userId == currentUserId }
    }
    
    private var userDeletedNotes: [Note] {
        deletedNotes.filter { $0.userId == currentUserId }
    }
    


    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var navigationPath = NavigationPath()
    @State private var showingSettings = false
    @State private var inputText = ""
    @State private var isVoiceMode = true
    @State private var pendingNoteText: String? = nil
    @State private var currentRecordingNote: Note? // Track note being recorded for immediate nav

    
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

    private let translateLanguages: [TranslateLanguage] = [
        TranslateLanguage(id: "zh-Hans", name: "Simplified Chinese", displayName: "简体中文", flag: "🇨🇳"),
        TranslateLanguage(id: "zh-Hant", name: "Traditional Chinese", displayName: "繁体中文", flag: "🇭🇰"),
        TranslateLanguage(id: "fr", name: "French", displayName: "法语", flag: "🇫🇷"),
        TranslateLanguage(id: "en", name: "English", displayName: "英语", flag: "🇺🇸"),
        TranslateLanguage(id: "de", name: "German", displayName: "德语", flag: "🇩🇪"),
        TranslateLanguage(id: "ja", name: "Japanese", displayName: "日语", flag: "🇯🇵"),
        TranslateLanguage(id: "es", name: "Spanish", displayName: "西班牙语", flag: "🇪🇸"),
        TranslateLanguage(id: "ko", name: "Korean", displayName: "韩语", flag: "🇰🇷")
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
    @State private var cachedVisibleNotes: [Note] = []
    @State private var searchDebounceTask: Task<Void, Never>?
    
    // Recording Recovery
    @State private var pendingRecordings: [PendingRecording] = []
    @State private var showRecoveryAlert = false
    @State private var isRecoveringRecording = false

    // Maintenance / Performance
    @State private var hasScheduledInitialMaintenance = false
    @State private var lastMaintenanceAt: Date?
    private let minimumMaintenanceInterval: TimeInterval = 30
    
    // Voice Processing
    // (Handled server-side in /ai/voice-note)
    @ObservedObject private var voiceService = VoiceProcessingService.shared

    private func computeVisibleNotes() -> [Note] {
        if isTrashSelected {
            var result = userDeletedNotes
            if !searchText.isEmpty {
                result = result.filter { note in
                    note.content.localizedCaseInsensitiveContains(searchText) ||
                    note.tags.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
                }
            }
            return result
        }
        
        var result = userNotes
        
        // 1. Tag Filter
        if let tag = selectedTag {
            result = result.filter { note in
                note.tags.contains { t in t.id == tag.id }
            }
        }
        
        // 2. Search Filter
        if !searchText.isEmpty {
            result = result.filter { note in
                note.content.localizedCaseInsensitiveContains(searchText) ||
                note.tags.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
            return sortNotes(result)
        }
        
        return Array(sortNotes(result).prefix(50))
    }

    private func refreshVisibleNotes() {
        cachedVisibleNotes = computeVisibleNotes()
        if !selectedNotes.isEmpty {
            let visibleIds = Set(cachedVisibleNotes.map { $0.id })
            selectedNotes = selectedNotes.intersection(visibleIds)
        }
    }

    private func scheduleSearchRefresh() {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            await MainActor.run {
                refreshVisibleNotes()
            }
        }
    }
    
    private func sortNotes(_ notes: [Note]) -> [Note] {
        notes.sorted { lhs, rhs in
            switch (lhs.pinnedAt, rhs.pinnedAt) {
            case let (left?, right?):
                if left == right {
                    return lhs.createdAt > rhs.createdAt
                }
                return left > right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.createdAt > rhs.createdAt
            }
        }
    }
    
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
        let onConfirmVoice: () -> Void = { speechRecognizer.stopRecording() }
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
            cachedVisibleNotes: cachedVisibleNotes,
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
            onCancelRecipeSoftLimit: { pendingRecipeForConfirmation = nil }
        )
        .onChange(of: speechRecognizer.recordingState) { _, newState in
            switch newState {
            case .processing:
                guard navigationPath.isEmpty else { return }
                let note = Note(content: "", userId: currentUserId)
                applyCurrentTagContext(to: note)
                modelContext.insert(note)
                try? modelContext.save()
                VoiceProcessingService.shared.processingStates[note.id] = .processing
                currentRecordingNote = note
                navigationPath.append(note)
                
            case .idle:
                if let note = currentRecordingNote {
                    let rawText = speechRecognizer.transcript
                    if !rawText.isEmpty {
                        Task {
                            await VoiceProcessingService.shared.startProcessing(note: note, rawTranscript: rawText, context: modelContext)
                            await syncManager.syncIfNeeded(context: modelContext)
                        }
                        speechRecognizer.completeRecording()
                    } else {
                        VoiceProcessingService.shared.processingStates.removeValue(forKey: note.id)
                    }
                    currentRecordingNote = nil
                }
                isVoiceMode = false
                
            case .error(let msg):
                print("Error recording: \(msg)")
                currentRecordingNote = nil
                isVoiceMode = false
                
            default: break
            }
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
            refreshVisibleNotes()
        }
        .onChange(of: selectedTag) { _, _ in
            refreshVisibleNotes()
        }
        .onChange(of: searchText) { _, _ in
            scheduleSearchRefresh()
        }
        .onChange(of: allNotes.map { $0.updatedAt }) { _, _ in
            refreshVisibleNotes()
        }
        .onChange(of: deletedNotes.map { $0.deletedAt }) { _, _ in
            refreshVisibleNotes()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StartRecording"))) { _ in
            isVoiceMode = true
            speechRecognizer.startRecording()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            scheduleMaintenance(reason: .foreground)
        }
        .task {
            scheduleInitialMaintenance()
            refreshVisibleNotes()
        }
        .overlay {
            if showRecoveryAlert && !pendingRecordings.isEmpty {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { }
                
                RecordingRecoveryAlert(
                    pendingRecordings: pendingRecordings,
                    onRecover: { recording in
                        recoverRecording(recording)
                    },
                    onDiscard: { recording in
                        discardRecording(recording)
                    },
                    onDismiss: {
                        showRecoveryAlert = false
                    }
                )
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
    }

    
    private func applyTagToSelected(_ tag: Tag) {
        let notes = getSelectedNotes()
        guard !notes.isEmpty else { return }
        
        withAnimation {
            for note in notes {
                if !note.tags.contains(where: { $0.id == tag.id }) {
                    note.tags.append(tag)
                }
            }
            // Update tag metadata
            touchTag(tag)
        }
        
        persistAndSync()
        
        // Optional: Exit selection mode or give feedback
        exitSelectionMode()
    }

    private func handleTextSubmit() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // If we are currently "recording" into a note but user typed instead, we might want to use that?
        // But for now, just save a new note.
        _ = saveNote(text: trimmed)
        inputText = ""
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

        // NEW FLOW: Immediate navigation + Background Processing
        // 1. Save and navigate immediately with Raw Text
        let noteID = await MainActor.run {
            let note = saveNote(text: trimmed, shouldNavigate: true)
            return note?.id
        }
        
        guard let noteID = noteID else { return }
        
        // 2. Trigger AI processing in background
        Task {
            // Find the note by ID to avoid Sendable issues
            if let note = allNotes.first(where: { $0.id == noteID }) {
                await VoiceProcessingService.shared.startProcessing(note: note, rawTranscript: trimmed, context: modelContext)
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
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedNotes = Set(cachedVisibleNotes.map { $0.id })
        }
    }
    
    private func getSelectedNotes() -> [Note] {
        return cachedVisibleNotes.filter { selectedNotes.contains($0.id) }
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
        modelContext.delete(note)
        persistAndSync()
        TagService.shared.cleanupEmptyTags(context: modelContext, candidates: Array(note.tags))
    }
    
    private func emptyTrash() {
        guard !deletedNotes.isEmpty else { return }
        let affectedTags = deletedNotes.flatMap { $0.tags }
        withAnimation {
            for note in deletedNotes {
                modelContext.delete(note)
            }
        }
        persistAndSync()
        TagService.shared.cleanupEmptyTags(context: modelContext, candidates: affectedTags)
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
                // Could show error alert here
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
        Task { await syncManager.syncIfNeeded(context: modelContext) }
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
        await syncManager.syncIfNeeded(context: modelContext)
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
    
    private func recoverRecording(_ recording: PendingRecording) {
        guard !isRecoveringRecording else { return }
        isRecoveringRecording = true
        
        // Remove from list
        if let index = pendingRecordings.firstIndex(where: { $0.id == recording.id }) {
            pendingRecordings.remove(at: index)
        }
        
        // Close alert if no more recordings
        if pendingRecordings.isEmpty {
            showRecoveryAlert = false
        }
        
        Task {
            do {
                // Create a new note immediately and get its ID
                let noteID = await MainActor.run {
                    let newNote = Note(content: "", userId: currentUserId)
                    
                    // Apply current tag context if active
                    if let currentTag = selectedTag {
                        newNote.tags.append(currentTag)
                        let now = Date()
                        currentTag.lastUsedAt = now
                        currentTag.updatedAt = now
                        newNote.updatedAt = now
                    }
                    
                    modelContext.insert(newNote)
                    try? modelContext.save()
                    return newNote.id
                }
                
                // Set processing state and navigate
                await MainActor.run {
                    VoiceProcessingService.shared.processingStates[noteID] = .processing
                    // Find the note to navigate
                    if let note = allNotes.first(where: { $0.id == noteID }) {
                        navigationPath.append(note)
                    }
                }
                
                // Transcribe the recovered audio
                print("🔄 Recovering recording from: \(recording.fileURL.path)")
                let text = try await GeminiService.shared.transcribeAndPolish(
                    audioFileURL: recording.fileURL,
                    locale: Locale.current.identifier
                )
                
                await MainActor.run {
                    // Find the note by ID and update it
                    if let note = allNotes.first(where: { $0.id == noteID }) {
                        note.content = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        note.updatedAt = Date()
                        try? modelContext.save()
                        
                        // Start 2nd pass processing
                        Task {
                            await VoiceProcessingService.shared.startProcessing(note: note, rawTranscript: text, context: modelContext)
                            await syncManager.syncIfNeeded(context: modelContext)
                        }
                    }
                    
                    // Clean up the recording file
                    RecordingFileManager.shared.completeRecording(fileURL: recording.fileURL)
                    
                    isRecoveringRecording = false
                }
                
            } catch {
                print("❌ Recovery failed: \(error)")
                await MainActor.run {
                    // Clean up the failed recording
                    RecordingFileManager.shared.cancelRecording(fileURL: recording.fileURL)
                    isRecoveringRecording = false
                }
            }
        }
    }
    
    private func discardRecording(_ recording: PendingRecording) {
        // Remove from list
        if let index = pendingRecordings.firstIndex(where: { $0.id == recording.id }) {
            pendingRecordings.remove(at: index)
        }
        
        // Close alert if no more recordings
        if pendingRecordings.isEmpty {
            showRecoveryAlert = false
        }
        
        // Delete the recording file
        RecordingFileManager.shared.cancelRecording(fileURL: recording.fileURL)
        print("🗑️ Discarded recording: \(recording.fileName)")
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
    
    private enum ProcessingStage {
        case jotting
        case polishing
    }
    
    private func processingStage(for note: Note) -> ProcessingStage? {
        guard let state = voiceService.processingStates[note.id],
              case .processing = state else {
            return nil
        }
        
        let isEmpty = note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return isEmpty ? .jotting : .polishing
    }
    
    @ViewBuilder
    private func processingBadge(for note: Note) -> some View {
        if let stage = processingStage(for: note) {
            HStack(spacing: 6) {
                switch stage {
                case .jotting:
                    Image(systemName: "pencil.and.scribble")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.accentPrimary)
                    Text("Jotting this down...")
                        .font(.bodySmall)
                        .foregroundColor(.textMain)
                case .polishing:
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.accentPrimary, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("Getting your vibe...")
                        .font(.bodySmall)
                        .foregroundColor(.textMain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.08), radius: 6, y: 2)
            .overlay(
                Capsule()
                    .stroke(Color.accentPrimary.opacity(0.2), lineWidth: 1)
            )
            .padding(12)
            .allowsHitTesting(false)
            .transition(.opacity)
        } else {
            EmptyView()
        }
    }

}

struct NoteCard: View {
    let note: Note
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onSelectionToggle: (() -> Void)? = nil

    private enum ProcessingStage {
        case jotting
        case polishing
    }

    private var processingStage: ProcessingStage? {
        guard let state = VoiceProcessingService.shared.processingStates[note.id],
              case .processing = state else {
            return nil
        }
        
        let isEmpty = note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return isEmpty ? .jotting : .polishing
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
                    Text(note.createdAt.relativeFormatted())
                        .font(.chillCaption)
                        .foregroundColor(.textSub)
                    if note.pinnedAt != nil {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.accentPrimary)
                            .padding(.leading, 4)
                            .accessibilityLabel(Text("Pinned"))
                    }
                    Spacer()
                }

                if let stage = processingStage {
                    // Processing State: Show Badge INLINE
                    HStack(spacing: 6) {
                        switch stage {
                        case .jotting:
                            Image(systemName: "pencil.and.scribble")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.accentPrimary)
                            Text("Jotting this down...")
                                .font(.bodySmall)
                                .foregroundColor(.textMain)
                        case .polishing:
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.accentPrimary, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Text("Getting your vibe...")
                                .font(.bodySmall)
                                .foregroundColor(.textMain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.08), radius: 6, y: 2)
                    .overlay(
                        Capsule()
                            .stroke(Color.accentPrimary.opacity(0.2), lineWidth: 1)
                    )
                    // Slightly reduce top padding to align nicely where text would be
                    .padding(.top, 2)
                    
                } else {
                    // Normal Content State
                    if note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("home.empty.title")
                            .font(.bodyMedium)
                            .foregroundColor(.textSub)
                    } else {
                        RichTextPreview(
                            content: note.content,
                            lineLimit: 3,
                            font: .bodyMedium,
                            textColor: .textMain
                        )
                    }

                    if !note.tags.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(note.tags.prefix(3)) { tag in
                                Text(tag.name)
                                    .font(.chillCaption)
                                    .foregroundColor(tag.color)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(tag.color.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            if note.tags.count > 3 {
                                Text("+\(note.tags.count - 3)")
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
