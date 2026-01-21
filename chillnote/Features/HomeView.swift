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
    @State private var showingSettings = false
    @State private var inputText = ""
    @State private var isVoiceMode = true
    @State private var pendingNoteText: String? = nil
    
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
    
    // Voice Processing
    // (Handled server-side in /ai/voice-note)

    private var recentNotes: [Note] {
        return Array(allNotes.prefix(50))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                if !isSelectionMode {
                                    Text("ChillNote")
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
                                            NavigationLink {
                                                NoteDetailView(note: note)
                                            } label: {
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
            .background(Color.bgPrimary.ignoresSafeArea())
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
            .onChange(of: speechRecognizer.transcript) { _, newValue in
                if !newValue.isEmpty {
                    let rawTranscript = newValue
                    speechRecognizer.transcript = ""
                    Task {
                        await processAndSaveVoiceNote(rawTranscript: rawTranscript)
                    }
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
            .onChange(of: scenePhase) { newPhase in
                guard newPhase == .active else { return }
                Task { await syncManager.syncIfNeeded(context: modelContext) }
            }
        }
    }

    private func handleTextSubmit() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let noteText = trimmed
        inputText = ""

        saveNote(text: noteText)
    }

    private func saveNote(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        withAnimation {
            let note = Note(content: trimmed)
            modelContext.insert(note)
        }
        
        try? modelContext.save()
        Task { await syncManager.syncIfNeeded(context: modelContext) }
    }
    
    /// Process voice transcript with AI intent recognition before saving
    private func processAndSaveVoiceNote(rawTranscript: String) async {
        let trimmed = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Use the VoiceProcessingService to apply intent rules (email, list, etc.)
        // This is the "second pass" that structures the text based on the user's prompt.
        do {
            let processedText = try await VoiceProcessingService.shared.processTranscript(trimmed)
            
            await MainActor.run {
                saveNote(text: processedText)
            }
        } catch {
            print("⚠️ AI processing failed, falling back to raw text: \(error)")
            // Fallback to raw text if AI fails
            await MainActor.run {
                saveNote(text: trimmed)
            }
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
                exitSelectionMode()
                
                // TODO: Navigate to the new note or show success message
                // For now, just exit selection mode
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
        withAnimation {
            for note in notesToDelete where note.deletedAt == nil {
                note.markDeleted()
            }
        }
        try? modelContext.save()
        Task { await syncManager.syncIfNeeded(context: modelContext) }
        exitSelectionMode()
    }
}

#Preview {
    HomeView()
        .modelContainer(DataService.shared.container!)
        .environmentObject(AuthService.shared)
        .environmentObject(SyncManager())
}
