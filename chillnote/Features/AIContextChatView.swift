import SwiftUI
import SwiftData

struct AIContextChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let contextNotes: [Note]
    
    @State private var userInput = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var isInputFocused: Bool
    
    // Voice input
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var isVoiceMode = false
    
    // Save note feedback
    @State private var savedMessageId: UUID?
    @EnvironmentObject private var syncManager: SyncManager
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Context Preview Section
                contextPreviewSection
                
                Divider()
                    .background(Color.textSub.opacity(0.2))
                
                // Chat Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(messages) { message in
                                ChatMessageBubble(
                                    message: message,
                                    isSaved: savedMessageId == message.id,
                                    onSave: message.role == .assistant ? {
                                        saveMessageAsNote(message)
                                    } : nil
                                )
                                .id(message.id)
                            }
                            
                            
                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .accentPrimary))
                                    Text("Chillo is thinking...")
                                        .font(.bodyMedium)
                                        .foregroundColor(.textSub)
                                }
                                .padding()
                            }
                        }
                        .padding(16)
                    }
                    .background(Color.bgPrimary)
                    .onChange(of: messages.count) { _, _ in
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Error Display
                if let error = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                        Spacer()
                        Button("Dismiss") {
                            errorMessage = nil
                        }
                        .font(.caption)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                }
                
                // Input Bar
                if isVoiceMode {
                    VoiceInputBar(
                        speechRecognizer: speechRecognizer,
                        onCancel: {
                            speechRecognizer.stopRecording(reason: .cancelled)
                            isVoiceMode = false
                        },
                        onConfirm: {
                            speechRecognizer.stopRecording()
                            isVoiceMode = false
                        }
                    )
                } else {
                    HStack(spacing: 12) {
                        TextField("Ask Chillo about these notes...", text: $userInput, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.bodyMedium)
                            .foregroundColor(.textMain)
                            .padding(12)
                            .background(Color.bgSecondary)
                            .cornerRadius(20)
                            .lineLimit(1...5)
                            .focused($isInputFocused)
                        
                        // Voice button
                        Button(action: startVoiceInput) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.accentPrimary)
                                .frame(width: 40, height: 40)
                                .background(Color.accentPrimary.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .disabled(isLoading)
                        
                        Button(action: sendMessage) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(userInput.isEmpty ? .textSub : .accentPrimary)
                        }
                        .disabled(userInput.isEmpty || isLoading)
                    }
                    .padding(16)
                    .background(Color.white)
                }
            }
            .navigationTitle("Chillo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: clearChat) {
                        Image(systemName: "trash")
                            .foregroundColor(.textSub)
                    }
                    .disabled(messages.isEmpty)
                }
            }
        }
        .onAppear {
            isInputFocused = true
        }
        .onChange(of: speechRecognizer.transcript) { _, newValue in
            if !newValue.isEmpty {
                userInput = newValue
                speechRecognizer.transcript = ""
                sendMessage()
            }
        }
    }
    
    private var contextPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.accentPrimary)
                Text("Context Notes (\(contextNotes.count))")
                    .font(.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(.textMain)
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(contextNotes) { note in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.displayText)
                                .font(.caption)
                                .foregroundColor(.textMain)
                                .lineLimit(2)
                            Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 10))
                                .foregroundColor(.textSub)
                        }
                        .padding(8)
                        .frame(width: 150)
                        .background(Color.bgSecondary)
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
    }
    
    private func startVoiceInput() {
        guard !isLoading else { return }
        isVoiceMode = true
        isInputFocused = false
        speechRecognizer.startRecording()
    }
    
    private func sendMessage() {
        let trimmed = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Add user message
        let userMessage = ChatMessage(role: .user, content: trimmed)
        messages.append(userMessage)
        userInput = ""
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Build context from notes
                let context = buildContext()
                
                // Create prompt with context
                let fullPrompt = """
                You are an intelligent assistant helping users understand and analyze their notes.
                
                User's notes:
                \(context)
                
                User's question: \(trimmed)
                
                Please answer the user's question based on the notes above. If the notes don't contain relevant information, please tell the user honestly.
                """
                
                let response = try await GeminiService.shared.generateContent(
                    prompt: fullPrompt,
                    systemInstruction: "You are a professional note-taking assistant, skilled at analyzing and summarizing note content. Keep your answers concise, accurate, and helpful."
                )
                
                await MainActor.run {
                    let aiMessage = ChatMessage(role: .assistant, content: response)
                    messages.append(aiMessage)
                    isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "AI response failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func buildContext() -> String {
        contextNotes.enumerated().map { index, note in
            """
            [Note \(index + 1)]
            Created: \(note.createdAt.formatted(date: .long, time: .shortened))
            Content: \(note.content)
            """
        }.joined(separator: "\n\n")
    }
    
    private func saveMessageAsNote(_ message: ChatMessage) {
        let newNote = Note(content: message.content)
        modelContext.insert(newNote)
        

        
        try? modelContext.save()
        Task { await syncManager.syncIfNeeded(context: modelContext) }
        
        // Show feedback
        withAnimation {
            savedMessageId = message.id
        }
        
        // Reset feedback after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                savedMessageId = nil
            }
        }
    }
    
    private func clearChat() {
        messages.removeAll()
        errorMessage = nil
    }
}

// MARK: - Chat Message Model
struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp = Date()
    
    enum Role {
        case user
        case assistant
    }
}

// MARK: - Chat Message Bubble
struct ChatMessageBubble: View {
    let message: ChatMessage
    var isSaved: Bool = false
    var onSave: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                // Message content
                VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                    // Use MarkdownText for AI responses to properly render markdown
                    if message.role == .assistant {
                        MarkdownText(message.content)
                            .font(.bodyMedium)
                            .foregroundColor(.textMain)
                            .padding(12)
                            .background(Color.bgSecondary)
                            .cornerRadius(16)
                    } else {
                        Text(message.content)
                            .font(.bodyMedium)
                            .foregroundColor(.textMain)
                            .padding(12)
                            .background(Color.mellowYellow)
                            .cornerRadius(16)
                    }
                    
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10))
                        .foregroundColor(.textSub)
                }
                
                // Save button for AI responses
                if message.role == .assistant, let onSave = onSave {
                    Button(action: onSave) {
                        HStack(spacing: 6) {
                            Image(systemName: isSaved ? "checkmark.circle.fill" : "square.and.arrow.down")
                                .font(.system(size: 14))
                            Text(isSaved ? "Saved!" : "Save as Note")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(isSaved ? .green : .accentPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isSaved ? Color.green.opacity(0.1) : Color.accentPrimary.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .disabled(isSaved)
                }
            }
            .frame(maxWidth: 280, alignment: message.role == .user ? .trailing : .leading)
            
            if message.role == .assistant {
                Spacer()
            }
        }
    }
}

#Preview {
    AIContextChatView(contextNotes: [
        Note(content: "Learned about SwiftUI state management today. The difference between @State and @Binding is important."),
        Note(content: "Completed the UI design for the project, using gradients and rounded cards.")
    ])
    .modelContainer(DataService.shared.container!)
}
