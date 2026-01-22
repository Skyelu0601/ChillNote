import SwiftUI
import SwiftData
import UIKit

struct NoteDetailView: View {
    @Bindable var note: Note
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var syncManager: SyncManager
    @EnvironmentObject private var actionsManager: AIActionsManager
    
    @State private var showDeleteConfirmation = false
    @State private var inputText = ""
    @State private var isVoiceMode = false
    @State private var isProcessing = false // Local processing state (e.g. for Magic Wand)
    @ObservedObject private var voiceService = VoiceProcessingService.shared // Global processing state (background)
    @StateObject private var speechRecognizer = SpeechRecognizer()
    
    // AI Quick Actions
    @State private var showAIActionsSheet = false
    @State private var showAIToolbar = false
    @State private var currentAIAction: CustomAIAction?
    @State private var aiOriginalContent: String?
    @State private var isProgrammaticContentUpdate = false
    @State private var isWriting = false
    
    // Manual Tag Input
    @State private var showAddTagAlert = false
    @State private var newTagName = ""
    
    // Voice Input State
    @State private var recordingStartTime: Date?
    @State private var recordingDuration: TimeInterval = 0
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    Button(action: { 
                        updateTimestampAndDismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.textMain)
                            .padding(8)
                    }
                    .accessibilityLabel("Back")
                    
