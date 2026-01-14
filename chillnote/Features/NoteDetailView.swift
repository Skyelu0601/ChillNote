import SwiftUI
import SwiftData

struct NoteDetailView: View {
    @Bindable var note: Note
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var syncManager: SyncManager
    
    @State private var showDeleteConfirmation = false
    @State private var inputText = ""
    @State private var isVoiceMode = false
    @State private var isProcessing = false
    @StateObject private var speechRecognizer = SpeechRecognizer()

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Button(action: { 
                        updateTimestampAndDismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.textMain)
                            .padding(8)
                    }
                    .accessibilityLabel("Back")
                    
                    if isProcessing {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("AI Thinking...")
                                .font(.caption)
                                .foregroundColor(.textSub)
                        }
                        .padding(.leading, 8)
                    }
                    
                    Spacer()
                    
                    // Delete button
                    Button(action: { showDeleteConfirmation = true }) {
                        Image(systemName: "trash")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.red)
                            .padding(8)
                    }
                    .accessibilityLabel("Delete note")
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                Text(note.createdAt.relativeFormatted())
                    .font(.bodySmall)
                    .foregroundColor(.textSub)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                // Text Editor
                TextEditor(text: $note.content)
                    .font(.bodyLarge)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .disabled(isProcessing) // Disable editing while AI is working
                    .opacity(isProcessing ? 0.6 : 1.0)
                
                // AI Input Bar at bottom
                ChatInputBar(
                    text: $inputText,
                    isVoiceMode: $isVoiceMode,
                    speechRecognizer: speechRecognizer,
                    onSendText: {
                        Task { await handleAIInput() }
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
        .navigationBarHidden(true)
        .alert("Delete Note", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteNote()
            }
        } message: {
            Text("Are you sure you want to delete this note? This action cannot be undone.")
        }
        .onChange(of: speechRecognizer.transcript) { _, newValue in
            if !newValue.isEmpty {
                let voiceInput = newValue
                speechRecognizer.transcript = ""
                Task {
                    await handleAIInput(voiceInput: voiceInput)
                }
            }
        }
    }
    
    private func handleAIInput(voiceInput: String? = nil) async {
        let userInput = voiceInput ?? inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userInput.isEmpty else { return }
        
        // Clear input immediately for better UX
        inputText = ""
        isProcessing = true
        
        // Use AI to help edit or expand the note
        do {
            let prompt = """
            The user is editing a note with the following content:
            
            \(note.content)
            
            The user wants to: \(userInput)
            
            Please provide an improved or expanded version of the note based on the user's request. Return only the updated note content, without any explanations or meta-commentary.
            """
            
            let response = try await GeminiService.shared.chat(prompt: prompt)
            
            // Update the note content with AI response
            await MainActor.run {
                note.content = response
                note.updatedAt = Date()
                isProcessing = false
                try? modelContext.save()
                Task { await syncManager.syncIfNeeded(context: modelContext) }
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
        modelContext.delete(note)
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
