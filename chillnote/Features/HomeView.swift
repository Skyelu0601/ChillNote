import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var syncManager: SyncManager
    @Environment(\.scenePhase) private var scenePhase

    @Query(filter: #Predicate<Note> { $0.deletedAt == nil }, sort: [SortDescriptor(\Note.createdAt, order: .reverse)])
    private var allNotes: [Note]
    
    @Query(sort: \Category.order) private var allCategories: [Category]

    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var showingSettings = false
    @State private var inputText = ""
    @State private var isVoiceMode = false
    @State private var selectedCategory: Category? = nil
    @State private var showCategorySelector = false
    @State private var pendingNoteText: String? = nil
    
    // Multi-selection mode for AI context
    @State private var isSelectionMode = false
    @State private var selectedNotes: Set<UUID> = []
    @State private var showAIChat = false
    @State private var showDeleteConfirmation = false

    private var recentNotes: [Note] {
        let filtered = selectedCategory == nil 
            ? allNotes 
            : allNotes.filter { note in
                note.categories?.contains(where: { $0.id == selectedCategory?.id }) ?? false
            }
        return Array(filtered.prefix(50))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                if !isSelectionMode {
                                    Text("Recent Notes")
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
                                    // Selection mode header
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Select Notes")
                                            .font(.displayMedium)
                                            .foregroundColor(.textMain)
                                        Text("\(selectedNotes.count) selected")
                                            .font(.caption)
                                            .foregroundColor(.textSub)
                                    }
                                    Spacer()
                                    
                                    // Delete button
                                    Button(action: { showDeleteConfirmation = true }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.red)
                                            .padding(8)
                                    }
                                    .disabled(selectedNotes.isEmpty)
                                    .opacity(selectedNotes.isEmpty ? 0.3 : 1.0)
                                    .accessibilityLabel("Delete selected notes")
                                    
                                    Button("Select All") {
                                        selectAllNotes()
                                    }
                                    .font(.bodyMedium)
                                    .foregroundColor(.accentPrimary)
                                    
                                    Button("Cancel") {
                                        exitSelectionMode()
                                    }
                                    .font(.bodyMedium)
                                    .foregroundColor(.textSub)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                            
                            // Category Filter Bar
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    CategoryPill(
                                        category: nil,
                                        count: allNotes.count,
                                        isSelected: selectedCategory == nil
                                    ) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            selectedCategory = nil
                                        }
                                    }
                                    
                                    ForEach(allCategories) { category in
                                        CategoryPill(
                                            category: category,
                                            count: allNotes.filter { note in
                                                note.categories?.contains(where: { $0.id == category.id }) ?? false
                                            }.count,
                                            isSelected: selectedCategory?.id == category.id
                                        ) {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                selectedCategory = selectedCategory?.id == category.id ? nil : category
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                            .padding(.bottom, 8)

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
                                .padding(.bottom, 20)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            hideKeyboard()
                        }
                    }
                    .background(Color.bgPrimary)
                    .scrollDismissesKeyboard(.interactively)
                    
                    // Show AI chat button in selection mode, otherwise show input bar
                    if isSelectionMode {
                        VStack(spacing: 0) {
                            Divider()
                                .background(Color.textSub.opacity(0.2))
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(selectedNotes.count) notes selected")
                                        .font(.bodyMedium)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.textMain)
                                    if selectedNotes.count > 0 {
                                        Text("Tap button to start AI chat")
                                            .font(.caption)
                                            .foregroundColor(.textSub)
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: startAIChat) {
                                    HStack(spacing: 8) {
                                        Text("AI")
                                            .font(.system(size: 16, weight: .bold))
                                        Text("Chat")
                                            .font(.bodyMedium)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(.textMain)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.mellowYellow, Color.mellowOrange],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(24)
                                    .shadow(color: Color.mellowOrange.opacity(0.3), radius: 8, x: 0, y: 4)
                                }
                                .disabled(selectedNotes.isEmpty)
                                .opacity(selectedNotes.isEmpty ? 0.5 : 1.0)
                            }
                            .padding(16)
                            .background(Color.white)
                        }
                    } else {
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
                    }
                }
            }
            .background(Color.bgPrimary.ignoresSafeArea())
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showCategorySelector, onDismiss: {
                pendingNoteText = nil
            }) {
                CategorySelectorSheet(
                    onConfirm: { selectedCategories in
                        if let noteText = pendingNoteText {
                            saveNoteWithCategories(text: noteText, categories: selectedCategories)
                        }
                        pendingNoteText = nil
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $showAIChat) {
                AIContextChatView(contextNotes: getSelectedNotes())
                    .onDisappear {
                        exitSelectionMode()
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
                    pendingNoteText = newValue
                    speechRecognizer.transcript = ""
                    showCategorySelector = true
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
        
        // Clear input immediately for better UX
        let noteText = trimmed
        inputText = ""

        // Ask user to tag manually (or skip).
        pendingNoteText = noteText
        showCategorySelector = true
    }

    private func saveNoteWithCategories(text: String, categories: [Category]) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        withAnimation {
            let note = Note(content: trimmed)
            modelContext.insert(note)
            
            // Add selected categories
            for category in categories {
                note.addCategory(category)
            }
        }
        
        try? modelContext.save()
        Task { await syncManager.syncIfNeeded(context: modelContext) }
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
        withAnimation {
            modelContext.delete(note)
        }
        try? modelContext.save()
        Task { await syncManager.syncIfNeeded(context: modelContext) }
    }
    
    private func deleteSelectedNotes() {
        let notesToDelete = getSelectedNotes()
        withAnimation {
            for note in notesToDelete {
                modelContext.delete(note)
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
