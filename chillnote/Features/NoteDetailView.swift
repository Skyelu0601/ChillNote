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
    @State private var isProcessing = false
    @StateObject private var speechRecognizer = SpeechRecognizer()
    
    // AI Quick Actions
    @State private var showAIActionsSheet = false
    @State private var showAIToolbar = false
    @State private var currentAIAction: CustomAIAction?
    @State private var aiOriginalContent: String?
    @State private var isProgrammaticContentUpdate = false
    
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

                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(note.createdAt.relativeFormatted())
                            .font(.bodySmall)
                            .foregroundColor(.textSub)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)

                        // Rich Text Editor - renders markdown as formatted text
                        RichTextEditorView(
                            text: $note.content,
                            isEditable: !isProcessing,
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            
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
                note.content = response
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
        // Update the timestamp to track when the note was last modified
        note.updatedAt = Date()
        try? modelContext.save()
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
        Task { await syncManager.syncIfNeeded(context: modelContext) }
        dismiss()
    }
}

#Preview {
    NoteDetailView(note: Note(content: "Hello"))
        .modelContainer(DataService.shared.container!)
        .environmentObject(SyncManager())
}
