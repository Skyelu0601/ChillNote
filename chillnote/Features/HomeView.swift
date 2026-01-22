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
    
    // Voice Processing
    // (Handled server-side in /ai/voice-note)

    private var recentNotes: [Note] {
        let activeNotes = allNotes
        if let tag = selectedTag {
            return activeNotes.filter { note in
                note.tags.contains { t in t.id == tag.id }
            }
        }
        return Array(activeNotes.prefix(50))
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
                    }
                }
                
                // Floating Voice Input
                if !isSelectionMode {
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
                            // Update content and start 2nd pass
                            note.content = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
                            Task {
                                await VoiceProcessingService.shared.startProcessing(note: note, rawTranscript: rawText)
                            }
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
            .onChange(of: authService.isSignedIn) { isSignedIn in
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
            .onChange(of: scenePhase) { newPhase in
                guard newPhase == .active else { return }
                Task { await syncManager.syncIfNeeded(context: modelContext) }
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
        let note = await MainActor.run {
            saveNote(text: trimmed, shouldNavigate: true)
        }
        
        guard let note = note else { return }
        
        // 2. Trigger AI processing in background
        Task {
            await VoiceProcessingService.shared.startProcessing(note: note, rawTranscript: trimmed)
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
}

#Preview {
    HomeView()
        .modelContainer(DataService.shared.container!)
        .environmentObject(AuthService.shared)
        .environmentObject(SyncManager())
}
