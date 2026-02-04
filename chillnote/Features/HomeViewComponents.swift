import SwiftUI
import SwiftData

struct TranslateLanguage: Identifiable {
    let id: String
    let name: String
    let displayName: String
    let flag: String
}

struct HomeBodyView: View {
    @Binding var navigationPath: NavigationPath
    @Binding var isSelectionMode: Bool
    @FocusState.Binding var isSearchFocused: Bool
    @Binding var searchText: String
    @Binding var isSearchVisible: Bool
    @Binding var isTrashSelected: Bool
    @Binding var isAgentMenuOpen: Bool
    @Binding var showChillRecipes: Bool
    @Binding var showingSettings: Bool
    @Binding var showAIChat: Bool
    @Binding var showAgentActionsSheet: Bool
    @Binding var isCustomActionInputPresented: Bool
    @Binding var customActionPrompt: String
    @Binding var isTranslateInputPresented: Bool
    @Binding var translateTargetLanguage: String
    @Binding var showDeleteConfirmation: Bool
    @Binding var showMergeSuccessAlert: Bool
    @Binding var showEmptyTrashConfirmation: Bool
    @Binding var showBatchTagSheet: Bool
    @Binding var isSidebarPresented: Bool
    @Binding var selectedTag: Tag?
    @Binding var selectedNotes: Set<UUID>
    @Binding var notesToDeleteAfterMerge: [Note]
    @Binding var inputText: String
    @Binding var isVoiceMode: Bool
    
    let cachedVisibleNotes: [Note]
    let availableTags: [Tag]
    let translateLanguages: [TranslateLanguage]
    let recipeManager: RecipeManager
    let speechRecognizer: SpeechRecognizer
    let syncManager: SyncManager
    let headerTitle: String
    let actionProgress: String?
    let isExecutingAction: Bool
    
    let searchBar: AnyView
    let getSelectedNotes: () -> [Note]
    
    @Binding var showAskSoftLimitAlert: Bool
    @Binding var showAskHardLimitAlert: Bool
    @Binding var showRecipeSoftLimitAlert: Bool
    @Binding var showRecipeHardLimitAlert: Bool
    let askHardLimit: Int
    let recipeHardLimit: Int
    
