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
    @State private var showUpgradeSheet = false
    @State private var showSubscription = false
    
    var initialQuery: String? = nil // Optional initial query to auto-send
    var onAnswer: ((String) -> Void)? = nil

    
    // Voice input
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var isVoiceMode = false
    
    // Save note feedback
    @State private var savedMessageId: UUID?
    @EnvironmentObject private var syncManager: SyncManager
    
    private func openSubscriptionFromUpgrade() {
        showUpgradeSheet = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            showSubscription = true
        }
    }
    
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
                                    } : nil,
                                    onAnimationComplete: {
                                        if let index = messages.firstIndex(where: { $0.id == message.id }) {
                                            messages[index].isAnimated = true
                                        }
                                    }
                                )
                                .id(message.id)
                            }
                            
                            
                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .accentPrimary))
                                    Text("Chillo is climbing the tree of knowledge...")
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
                    HStack(alignment: .bottom, spacing: 12) {
                        // Text Input
                        TextField("Ask Chillo...", text: $userInput, axis: .vertical)
                            .font(.bodyMedium)
                            .foregroundColor(.textMain)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14) // Slightly taller for better touch target
                            .background(Color.bgSecondary)
                            .cornerRadius(24)
                            .lineLimit(1...5)
                            .focused($isInputFocused)
                            .submitLabel(.send)
                            .onSubmit {
                                sendMessage()
                            }
                        
                        // Primary Action Button (Voice or Send)
                        Button(action: {
                            if userInput.isEmpty {
                                startVoiceInput()
                            } else {
                                sendMessage()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentPrimary)
                                    .frame(width: 52, height: 52)
                                    .shadow(color: Color.accentPrimary.opacity(0.3), radius: 4, y: 2)
                                
                                Image(systemName: userInput.isEmpty ? "mic.fill" : "arrow.up")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white) // Always white for contrast on accent color
                                    .contentTransition(.symbolEffect(.replace))
                            }
                        }
                        .disabled(isLoading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
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
                
                // Mark recording as complete to clean up the file so it doesn't trigger "Unsaved Recording" checks
                speechRecognizer.completeRecording()
                
                sendMessage()
            }
        }
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradeBottomSheet(
                title: "Daily free limit reached",
                message: UpgradeBottomSheet.unifiedMessage,
                primaryButtonTitle: "Upgrade to Pro",
                onUpgrade: openSubscriptionFromUpgrade,
                onDismiss: { showUpgradeSheet = false }
            )
            .presentationDetents([.height(350)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
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
                Image("askchillo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                
                Text(contextNotes.isEmpty ? "Select some notes to start" : "What's on your mind?")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.textMain)
                
                Text(contextNotes.isEmpty ? "I'm ready to help once you pick some content." : "I've read through your notes. Let's see what we can create together.")
                    .font(.body)
                    .foregroundColor(.textSub)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            Spacer()
        }
    }
    
    func startVoiceInput() {
        guard !isLoading else { return }
        Task {
            let canRecord = await StoreService.shared.checkDailyQuotaOnServer(feature: .voice)
            await MainActor.run {
                guard canRecord else {
                    showUpgradeSheet = true
                    return
                }
                isVoiceMode = true
                isInputFocused = false
                speechRecognizer.startRecording(countsTowardQuota: true)
            }
        }
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
                
                // Add empty assistant message placeholder
                await MainActor.run {
                    let placeholder = ChatMessage(role: .assistant, content: "", isStreaming: true)
                    messages.append(placeholder)
                    isLoading = false // Start showing bubble immediately
                }
                
                let stream = GeminiService.shared.streamGenerateContent(
                    prompt: fullPrompt,
                    systemInstruction: """
                    You are Chillo, a friendly and calm Koala assistant. You are wise but laid-back. Your tone is soothing, concise, and helpful. You prefer a 'chill' vibe but deliver accurate information. Don't be overly formal.
                    
                    CRITICAL:
                    \(languageRule)
                    - Always prioritize the language of the User's question for your response, even if the notes are in a different language.
                    """,
                    usageType: .chat
                )
                
                for try await chunk in stream {
                    await MainActor.run {
                        if let lastIndex = messages.indices.last {
                            messages[lastIndex].content += chunk
                        }
                    }
                }
                
                // Mark as finished
                await MainActor.run {
                    if let lastIndex = messages.indices.last {
                        messages[lastIndex].isStreaming = false
                        messages[lastIndex].isAnimated = true // Skip typewriter effect since we streamed it
                        let finalAnswer = messages[lastIndex].content
                        if !finalAnswer.isEmpty {
                            onAnswer?(finalAnswer)
                        }
                    }
                }
                
            } catch {
                await MainActor.run {
                    // Remove the empty/partial message if it failed
                    if let last = messages.last, last.role == .assistant, last.isStreaming {
                        messages.removeLast()
                    }
                    isLoading = false
                    let message = error.localizedDescription
                    if message.localizedCaseInsensitiveContains("daily free ai chat limit reached") {
                        errorMessage = nil
                        showUpgradeSheet = true
                    } else {
                        errorMessage = "Chillo ran into an issue: \(message)"
                    }
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
        guard let userId = AuthService.shared.currentUserId else { return }
        let newNote = Note(content: message.content, userId: userId)
        modelContext.insert(newNote)
        
        try? modelContext.save()
        Task { await syncManager.syncNow(context: modelContext) }
        
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
    var content: String
    let timestamp = Date()
    
    enum Role {
        case user
        case assistant
    }
    
    // UI State
    var isAnimated: Bool = false
    var isStreaming: Bool = false
}

// MARK: - Chat Message Bubble
struct ChatMessageBubble: View {
    let message: ChatMessage
    var isLast: Bool = false
    var isSaved: Bool = false
    var onSave: (() -> Void)? = nil
    var onAnimationComplete: (() -> Void)? = nil
    
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
                            isStreaming: message.isStreaming,
                            shouldAnimate: isLast && !message.isAnimated && !message.isStreaming,
                            onAnimationComplete: onAnimationComplete
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
        Note(content: "Learned about SwiftUI state management today. The difference between @State and @Binding is important.", userId: "preview-user"),
        Note(content: "Completed the UI design for the project, using gradients and rounded cards.", userId: "preview-user")
    ])
    .modelContainer(DataService.shared.container!)
}
