import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var syncManager: SyncManager
    @Environment(\.scenePhase) private var scenePhase

    @Query(filter: #Predicate<Note> { $0.deletedAt == nil }, sort: [SortDescriptor(\Note.createdAt, order: .reverse)])
    private var allNotes: [Note]
    


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
    
    // Sidebar & Filtering
    @State private var isSidebarPresented = false
    @State private var selectedTag: Tag? = nil
    
    // Search
    @State private var searchText = ""
    @State private var isSearchVisible = false
    @FocusState private var isSearchFocused: Bool
    
    // Recording Recovery
    @State private var pendingRecordings: [PendingRecording] = []
    @State private var showRecoveryAlert = false
    @State private var isRecoveringRecording = false
    
    // Voice Processing
    // (Handled server-side in /ai/voice-note)
    @ObservedObject private var voiceService = VoiceProcessingService.shared

    private var recentNotes: [Note] {
        let activeNotes = allNotes
        var result = activeNotes
        
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
            return result // Return all matches when searching
        }
        
        return Array(result.prefix(50))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                if !isSelectionMode {
                                    // Sidebar Toggle
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            isSidebarPresented.toggle()
                                        }
                                    }) {
                                        Image(systemName: "line.3.horizontal")
                                            .font(.system(size: 22, weight: .medium)) // Slightly larger, cleaner weight
                                            .foregroundColor(.textMain)
                                            .frame(width: 44, height: 44)
                                    }
                                    .buttonStyle(.bouncy)
                                    .padding(.leading, -10)
                                    
                                    Text(selectedTag?.name ?? "ChillNote")
                                        .font(.displayMedium)
                                        .foregroundColor(.textMain)
                                    
                                    Spacer()
                                    
                                    // RIGHT SIDE ACTIONS
                                    HStack(spacing: 12) {
                                        // 1. AI Context Button (Featured)
                                        Button(action: enterSelectionMode) {
                                            Image("chillohead_touming")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 48, height: 48) // Back to slightly larger pop size
                                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2) // Maintain the subtle lift
                                                .opacity(speechRecognizer.isRecording ? 0.3 : 1.0)
                                                .grayscale(speechRecognizer.isRecording ? 1.0 : 0.0)
                                        }
                                        .buttonStyle(.bouncy)
                                        .disabled(speechRecognizer.isRecording)
                                        .accessibilityLabel("Enter AI Context Mode")
                                        
                                        // 2. Search Button
                                        Button(action: {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                isSearchVisible.toggle()
                                                if !isSearchVisible {
                                                    searchText = ""
                                                    hideKeyboard()
                                                } else {
                                                    isSearchFocused = true
                                                }
                                            }
                                        }) {
                                            Image(systemName: "magnifyingglass")
                                                .font(.system(size: 20, weight: .regular))
                                                .foregroundColor(isSearchVisible ? .accentPrimary : .textMain.opacity(0.8))
                                                .frame(width: 40, height: 40)
                                                .background(Color.white)
                                                .clipShape(Circle())
                                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                                .opacity(speechRecognizer.isRecording ? 0.3 : 1.0)
                                        }
                                        .buttonStyle(.bouncy)
                                        .disabled(speechRecognizer.isRecording)
                                        .accessibilityLabel("Search")
                                    }
                                } else {
                                    // Selection Mode Header (Clean Layout)
                                    HStack {
                                        // Left: Cancel
                                        Button("common.cancel") {
                                            exitSelectionMode()
                                        }
                                        .font(.bodyMedium)
                                        .foregroundColor(.textSub)
                                        
                                        Spacer()
                                        
                                        // Right: Actions
                                        HStack(spacing: 20) {
                                            if selectedNotes.count < recentNotes.count {
                                                Button("home.action.selectAll") {
                                                    selectAllNotes()
                                                }
                                                .font(.bodyMedium)
                                                .foregroundColor(.accentPrimary)
                                            } else {
                                                Button("home.action.deselectAll") {
                                                    selectedNotes.removeAll()
                                                }
                                                .font(.bodyMedium)
                                                .foregroundColor(.accentPrimary)
                                            }
                                            
                                            Button(action: { showDeleteConfirmation = true }) {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 18, weight: .medium)) // refined weight
                                                    .foregroundColor(.red.opacity(0.8)) // slightly softer red
                                            }
                                            .disabled(selectedNotes.isEmpty)
                                            .opacity(selectedNotes.isEmpty ? 0.3 : 1.0)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                            
                            // Search Bar
                            if !isSelectionMode && isSearchVisible {
                                searchBar
                                    .padding(.horizontal, 24)
                                    .padding(.top, 8)
                            }
                            


                            if recentNotes.isEmpty {
                                Text("home.empty.title")
                                    .font(.bodyMedium)
                                    .foregroundColor(.textSub)
                                    .padding(.horizontal, 24)
                                    .padding(.top, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                LazyVStack(spacing: 16) {
                                    ForEach(recentNotes) { note in
                                        if isSelectionMode {
                                            NoteCard(
                                                note: note,
                                                isSelectionMode: true,
                                                isSelected: selectedNotes.contains(note.id),
                                                onSelectionToggle: {
                                                    toggleNoteSelection(note)
                                                }
                                            )
                                        } else {
                                            NavigationLink(value: note) {
                                                NoteCard(note: note)
                                            }
                                            .buttonStyle(.plain)
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    deleteNote(note)
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.bottom, 100) // Extra padding for floating mic button
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            hideKeyboard()
                        }
                    }
                    .background(Color.bgPrimary)
                    .scrollDismissesKeyboard(.interactively)
                    .navigationDestination(for: Note.self) { note in
                        NoteDetailView(note: note)
                            .environmentObject(speechRecognizer)
                    }
                }
                
                // Floating Voice Input
                if !isSelectionMode && !isSearchFocused && searchText.isEmpty {
                    ChatInputBar(
                        text: $inputText,
                        isVoiceMode: $isVoiceMode,
                        speechRecognizer: speechRecognizer,
                        onSendText: {
                            handleTextSubmit()
                        },
                        onCancelVoice: {
                            speechRecognizer.stopRecording(reason: .cancelled)
                        },
                        onConfirmVoice: {
                            speechRecognizer.stopRecording()
                        },
                        onCreateBlankNote: {
                            createAndOpenBlankNote()
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Twin Floating Icons for Selection Mode
                // Text-Based Floating Action Bar (The "Chill" Capsule)
                if isSelectionMode {
                    VStack {
                        Spacer()
                        
                        // Action Menu (Text List) - Anchored above the bar
                        if isAgentMenuOpen {
                            VStack(spacing: 8) {
                                ForEach(AIAgentAction.defaultActions) { action in
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            isAgentMenuOpen = false
                                        }
                                        Task { await executeAgentAction(action) }
                                    }) {
                                        HStack {
                                            Text(action.title)
                                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                                .foregroundColor(.accentPrimary)
                                            
                                            Spacer()
                                            
                                            // Optional: subtly keep the icon for visual anchor, or remove if strictly purist
                                            // Keeping it small and subtle helps quick scanning
                                            Image(systemName: action.icon)
                                                .font(.system(size: 14))
                                                .foregroundColor(.accentPrimary.opacity(0.6))
                                        }
                                        .padding(.vertical, 16)
                                        .padding(.horizontal, 24)
                                        .background(Color.white)
                                        .cornerRadius(100) // Pill shape for individual actions
                                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                                    }
                                    .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
                                }
                            }
                            .padding(.bottom, 12)
                            .padding(.horizontal, 40) // Match approximate width of main bar
                            .transition(.opacity)
                        }
                        
                        // Main Control Capsule
                        HStack(spacing: 0) {
                            // Left: Ask
                            Button(action: startAIChat) {
                                Text("home.askChillo")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(.accentPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                            }
                            
                            // Divider
                            Rectangle()
                                .fill(Color.accentPrimary.opacity(0.15))
                                .frame(width: 1, height: 24)
                            
                            // Right: Actions
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    isAgentMenuOpen.toggle()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Text("home.actions")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    
                                    // Subtle chevron to indicate menu
                                    Image(systemName: "chevron.up")
                                        .font(.system(size: 12, weight: .bold))
                                        .rotationEffect(.degrees(isAgentMenuOpen ? 180 : 0))
                                }
                                .foregroundColor(.accentPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                            }
                        }
                        .background(Color.white) // Clean, premium white background
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 6) // Soft, premium shadow
                        .padding(.horizontal, 40)
                        .padding(.bottom, 32)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
                }
                
                // Agent Menu Overlay (Global Layer)
                // (Old global menu overlay removed in favor of local stack)
                if isSelectionMode && isAgentMenuOpen {
                    // Just the dismiss background
                     Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isAgentMenuOpen = false
                            }
                        }
                        .zIndex(99) // Just below the text pill
                }
                
                // Progress Overlay for Agent Actions
                if isExecutingAction, let progress = actionProgress {
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
            // Screen Edge Swipe to Open Sidebar
            .gesture(
                DragGesture()
                    .onEnded { value in
                        // Detect swipe from left edge (first 50pts) moving right
                        if value.startLocation.x < 50 && value.translation.width > 60 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isSidebarPresented = true
                            }
                        }
                    }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.bgPrimary.ignoresSafeArea())
            .overlay {
                // Sidebar Overlay
                SidebarView(
                    isPresented: $isSidebarPresented,
                    selectedTag: $selectedTag,
                    onSettingsTap: { showingSettings = true }
                )
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showingSettings) {
                SettingsView()
            }

            .fullScreenCover(isPresented: $showAIChat) {
                AIContextChatView(contextNotes: getSelectedNotes())
                    .environmentObject(syncManager)
                    .onDisappear {
                        exitSelectionMode()
                    }
            }
            .sheet(isPresented: $showAgentActionsSheet) {
                AIAgentActionsSheet(selectedCount: selectedNotes.count) { action in
                    Task { await executeAgentAction(action) }
                }
            }
            .alert("Delete Notes", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete \(selectedNotes.count) Note\(selectedNotes.count == 1 ? "" : "s")", role: .destructive) {
                    deleteSelectedNotes()
                }
            } message: {
                Text("Are you sure you want to delete \(selectedNotes.count) note\(selectedNotes.count == 1 ? "" : "s")? This action cannot be undone.")
            }
            .alert("Merge Successful", isPresented: $showMergeSuccessAlert) {
                Button("Keep Original Notes", role: .cancel) {
                    exitSelectionMode()
                }
                Button("Delete Originals", role: .destructive) {
                    deleteNotes(notesToDeleteAfterMerge)
                    exitSelectionMode()
                }
            } message: {
                Text("The notes have been merged into a new note. Would you like to delete the original \(notesToDeleteAfterMerge.count) notes?")
            }
            .onChange(of: speechRecognizer.recordingState) { _, newState in
                switch newState {
                case .processing:
                    // Only create a new note if we are on the home screen (not already in a note)
                    // This prevents duplicate notes when Retrying from NoteDetailView
                    guard navigationPath.isEmpty else { return }
                    
                    // Navigate immediately when user hits done
                    let note = Note(content: "")
                    
                    // Apply current tag context if active
                    if let currentTag = selectedTag {
                        note.tags.append(currentTag)
                        let now = Date()
                        currentTag.lastUsedAt = now
                        currentTag.updatedAt = now
                        note.updatedAt = now
                    }
                    
                    modelContext.insert(note)
                    try? modelContext.save()
                    
                    VoiceProcessingService.shared.processingStates[note.id] = .processing
                    currentRecordingNote = note
                    navigationPath.append(note)
                    
                case .idle:
                    // Post-processing update
                    if let note = currentRecordingNote {
                        let rawText = speechRecognizer.transcript
                        if !rawText.isEmpty {
                            Task {
                                await VoiceProcessingService.shared.startProcessing(note: note, rawTranscript: rawText, context: modelContext)
                                await syncManager.syncIfNeeded(context: modelContext)
                            }
                            
                            // CRITICAL FIX: Mark recording as complete to clean up the file
                            // This was missing, causing files to linger and trigger "Unfinished Recording" alerts
                            speechRecognizer.completeRecording()
                            
                        } else {
                            // Empty? Cancel state
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
            .task {
                await syncManager.syncIfNeeded(context: modelContext)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StartRecording"))) { _ in
                isVoiceMode = true
                speechRecognizer.startRecording()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task { await syncManager.syncIfNeeded(context: modelContext) }
            }
            .onAppear {
                checkForPendingRecordings()
            }
            .overlay {
                if showRecoveryAlert && !pendingRecordings.isEmpty {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { /* Prevent dismissal by tapping background */ }
                    
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
        let note = Note(content: "")
        
        // Apply current tag context if active
        if let currentTag = selectedTag {
            note.tags.append(currentTag)
            let now = Date()
            currentTag.lastUsedAt = now
            currentTag.updatedAt = now
            note.updatedAt = now
        }
        
        modelContext.insert(note)
        try? modelContext.save()
        
        // No tag generation needed for empty note
        
        // Trigger sync
        Task { await syncManager.syncIfNeeded(context: modelContext) }
        
        // Navigate
        navigationPath.append(note)
    }

    @discardableResult
    private func saveNote(text: String, shouldNavigate: Bool = false) -> Note? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let note = Note(content: trimmed)
        
        // Apply current tag context if active
        if let currentTag = selectedTag {
            note.tags.append(currentTag)
            let now = Date()
            currentTag.lastUsedAt = now
            currentTag.updatedAt = now
            note.updatedAt = now
        }
        
        withAnimation {
            modelContext.insert(note)
            
            // Trigger background tag generation
            Task {
                await generateTags(for: note)
            }
        }
        
        try? modelContext.save()
        Task { await syncManager.syncIfNeeded(context: modelContext) }
        
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
                    try? modelContext.save()
                    Task { await syncManager.syncIfNeeded(context: modelContext) }
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
            selectedNotes = Set(recentNotes.map { $0.id })
        }
    }
    
    private func getSelectedNotes() -> [Note] {
        return recentNotes.filter { selectedNotes.contains($0.id) }
    }
    
    private func startAIChat() {
        guard !selectedNotes.isEmpty else { return }
        showAIChat = true
    }
    
    // MARK: - Delete Methods
    
    private func deleteNote(_ note: Note) {
        guard note.deletedAt == nil else { return }
        withAnimation {
            note.markDeleted()
        }
        try? modelContext.save()
        TagService.shared.cleanupEmptyTags(context: modelContext)
        Task { await syncManager.syncIfNeeded(context: modelContext) }
    }
    
    private func executeAgentAction(_ action: AIAgentAction) async {
        let notesToProcess = getSelectedNotes()
        guard !notesToProcess.isEmpty else { return }
        
        await MainActor.run {
            isExecutingAction = true
            actionProgress = "Executing \(action.title)..."
        }
        
        do {
            _ = try await action.execute(on: notesToProcess, context: modelContext)
            
            await MainActor.run {
                try? modelContext.save()
                Task { await syncManager.syncIfNeeded(context: modelContext) }
                
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
        try? modelContext.save()
        TagService.shared.cleanupEmptyTags(context: modelContext)
        Task { await syncManager.syncIfNeeded(context: modelContext) }
    }
    
    // MARK: - Recording Recovery Methods
    
    private func checkForPendingRecordings() {
        // If we are currently recording or processing, DO NOT check for recovery
        // The current file is valid and active, not a crash remnant.
        guard speechRecognizer.recordingState == .idle else { return }
        
        // Clean up old recordings first (>24 hours)
        RecordingFileManager.shared.cleanupOldRecordings()
        
        // Check for pending recordings
        var pending = RecordingFileManager.shared.checkForPendingRecordings()
        
        // IMPORTANT: Filter out the file that might be currently held by SpeechRecognizer
        // even if state is idle (e.g. just finished but not cleaned yet)
        if let currentURL = speechRecognizer.getCurrentAudioFileURL() {
            pending.removeAll { $0.fileURL.path == currentURL.path }
        }
        
        if !pending.isEmpty {
            pendingRecordings = pending
            // Reduced to 0.1s just to ensure view hierarchy is ready, making it feel instant
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
                    let newNote = Note(content: "")
                    
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