    let onToggleSidebar: () -> Void
    let onOpenSidebar: () -> Void
    let onEnterSelectionMode: () -> Void
    let onToggleSearch: () -> Void
    let onExitSelectionMode: () -> Void
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onShowBatchTagSheet: () -> Void
    let onShowDeleteConfirmation: () -> Void
    let onShowEmptyTrashConfirmation: () -> Void
    let onRestoreNote: (Note) -> Void
    let onDeleteNotePermanently: (Note) -> Void
    let onTogglePin: (Note) -> Void
    let onDeleteNote: (Note) -> Void
    let onToggleNoteSelection: (Note) -> Void
    let onHandleAgentActionRequest: (AgentRecipe) -> Void
    let onStartAIChat: () -> Void
    let onHandleTextSubmit: () -> Void
    let onCancelVoice: () -> Void
    let onConfirmVoice: () -> Void
    let onCreateBlankNote: () -> Void
    let onDeleteSelectedNotes: () -> Void
    let onDeleteNotesAfterMerge: () -> Void
    let onEmptyTrash: () -> Void
    let onApplyTagToSelected: (Tag) -> Void
    let onHideKeyboard: () -> Void
    let onExecutePendingAgentAction: (String) -> Void
    let onTranslateSelect: (String) -> Void
    let onCloseTranslate: () -> Void
    let onShowSettings: () -> Void
    let onAIChatDisappear: () -> Void
    let onOpenChillRecipes: () -> Void
    let onCloseChillRecipes: () -> Void
    let onConfirmAskSoftLimit: () -> Void
    let onConfirmRecipeSoftLimit: () -> Void
    let onCancelRecipeSoftLimit: () -> Void
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            rootContainer
        }
    }
    
    private var rootContainer: some View {
        ZStack(alignment: .bottom) {
            mainContent
            floatingVoiceInput
            selectionModeOverlay
            agentProgressOverlay
        }
        // Screen Edge Swipe to Open Sidebar
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.startLocation.x < 50 && value.translation.width > 60 {
                        onOpenSidebar()
                    }
                }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary.ignoresSafeArea())
        .overlay {
            SidebarView(
                isPresented: $isSidebarPresented,
                selectedTag: $selectedTag,
                isTrashSelected: $isTrashSelected,
                onSettingsTap: onShowSettings
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
                    onAIChatDisappear()
                }
        }
        .sheet(isPresented: $showAgentActionsSheet) {
            AIAgentActionsSheet(selectedCount: selectedNotes.count) { recipe in
                onHandleAgentActionRequest(recipe)
            }
        }
        .sheet(isPresented: $showChillRecipes) {
            NavigationStack {
                ChillRecipesView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Close") {
                                onCloseChillRecipes()
                            }
                        }
                    }
            }
        }
        .alert("Ask Agent", isPresented: $isCustomActionInputPresented) {
            TextField("What should I do?", text: $customActionPrompt)
            Button("Cancel", role: .cancel) {
                customActionPrompt = ""
            }
            Button("Do it") {
                onExecutePendingAgentAction(customActionPrompt)
                customActionPrompt = ""
            }
        } message: {
            Text("Enter your instruction for these notes.")
        }
        .alert("Large Selection", isPresented: $showAskSoftLimitAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Continue") {
                onConfirmAskSoftLimit()
            }
        } message: {
            Text("You selected \(selectedNotes.count) notes. Asking AI with many notes may be slower and less accurate.")
        }
        .alert("Too Many Notes", isPresented: $showAskHardLimitAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Ask AI supports up to \(askHardLimit) notes. Please reduce your selection.")
        }
        .alert("Large Selection", isPresented: $showRecipeSoftLimitAlert) {
            Button("Cancel", role: .cancel) {
                onCancelRecipeSoftLimit()
            }
            Button("Continue") {
                onConfirmRecipeSoftLimit()
            }
        } message: {
            Text("You selected \(selectedNotes.count) notes. This may take a while to process.")
        }
        .alert("Too Many Notes", isPresented: $showRecipeHardLimitAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Chill Recipes supports up to \(recipeHardLimit) notes. Please reduce your selection.")
        }
        .sheet(isPresented: $isTranslateInputPresented) {
            TranslateSheetView(
                translateLanguages: translateLanguages,
                onSelect: onTranslateSelect,
                onCancel: onCloseTranslate
            )
        }
        .alert("Delete Notes", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete \(selectedNotes.count) Note\(selectedNotes.count == 1 ? "" : "s")", role: .destructive) {
                onDeleteSelectedNotes()
            }
        } message: {
            Text("Are you sure you want to delete \(selectedNotes.count) note\(selectedNotes.count == 1 ? "" : "s")? This action cannot be undone.")
        }
        .alert("Merge Successful", isPresented: $showMergeSuccessAlert) {
            Button("Keep Original Notes", role: .cancel) { }
            Button("Delete Originals", role: .destructive) {
                onDeleteNotesAfterMerge()
            }
        } message: {
            Text("The notes have been merged into a new note. Would you like to delete the original \(notesToDeleteAfterMerge.count) notes?")
        }
        .alert("Empty Recycle Bin", isPresented: $showEmptyTrashConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Empty", role: .destructive) {
                onEmptyTrash()
            }
        } message: {
            Text("This will permanently delete all notes in the recycle bin.")
        }
        .sheet(isPresented: $showBatchTagSheet) {
            NavigationStack {
                List {
                    if availableTags.isEmpty {
                        Text("No tags available")
                            .foregroundColor(.textSub)
                    } else {
                        ForEach(availableTags) { tag in
                            Button {
                                onApplyTagToSelected(tag)
                                showBatchTagSheet = false
                            } label: {
                                HStack {
                                    Image(systemName: "tag.fill")
                                        .foregroundColor(.accentPrimary)
                                    Text(tag.name)
                                        .font(.bodyMedium)
                                        .foregroundColor(.textMain)
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .navigationTitle("Add Tag")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showBatchTagSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HomeHeaderView(
                        isSelectionMode: isSelectionMode,
                        isTrashSelected: isTrashSelected,
                        isSearchVisible: isSearchVisible,
                        isRecording: speechRecognizer.isRecording,
                        headerTitle: headerTitle,
                        selectedNotesCount: selectedNotes.count,
                        visibleNotesCount: cachedVisibleNotes.count,
                        onToggleSidebar: onToggleSidebar,
                        onEnterSelectionMode: onEnterSelectionMode,
                        onToggleSearch: onToggleSearch,
                        onExitSelectionMode: onExitSelectionMode,
                        onSelectAll: onSelectAll,
                        onDeselectAll: onDeselectAll,
                        onShowBatchTagSheet: onShowBatchTagSheet,
                        onShowDeleteConfirmation: onShowDeleteConfirmation,
                        onShowEmptyTrashConfirmation: onShowEmptyTrashConfirmation
                    )
                    
                    if !isSelectionMode && isSearchVisible {
                        searchBar
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                    }
                    
                    HomeNotesListView(
                        cachedVisibleNotes: cachedVisibleNotes,
                        isTrashSelected: isTrashSelected,
                        isSelectionMode: isSelectionMode,
                        selectedNotes: selectedNotes,
                        onToggleNoteSelection: onToggleNoteSelection,
                        onRestoreNote: onRestoreNote,
                        onDeleteNotePermanently: onDeleteNotePermanently,
                        onTogglePin: onTogglePin,
                        onDeleteNote: onDeleteNote
                    )
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onHideKeyboard()
                }
            }
            .background(Color.bgPrimary)
            .scrollDismissesKeyboard(.interactively)
            .navigationDestination(for: Note.self) { note in
                NoteDetailView(note: note)
                    .environmentObject(speechRecognizer)
            }
        }
    }
    
    private var floatingVoiceInput: some View {
        Group {
            if !isSelectionMode && !isSearchFocused && searchText.isEmpty && !isTrashSelected {
                ChatInputBar(
                    text: $inputText,
                    isVoiceMode: $isVoiceMode,
                    speechRecognizer: speechRecognizer,
                    onSendText: {
                        onHandleTextSubmit()
                    },
                    onCancelVoice: {
                        onCancelVoice()
                    },
                    onConfirmVoice: {
                        onConfirmVoice()
                    },
                    onCreateBlankNote: {
                        onCreateBlankNote()
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    private var selectionModeOverlay: some View {
        HomeSelectionOverlayView(
            isSelectionMode: isSelectionMode,
            isAgentMenuOpen: isAgentMenuOpen,
            recipeManager: recipeManager,
            onStartAIChat: onStartAIChat,
            onToggleAgentMenu: {
                isAgentMenuOpen.toggle()
            },
            onCloseMenu: {
                isAgentMenuOpen = false
            },
            onOpenChillRecipes: onOpenChillRecipes,
            onHandleAgentActionRequest: onHandleAgentActionRequest
        )
    }
    
    private var agentProgressOverlay: some View {
        Group {
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
    }
    
    
}

struct HomeHeaderView: View {
    let isSelectionMode: Bool
    let isTrashSelected: Bool
    let isSearchVisible: Bool
    let isRecording: Bool
    let headerTitle: String
    let selectedNotesCount: Int
    let visibleNotesCount: Int
    
    let onToggleSidebar: () -> Void
    let onEnterSelectionMode: () -> Void
    let onToggleSearch: () -> Void
    let onExitSelectionMode: () -> Void
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onShowBatchTagSheet: () -> Void
    let onShowDeleteConfirmation: () -> Void
    let onShowEmptyTrashConfirmation: () -> Void
    
    var body: some View {
        HStack {
            if !isSelectionMode {
                Button(action: onToggleSidebar) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.textMain)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bouncy)
                .padding(.leading, -10)
                
                Text(headerTitle)
                    .font(.displayMedium)
                    .foregroundColor(.textMain)
                
                Spacer()
                
                HStack(spacing: 12) {
                    if !isTrashSelected {
                        Button(action: onEnterSelectionMode) {
                            Image("chillohead_touming")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 48, height: 48)
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                .opacity(isRecording ? 0.3 : 1.0)
                                .grayscale(isRecording ? 1.0 : 0.0)
                        }
                        .buttonStyle(.bouncy)
                        .disabled(isRecording)
                        .accessibilityLabel("Enter AI Context Mode")
                    }
                    
                    Button(action: onToggleSearch) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(isSearchVisible ? .accentPrimary : .textMain.opacity(0.8))
                            .frame(width: 40, height: 40)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            .opacity(isRecording ? 0.3 : 1.0)
                    }
                    .buttonStyle(.bouncy)
                    .disabled(isRecording)
                    .accessibilityLabel("Search")
                    
                    if isTrashSelected {
                        Button(action: onShowEmptyTrashConfirmation) {
                            Image(systemName: "trash.slash")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundColor(.red.opacity(0.85))
                                .frame(width: 40, height: 40)
                                .background(Color.red.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.bouncy)
                        .accessibilityLabel("Empty Recycle Bin")
                    }
                }
            } else {
                HStack {
                    Button("common.cancel") {
                        onExitSelectionMode()
                    }
                    .font(.bodyMedium)
                    .foregroundColor(.textSub)
                    
                    Spacer()
                    
                    HStack(spacing: 20) {
                        if selectedNotesCount < visibleNotesCount {
                            Button("home.action.selectAll") {
                                onSelectAll()
                            }
                            .font(.bodyMedium)
                            .foregroundColor(.accentPrimary)
                        } else {
                            Button("home.action.deselectAll") {
                                onDeselectAll()
                            }
                            .font(.bodyMedium)
                            .foregroundColor(.accentPrimary)
                        }
                        
                        Button(action: onShowBatchTagSheet) {
                            Image(systemName: "tag")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.accentPrimary)
                        }
                        .disabled(selectedNotesCount == 0)
                        .opacity(selectedNotesCount == 0 ? 0.3 : 1.0)
                        
                        Button(action: onShowDeleteConfirmation) {
                            Image(systemName: "trash")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.red.opacity(0.8))
                        }
                        .disabled(selectedNotesCount == 0)
                        .opacity(selectedNotesCount == 0 ? 0.3 : 1.0)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
}

struct HomeNotesListView: View {
    let cachedVisibleNotes: [Note]
    let isTrashSelected: Bool
    let isSelectionMode: Bool
    let selectedNotes: Set<UUID>
    let onToggleNoteSelection: (Note) -> Void
    let onRestoreNote: (Note) -> Void
    let onDeleteNotePermanently: (Note) -> Void
    let onTogglePin: (Note) -> Void
    let onDeleteNote: (Note) -> Void
    
    var body: some View {
        if cachedVisibleNotes.isEmpty {
            Text(isTrashSelected ? "No deleted notes yet. Notes stay for 30 days." : "home.empty.title")
                .font(.bodyMedium)
                .foregroundColor(.textSub)
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            LazyVStack(spacing: 16) {
                ForEach(cachedVisibleNotes) { note in
                    if isTrashSelected {
                        NavigationLink(value: note) {
                            VStack(alignment: .leading, spacing: 8) {
                                NoteCard(note: note)
                                TrashNoteFooterView(note: note)
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                onRestoreNote(note)
                            } label: {
                                Label("Restore", systemImage: "arrow.uturn.left")
                            }
                            Button(role: .destructive) {
                                onDeleteNotePermanently(note)
                            } label: {
                                Label("Delete Permanently", systemImage: "trash.slash")
                            }
                        }
                    } else if isSelectionMode {
                        NoteCard(
                            note: note,
                            isSelectionMode: true,
                            isSelected: selectedNotes.contains(note.id),
                            onSelectionToggle: {
                                onToggleNoteSelection(note)
                            }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onToggleNoteSelection(note)
                        }
                    } else {
                        NavigationLink(value: note) {
                            NoteCard(note: note)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                onTogglePin(note)
                            } label: {
                                Label(note.pinnedAt == nil ? "Pin" : "Unpin", systemImage: note.pinnedAt == nil ? "pin" : "pin.slash")
                            }
                            Button(role: .destructive) {
                                onDeleteNote(note)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, isTrashSelected ? 24 : 100)
        }
    }
}

struct TrashNoteFooterView: View {
    let note: Note
    
    var body: some View {
        if let deletedAt = note.deletedAt {
            let daysRemaining = TrashPolicy.daysRemaining(from: deletedAt)
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 12))
                    .foregroundColor(.textSub)
                Text("Deleted \(deletedAt.relativeFormatted())")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSub)
                Text("•")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSub)
                Text(daysRemaining == 0 ? "Expires today" : "\(daysRemaining) days left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSub)
            }
            .padding(.horizontal, 8)
        }
    }
}

struct HomeSelectionOverlayView: View {
    let isSelectionMode: Bool
    let isAgentMenuOpen: Bool
    let recipeManager: RecipeManager
    let onStartAIChat: () -> Void
    let onToggleAgentMenu: () -> Void
    let onCloseMenu: () -> Void
    let onOpenChillRecipes: () -> Void
    let onHandleAgentActionRequest: (AgentRecipe) -> Void
    
    var body: some View {
        if isSelectionMode {
            ZStack(alignment: .bottom) {
                if isAgentMenuOpen {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .onTapGesture {
                            onCloseMenu()
                        }
                        .transition(.opacity)
                }
                
                VStack(spacing: 0) {
                    if isAgentMenuOpen {
                        VStack(spacing: 16) {
                            HStack {
                                Text("Chill Recipes")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button {
                                    onCloseMenu()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        onOpenChillRecipes()
                                    }
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.accentPrimary)
                                        .accessibilityLabel("Add Recipes")
                                }
                            }
                            .padding(.horizontal, 4)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                ForEach(recipeManager.savedRecipes) { recipe in
                                    Button(action: {
                                        onCloseMenu()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            onHandleAgentActionRequest(recipe)
                                        }
                                    }) {
                                        VStack(spacing: 10) {
                                            RecipeGridIcon(recipe: recipe, size: 22, container: 52)
                                            
                                            Text(recipe.name)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.primary)
                                                .multilineTextAlignment(.center)
                                                .lineLimit(2)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                                if recipeManager.savedRecipes.isEmpty {
                                    VStack(spacing: 8) {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 20))
                                            .foregroundColor(.secondary)
                                        Text("No recipes yet")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(24)
                        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95)))
                    }
                    
                    HStack(spacing: 0) {
                        Button(action: onStartAIChat) {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 16))
                                Text("Ask AI")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.accentPrimary)
                        }
                        
                        Button(action: onToggleAgentMenu) {
                            HStack(spacing: 6) {
                                Text("Chill Recipes")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 14, weight: .bold))
                                    .rotationEffect(.degrees(isAgentMenuOpen ? 180 : 0))
                            }
                            .foregroundColor(.accentPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white)
                        }
                    }
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 32)
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(100)
        }
    }
}