                    if isProcessing {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.6)
                            Text("AI Thinking...")
                                .font(.system(size: 12))
                                .foregroundColor(.textSub)
                        }
                    }
                    
                    Spacer()
                    
                    if isVoiceMode && speechRecognizer.isRecording {
                        // Compact Recording State in Header
                        HStack(spacing: 8) {
                            Text(timeString(from: recordingDuration))
                                .font(.system(size: 14, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.accentPrimary)
                            
                            Image(systemName: "waveform")
                                .symbolEffect(.variableColor.iterative.dimInactiveLayers, isActive: true)
                                .font(.system(size: 14))
                                .foregroundColor(.accentPrimary)
                            
                            Button(action: stopRecording) {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Color.accentPrimary)
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.leading, 12)
                        .padding(.trailing, 4)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.bgSecondary))
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                    } else {
                        // Compact Action Buttons
                        HStack(spacing: 8) {
                            // Microphone
                            Button(action: startRecording) {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.accentPrimary)
                                    .frame(width: 32, height: 32)
                                    .background(Color.bgSecondary)
                                    .clipShape(Circle())
                            }
                            .accessibilityLabel("Voice Input")
                            
                            // Magic Wand
                            Button(action: {
                                if let action = actionsManager.enabledActions.first {
                                    Task { await executeAIAction(action) }
                                }
                            }) {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 16))
                                    .foregroundColor(.accentPrimary)
                                    .frame(width: 32, height: 32)
                                    .background(Color.bgSecondary)
                                    .clipShape(Circle())
                            }
                            .accessibilityLabel("AI Magic")
                            .disabled(isProcessing || note.content.isEmpty)
                            .opacity((isProcessing || note.content.isEmpty) ? 0.5 : 1)
                            
                            // More Menu (Ellipsis)
                            Menu {
                                Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                                    Label("Delete Note", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 16))
                                    .foregroundColor(.textSub)
                                    .frame(width: 32, height: 32)
                                    .background(Color.bgSecondary)
                                    .clipShape(Circle())
                            }
                            .accessibilityLabel("More Actions")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                


                if let state = voiceService.processingStates[note.id],
                   case .processing = state,
                   note.content.isEmpty {
                    
                    // Stage 1: Jotting (Glass Capsule Top - Same Position as Stage 2)
                    HStack(spacing: 12) {
                        Image(systemName: "pencil.and.scribble")
                            .font(.system(size: 16))
                            .foregroundColor(.accentPrimary)
                            .symbolEffect(.variableColor.iterative, options: .repeating)
                        
                        Text("Jotting this down...")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.textMain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
                    .overlay(
                        Capsule().stroke(Color.accentPrimary.opacity(0.2), lineWidth: 1)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading) // Align left
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .transition(.opacity) // Smoother transition in place
                    
                } else {
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 0) {
                            
                            // Stage 2: Getting your vibe (Inline Header)
                            // Stage 2: Getting your vibe (Glass Capsule Top)
                            if let state = voiceService.processingStates[note.id],
                               case .processing = state,
                               !note.content.isEmpty {
                                HStack(spacing: 10) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 14))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.accentPrimary, .purple],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .symbolEffect(.bounce, options: .repeating)
                                    
                                    Text("Getting your vibe...")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
                                .overlay(
                                    Capsule()
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [Color.accentPrimary.opacity(0.3), Color.purple.opacity(0.3)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 16)
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                            
                            Text(note.createdAt.relativeFormatted())
                                .font(.bodySmall)
                                .foregroundColor(.textSub)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 8)

                            // Tag Banner
                            TagBannerView(
                                tags: note.tags,
                                suggestedTags: note.suggestedTags,
                                onConfirm: { tagName in
                                    confirmTag(tagName)
                                },
                                onRemove: { tag in
                                    note.tags.removeAll { $0.id == tag.id }
                                    TagService.shared.cleanupEmptyTags(context: modelContext)
                                },
                                onAddClick: {
                                    newTagName = ""
                                    showAddTagAlert = true
                                }
                            )
                            .padding(.top, 0)
                            .padding(.bottom, 16)
                            .padding(.horizontal, 20)
                            
                            // Rich Text Editor - renders markdown as formatted text
                            RichTextEditorView(
                                text: $note.content,
                                isEditable: !isProcessing && voiceService.processingStates[note.id] != .processing,
                                font: .systemFont(ofSize: 17),
                                textColor: UIColor(Color.textMain),
                                bottomInset: 40,
                                isScrollEnabled: false
                            )
                            .padding(.horizontal, 4)
                            .opacity(isProcessing ? 0.6 : 1.0)
                            .frame(minHeight: 400)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            
            // Stage 3: Magic Applied (Glass Capsule Bottom)
            if let state = voiceService.processingStates[note.id],
               case .completed(let originalText) = state {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 14))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.accentPrimary, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("Magic applied")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        ContainerRelativeShape()
                            .fill(Color.primary.opacity(0.1))
                            .frame(width: 1, height: 16)
                            .padding(.horizontal, 4)
                        
                        Button(action: {
                            withAnimation {
                                note.content = originalText
                                voiceService.processingStates.removeValue(forKey: note.id)
                            }
                        }) {
                            Text("Undo")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.accentPrimary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.accentPrimary.opacity(0.4), Color.purple.opacity(0.4)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        // Haptic feedback for success
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                }
            }
            
            // AI Action Review Toolbar (Floats at bottom only when reviewing changes)
            if showAIToolbar, let action = currentAIAction {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        AIActionToolbar(
                            onRetry: {
                                Task { await executeAIAction(action) }
                            },
                            onUndo: {
                                undoAIContent()
                            },
                            onSave: {
                                saveAIContentAndDismissToolbar()
                            }
                        )
                        .frame(maxWidth: 360)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationBarHidden(true)
        .alert("Add Tag", isPresented: $showAddTagAlert) {
            TextField("Tag name", text: $newTagName)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button("Cancel", role: .cancel) { }
            Button("Add") {
                let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    confirmTag(trimmed)
                }
            }
        } message: {
            Text("Enter a name for your custom tag.")
        }
        .alert("Delete Note", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteNote()
            }
        } message: {
            Text("Are you sure you want to delete this note? This action cannot be undone.")
        }
        .onReceive(timer) { _ in
            if speechRecognizer.isRecording, let startTime = recordingStartTime {
                recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
        .onChange(of: speechRecognizer.recordingState) { _, newState in
            switch newState {
            case .processing:
                isProcessing = true
            case .idle:
                isVoiceMode = false
                if let transcript = Optional(speechRecognizer.transcript), !transcript.isEmpty {
                    Task {
                        await handleAIInput(voiceInput: transcript)
                    }
                } else {
                    isProcessing = false
                }
            case .error:
                isVoiceMode = false
                isProcessing = false
            case .recording:
                isProcessing = false
            }
        }
        .task {
            // If the note has no tags and no suggestions, trigger once
            if note.tags.isEmpty && note.suggestedTags.isEmpty && !note.content.isEmpty {
                await generateTags()
            }
        }
        .onChange(of: note.content) { oldValue, newValue in
            // Trigger tag generation when content changes from empty to non-empty
            // This handles the case where user pastes text into an empty note
            if oldValue.isEmpty && !newValue.isEmpty && 
               note.tags.isEmpty && note.suggestedTags.isEmpty {
                Task {
                    await generateTags()
                }
            }
        }
    }
    
    private func generateTags() async {
        do {
            let fetchDescriptor = FetchDescriptor<Tag>()
            let allTags = (try? modelContext.fetch(fetchDescriptor))?.map { $0.name } ?? []
            
            let suggestions = try await TagService.shared.suggestTags(for: note.content, existingTags: allTags)
            
            if !suggestions.isEmpty {
                await MainActor.run {
                    withAnimation {
                        note.suggestedTags = suggestions
                    }
                    try? modelContext.save()
                }
            }
        } catch {
            print("⚠️ Failed to generate tags: \(error)")
        }
    }
    
    // MARK: - Voice Input Logic
    
    private func startRecording() {
        isVoiceMode = true
        recordingStartTime = Date()
        recordingDuration = 0
        speechRecognizer.transcript = "" // Reset
        speechRecognizer.startRecording()
    }
    
    private func stopRecording() {
        speechRecognizer.stopRecording()
    }
    
    private func timeString(from interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - AI Quick Actions
    
    private func executeAIAction(_ action: CustomAIAction) async {
        let contentToTransform: String = await MainActor.run {
            // Store original content for undo
            if !showAIToolbar {
                aiOriginalContent = note.content
            }

            currentAIAction = action
            isProcessing = true
            return note.content
        }
        
        do {
            let result = try await action.execute(on: contentToTransform)
            
            await MainActor.run {
                isProgrammaticContentUpdate = true
                note.content = result
                note.updatedAt = Date()
                try? modelContext.save()
                Task { await syncManager.syncIfNeeded(context: modelContext) }
                
                isProcessing = false
                withAnimation {
                    showAIToolbar = true
                }
                DispatchQueue.main.async {
                    isProgrammaticContentUpdate = false
                }
            }
        } catch {
            print("⚠️ AI action failed: \(error)")
            await MainActor.run {
                isProcessing = false
            }
        }
    }
    
    private func undoAIContent() {
        guard let aiOriginalContent else {
            dismissAIToolbar()
            return
        }
        withAnimation {
            isProgrammaticContentUpdate = true
            note.content = aiOriginalContent
            note.updatedAt = Date()
            try? modelContext.save()
            Task { await syncManager.syncIfNeeded(context: modelContext) }
            
            // Dismiss toolbar
            dismissAIToolbar()
            DispatchQueue.main.async {
                isProgrammaticContentUpdate = false
            }
        }
    }
    
    private func dismissAIToolbar() {
        withAnimation {
            showAIToolbar = false
            currentAIAction = nil
            aiOriginalContent = nil
        }
    }
    
    private func saveAIContentAndDismissToolbar() {
        // Persist the formatted content and close the toolbar
        note.updatedAt = Date()
        try? modelContext.save()
        Task { await syncManager.syncIfNeeded(context: modelContext) }
        
        dismissAIToolbar()
    }
    
    private func handleAIInput(voiceInput: String? = nil) async {
        let userInput = voiceInput ?? inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userInput.isEmpty else { return }
        
        // Clear input immediately for better UX
        inputText = ""
        isProcessing = true
        
        // Use AI to help edit or expand the note
        do {
            let languageRule = LanguageDetection.languagePreservationRule(for: note.content)
            let systemInstruction = """
            You are a professional writing assistant helping the user edit a note.
            Rules:
            \(languageRule)
            - Preserve the original structure and formatting (including markdown, code blocks, and line breaks) unless the user explicitly requests changes.
            - Return only the updated note content, without any explanations or meta-commentary.
            """

            let prompt = """
            The user is editing a note with the following content:
            
            \(note.content)
            
            The user wants to: \(userInput)
            
            Please update the note based on the user's request.
            """
            
            let response = try await GeminiService.shared.generateContent(
                prompt: prompt,
                systemInstruction: systemInstruction
            )
            
            // Update the note content with AI response
            await MainActor.run {
                isProgrammaticContentUpdate = true
                note.updateContent(response)
                note.syncContentStructure(with: modelContext)
                note.updatedAt = Date()
                isProcessing = false
                try? modelContext.save()
                Task { await syncManager.syncIfNeeded(context: modelContext) }
                DispatchQueue.main.async {
                    isProgrammaticContentUpdate = false
                }
            }
            
        } catch {
            print("⚠️ Failed to get AI assistance: \(error)")
            await MainActor.run {
                isProcessing = false
            }
        }
    }
    
    private func updateTimestampAndDismiss() {
        // Automatically delete if content is empty (referencing Apple Notes behavior)
        if note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            deleteNote()
            return
        }

        // Update the timestamp to track when the note was last modified
        note.updatedAt = Date()
        try? modelContext.save()
        TagService.shared.cleanupEmptyTags(context: modelContext)
        Task { await syncManager.syncIfNeeded(context: modelContext) }
        dismiss()
    }

    
    
    private func deleteNote() {
        guard note.deletedAt == nil else {
            dismiss()
            return
        }
        note.markDeleted()
        try? modelContext.save()
        TagService.shared.cleanupEmptyTags(context: modelContext)
        Task { await syncManager.syncIfNeeded(context: modelContext) }
        dismiss()
    }
    
    private func confirmTag(_ tagName: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            // Remove from suggestions
            note.suggestedTags.removeAll { $0 == tagName }
            
            // Find or create tag
            let fetchDescriptor = FetchDescriptor<Tag>()
            let allTags = (try? modelContext.fetch(fetchDescriptor)) ?? []
            let existing = allTags.first { $0.name.lowercased() == tagName.lowercased() }
            
            if let existing = existing {
                if !note.tags.contains(where: { $0.id == existing.id }) {
                    note.tags.append(existing)
                    existing.lastUsedAt = Date()
                }
            } else {
                let newTag = Tag(name: tagName)
                modelContext.insert(newTag)
                note.tags.append(newTag)
            }
            
            try? modelContext.save()
            Task { await syncManager.syncIfNeeded(context: modelContext) }
        }
    }
}

