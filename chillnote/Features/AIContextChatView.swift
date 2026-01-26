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
    @State private var isContextExpanded = false // Collapsible context state
    
    var initialQuery: String? = nil // Optional initial query to auto-send

    
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
                                    isLast: message.id == messages.last?.id,
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
                        .padding(.top, 40) // Spacing for empty state
                        
                        // Empty State
                        if messages.isEmpty {
                            emptyStateView
                        }
                    }
                    .background(Color.bgPrimary)
                    .onTapGesture {
                        isInputFocused = false
                    }
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
                    .transition(.move(edge: .bottom))
                } else {
                    HStack(spacing: 12) {
                        // Voice button
                        Button(action: startVoiceInput) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.textSub)
                                .frame(width: 36, height: 36)
                                .background(Color.bgSecondary)
                                .clipShape(Circle())
                        }
                        .disabled(isLoading)
                        
                        TextField("Ask Chillo...", text: $userInput, axis: .vertical)
                            .font(.bodyMedium)
                            .foregroundColor(.textMain)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.bgSecondary)
                            .cornerRadius(24)
                            .lineLimit(1...5)
                            .focused($isInputFocused)
                            .submitLabel(.send)
                            .onSubmit {
                                sendMessage()
                            }
                        
                        if !userInput.isEmpty {
                            Button(action: sendMessage) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.accentPrimary)
                                    .symbolEffect(.bounce, value: userInput)
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 0))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, y: -4)
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
        .onAppear {
            if let initial = initialQuery {
                userInput = initial
                // Small delay to allow view to appear before sending
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    sendMessage()
                }
            } else {
                isInputFocused = true
            }
        }
        .onChange(of: speechRecognizer.transcript) { _, newValue in
            if !newValue.isEmpty {
                userInput = newValue
                speechRecognizer.transcript = ""
                sendMessage()
            }
        }
    }
}
    
    var contextPreviewSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.spring(response: 0.3)) { isContextExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.accentPrimary)
                        .font(.system(size: 14))
                    
                    Text("\(contextNotes.count) Context Notes")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.textMain)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.textSub)
                        .rotationEffect(.degrees(isContextExpanded ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.bgSecondary.opacity(0.5))
            }
            
            if isContextExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(contextNotes) { note in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(note.displayText)
                                    .font(.caption)
                                    .foregroundColor(.textMain)
                                    .lineLimit(3)
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                
                                Spacer()
                                
                                Text(note.createdAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.system(size: 9))
                                    .foregroundColor(.textSub)
                            }
                            .padding(10)
                            .frame(width: 140, height: 100)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color.bgPrimary.opacity(0.5))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: isContextExpanded ? 0 : 0))
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
    }
    
    var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundStyle(LinearGradient(colors: [.accentPrimary, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .symbolEffect(.bounce, options: .repeating)
                
                Text(contextNotes.isEmpty ? "Select some notes to start" : "Ready to brainstorm?")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.textMain)
                
                Text("Ask me to summarize, find connections, or draft new content based on your selected notes.")
                    .font(.body)
                    .foregroundColor(.textSub)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Suggested Questions
            if !contextNotes.isEmpty {
                VStack(spacing: 10) {
                    Text("SUGGESTED")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.textSub)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 32)
                    
                    ForEach(["Summarize these notes", "What are the key takeaways?", "Draft a blog post from this"], id: \.self) { question in
                        Button(action: {
                            userInput = question
                            sendMessage()
                        }) {
                            Text(question)
                                .font(.subheadline)
                                .foregroundColor(.textMain)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.03), radius: 2, y: 1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.accentPrimary.opacity(0.1), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
            
            Spacer()
            Spacer()
        }
    }
    
    func startVoiceInput() {
        guard !isLoading else { return }
        isVoiceMode = true
        isInputFocused = false
        speechRecognizer.startRecording()
    }
    
    func sendMessage() {
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
                
                let languageRule = LanguageDetection.languagePreservationRule(for: trimmed)
                
                let response = try await GeminiService.shared.generateContent(
                    prompt: fullPrompt,
                    systemInstruction: """
                    You are a professional note-taking assistant, skilled at analyzing and summarizing note content. Keep your answers concise, accurate, and helpful.
                    
                    CRITICAL:
                    \(languageRule)
                    - Always prioritize the language of the User's question for your response, even if the notes are in a different language.
                    """
                )
                
                await MainActor.run {
                    let aiMessage = ChatMessage(role: .assistant, content: response)
                    messages.append(aiMessage)
                    isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Chillo ran into an issue: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func buildContext() -> String {
        contextNotes.enumerated().map { index, note in
            """
            [Note \(index + 1)]
            Created: \(note.createdAt.formatted(date: .long, time: .shortened))
            Content: \(note.content)
            """
        }.joined(separator: "\n\n")
    }
    
    func saveMessageAsNote(_ message: ChatMessage) {
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
    
    func clearChat() {
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
    var isLast: Bool = false
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
                        TypewriterMarkdownText(
                            content: message.content,
                            isNew: isLast
                        )
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
            .frame(maxWidth: message.role == .assistant ? .infinity : 280, alignment: message.role == .user ? .trailing : .leading)
            

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