private struct RecipeGridIcon: View {
    let recipe: AgentRecipe
    var size: CGFloat = 20
    var container: CGFloat = 52
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.bgSecondary)
                .frame(width: container, height: container)
                .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)
            
            if recipe.icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Image(systemName: recipe.systemIcon)
                    .font(.system(size: size))
                    .foregroundColor(.accentPrimary)
            } else {
                Text(recipe.icon)
                    .font(.system(size: size + 2))
            }
        }
    }
}

struct TranslateSheetView: View {
    let translateLanguages: [TranslateLanguage]
    let onSelect: (String) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Image(systemName: "globe")
                                .font(.system(size: 48))
                                .foregroundStyle(LinearGradient(colors: [.accentPrimary, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .padding(.bottom, 8)
                            
                            Text("Select Language")
                                .font(.title2.bold())
                                .foregroundColor(.textMain)
                            
                            Text("Choose a language to translate your note")
                                .font(.subheadline)
                                .foregroundColor(.textSub)
                        }
                        .padding(.top, 24)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(translateLanguages) { language in
                                Button {
                                    onSelect(language.name)
                                } label: {
                                    HStack(spacing: 12) {
                                        Text(language.flag)
                                            .font(.system(size: 32))
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(language.displayName)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.textMain)
                                            
                                            Text(language.name)
                                                .font(.system(size: 12))
                                                .foregroundColor(.textSub)
                                        }
                                        Spacer()
                                    }
                                    .padding(16)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.black.opacity(0.03), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.textMain)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }
}
