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
    @FocusState private var isSearchFocused: Bool
    
    // Recording Recovery
    @State private var pendingRecordings: [PendingRecording] = []
    @State private var showRecoveryAlert = false
    @State private var isRecoveringRecording = false
    
    // Voice Processing
    // (Handled server-side in /ai/voice-note)

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
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(.textMain)
                                            .frame(width: 44, height: 44)
                                    }
                                    .padding(.leading, -10)
                                    
                                    Text(selectedTag?.name ?? "ChillNote")
                                        .font(.displayMedium)
                                        .foregroundColor(.textMain)
                                    Spacer()
                                    
                                    // Manage button (for selection mode)
                                    Button(action: enterSelectionMode) {
                                        Image(systemName: "ellipsis.circle")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.accentPrimary)
                                            .frame(width: 40, height: 40)
                                            .background(Color.accentPrimary.opacity(0.1))
                                            .clipShape(Circle())
                                    }
                                    .accessibilityLabel("Manage notes")
                                    
                                    Button(action: { showingSettings = true }) {
                                        Image(systemName: "gearshape")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.textMain)
                                            .frame(width: 40, height: 40)
                                            .background(Color.white)
                                            .clipShape(Circle())
                                    }
                                    .accessibilityLabel("Open settings")
                                } else {
                                    // Selection Mode Header (Clean Layout)
                                    HStack {
                                        // Left: Cancel
                                        Button("Cancel") {
                                            exitSelectionMode()
                                        }
                                        .font(.bodyMedium)
                                        .foregroundColor(.textSub)
                                        
                                        Spacer()
                                        
                                        // Right: Actions
                                        HStack(spacing: 20) {
                                            if selectedNotes.count < recentNotes.count {
                                                Button("Select All") {
                                                    selectAllNotes()
                                                }
                                                .font(.bodyMedium)
                                                .foregroundColor(.accentPrimary)
                                            } else {
                                                Button("Deselect All") {
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
                            if !isSelectionMode {
                                VStack(spacing: 12) {
                                    searchBar
                                    
                                    if !searchText.isEmpty {
                                        askChilloButton
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.top, 8)
                            }
                            


                            if recentNotes.isEmpty {
                                Text("No notes yet. Start typing or recording below.")
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
                if isSelectionMode {
                    VStack {
                        Spacer()
                        HStack(spacing: 24) {
                            // Chat Button (Left)
                            Button(action: startAIChat) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 56, height: 56)
                                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                                    
                                    Image(systemName: "bubble.left.and.bubble.right.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.accentPrimary) // Using accent color for chat too for unity
                                }
                            }
                            
                            // Actions Menu (Right) - Toggle Button
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isAgentMenuOpen.toggle()
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 56, height: 56)
                                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                                    
                                    Image(systemName: isAgentMenuOpen ? "xmark" : "bolt.fill")
                                        .font(.system(size: isAgentMenuOpen ? 20 : 22, weight: isAgentMenuOpen ? .medium : .regular))
                                        .foregroundColor(.accentPrimary)
                                        .rotationEffect(.degrees(isAgentMenuOpen ? 90 : 0))
                                }
                            }
                        }
                        .padding(.bottom, 32)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Agent Menu Overlay (Global Layer)
                if isSelectionMode && isAgentMenuOpen {
                    ZStack(alignment: .bottom) {
                        // Background Dismiss Layer
                        Color.black.opacity(0.01)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isAgentMenuOpen = false
                                }
                            }
                        
                        // Menu Items Container - Aligned with bottom buttons
                        HStack(spacing: 24) {
                            // Spacer for Chat Button
                            Color.clear.frame(width: 56, height: 1)
                            
                            // Menu Items Column
                            VStack(spacing: 16) {
                                ForEach(Array(AIAgentAction.defaultActions.enumerated()), id: \.element.id) { index, action in
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            isAgentMenuOpen = false
                                        }
                                        // Delay execution slightly to allow UI to close
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            Task { await executeAgentAction(action) }
                                        }
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.white)
                                                .frame(width: 44, height: 44)
                                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                            
                                            Image(systemName: action.icon)
                                                .font(.system(size: 20))
                                                .foregroundColor(.accentPrimary)
                                        }
                                    }
                                    .transition(.scale(scale: 0.5).combined(with: .opacity).combined(with: .move(edge: .bottom)))
                                }
                                
                                // Spacer for Main Toggle Button
                                Color.clear.frame(width: 56, height: 56)
                            }
                        }
                        .padding(.bottom, 32)
                    }
                    .zIndex(100) // Ensure it's above everything else
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.bgPrimary.ignoresSafeArea())
            .overlay {
                // Sidebar Overlay
                SidebarView(isPresented: $isSidebarPresented, selectedTag: $selectedTag)
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showingSettings) {
                SettingsView()
            }

            .fullScreenCover(isPresented: $showAIChat) {
                // If we have an active search, pass that as context + initial query
                if !searchText.isEmpty && selectedNotes.isEmpty {
                    AIContextChatView(
                        contextNotes: searchContextNotes, // All notes (filtered by tag) for broad questions
                        initialQuery: searchText
                    )
                    .environmentObject(syncManager)
                } else {
                    AIContextChatView(contextNotes: getSelectedNotes())
                        .environmentObject(syncManager)
                        .onDisappear {
                            exitSelectionMode()
                        }
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
                    // Navigate immediately when user hits done
                    let note = Note(content: "")
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
            
            TextField("Find a thought...", text: $searchText)
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
    
    private var askChilloButton: some View {
        Button(action: {
            showAIChat = true
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.accentPrimary, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ask Chillo")
                        .font(.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(.textMain)
                    
                    Text("\"\(searchText)\"")
                        .font(.caption)
                        .foregroundColor(.textSub)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textSub.opacity(0.5))
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)
        }
    }
    
    /// Context notes for "Ask Chillo" - should respect Tag but ignore text search (so we search *in* the notes)
    private var searchContextNotes: [Note] {
        if let tag = selectedTag {
            return allNotes.filter { note in
                note.tags.contains { t in t.id == tag.id }
            }
        }
        // If no tag, maybe limit to recent 100 to avoid token overload?
        // Or just return all (local model might be fine, API might cost)
        // For now, let's cap at 100 most recent for "All Notes" queries to be safe
        return Array(allNotes.prefix(100))
    }
}

#Preview {
    HomeView()
        .modelContainer(DataService.shared.container!)
        .environmentObject(AuthService.shared)
        .environmentObject(SyncManager())
}