// MARK: - Tag UI Components

struct TagBannerView: View {
    let tags: [Tag]
    let suggestedTags: [String]
    let onConfirm: (String) -> Void
    let onRemove: (Tag) -> Void
    let onAddClick: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            
            FlowLayout(spacing: 8) {
                // Confirmed Tags
                ForEach(tags) { tag in
                    TagPill(title: tag.name, color: tag.color, isSuggested: false) {
                        onRemove(tag)
                    }
                }
                
                // Suggested Tags (Gray)
                ForEach(suggestedTags, id: \.self) { tagName in
                    TagPill(title: tagName, color: .gray, isSuggested: true) {
                        onConfirm(tagName)
                    }
                }
                
                // Add Button
                Button(action: onAddClick) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("Tag")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().stroke(Color.textSub.opacity(0.3), lineWidth: 1))
                    .foregroundColor(.textSub)
                }
            }
        }
    }
}

struct TagPill: View {
    let title: String
    let color: Color
    let isSuggested: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isSuggested {
                    Text("#")
                        .foregroundColor(color.opacity(0.4))
                }
                Text(title)
            }
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSuggested ? color.opacity(0.12) : color.opacity(0.15))
            )
            .foregroundColor(isSuggested ? .textSub : color)
            .overlay(
                Capsule()
                    .stroke(isSuggested ? color.opacity(0.2) : Color.clear, lineWidth: 1)
            )
        }
    }
}

// Simple FlowLayout for Tags
struct FlowLayout: Layout {
    var spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.replacingUnspecifiedDimensions().width
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        
        return CGSize(width: width, height: currentY + lineHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

#Preview {
    NoteDetailView(note: Note(content: "Hello"))
        .modelContainer(DataService.shared.container!)
        .environmentObject(SyncManager())
}
