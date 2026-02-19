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

    

    
    // Save note feedback
    @State private var savedMessageId: UUID?
    @EnvironmentObject private var syncManager: SyncManager
    
    private let recentHistoryLimit = 8
    private let summaryMessageLimit = 12
    private let summarySnippetLimit = 160
    
    private func openSubscriptionFromUpgrade() {
        showUpgradeSheet = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            showSubscription = true
        }
    }
    
    var body: some View {
        return NavigationStack {
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
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        chatInputBar
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    sendMessage()
                }
            } else {
                // 延迟弹出键盘，等 fullScreenCover 转场动画完成（约 0.4s）
                // 这样可以避免 "System gesture gate timed out" 警告和初始卡顿
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isInputFocused = true
                }
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
        ContextPreviewView(notes: contextNotes, isExpanded: $isContextExpanded)
    }

    // MARK: - Chat Input Bar (Text-only, floating, no background)
    var chatInputBar: some View {
        return HStack(alignment: .bottom, spacing: 10) {
            // Multi-line text field
            TextField("Ask Chillo...", text: $userInput, axis: .vertical)
                .font(.bodyMedium)
                .foregroundColor(.textMain)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color.bgSecondary)
                .cornerRadius(22)
                .lineLimit(1...5)
                .focused($isInputFocused)
                .submitLabel(.send)
                .onSubmit {
                    sendMessage()
                }

            // Send button — always visible, disabled when empty
            Button(action: sendMessage) {
                ZStack {
                    Circle()
                        .fill(userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              ? Color.textSub.opacity(0.2)
                              : Color.accentPrimary)
                        .frame(width: 36, height: 36)
                        .shadow(
                            color: userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? .clear
                                : Color.accentPrimary.opacity(0.35),
                            radius: 6, y: 3
                        )

                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(
                            userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.textSub.opacity(0.5)
                                : .white
                        )
                }
            }
            .disabled(userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: userInput.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color.bgPrimary.opacity(0.001)) // transparent but tappable
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
                let conversationHistory = buildConversationHistory(excludingLatestUserMessage: true)

                // Create prompt with context and history
                let fullPrompt = """
                You are an AI assistant with access to user notes as long-term memory.
                
                Follow these rules in order:
                1) Prioritize facts from User Notes whenever possible.
                2) If User Notes are insufficient, you may use general knowledge.
                3) Never present general knowledge or guesses as if they came from notes.
                4) The first line of your response must be exactly one of:
                   - Source: Notes (Note X, Note Y)
                   - Source: General Knowledge
                   - Source: Mixed (Note X + General Knowledge)
                5) Only when Source is "General Knowledge" or "Mixed", you may add one short line: Inference: ...
                   If Source is "Notes", do not include any "Inference:" line.
                6) Keep a natural conversational tone and support follow-up questions.
                
                Conversation Summary:
                \(conversationHistory.summary)
                
                Recent Conversation Turns:
                \(conversationHistory.recentTurns)
                
                User Notes:
                \(context)
                
                Current User Question:
                \(trimmed)
                
                If the notes do not contain relevant facts, answer helpfully with general knowledge and label it correctly.
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
                    - Always prioritize the language of the User's question for your response, even if notes are in another language.
                    - Act as a proactive partner. If the user's notes are brief, feel free to ask follow-up questions or offer creative suggestions.
                    - The first line of every answer must be one Source label in the exact required format.
                    - Do not output any "Inference:" line when Source is "Notes".
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
    
    func buildConversationHistory(excludingLatestUserMessage: Bool) -> (summary: String, recentTurns: String) {
        var history = messages
        if excludingLatestUserMessage, let last = history.last, last.role == .user {
            history.removeLast()
        }
        
        if history.isEmpty {
            return (
                summary: "No prior conversation yet.",
                recentTurns: "No recent turns."
            )
        }
        
        let recent = Array(history.suffix(recentHistoryLimit))
        let older = Array(history.dropLast(min(recentHistoryLimit, history.count)).suffix(summaryMessageLimit))
        
        let summary: String = older.isEmpty ? "No older turns to summarize." : older.map { message in
            let role = message.role == .user ? "User" : "Assistant"
            let snippet = summarizeSnippet(message.content, limit: summarySnippetLimit)
            return "- \(role): \(snippet)"
        }.joined(separator: "\n")
        
        let recentTurns = recent.map { message in
            let role = message.role == .user ? "User" : "Assistant"
            return "\(role): \(message.content)"
        }.joined(separator: "\n\n")
        
        return (summary: summary, recentTurns: recentTurns)
    }
    
    func summarizeSnippet(_ text: String, limit: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit)) + "..."
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
                    // Use typewriter markdown rendering for AI responses.
                    if message.role == .assistant {
                        TypewriterMarkdownText(
                            content: message.content,
                            isStreaming: message.isStreaming,
                            shouldAnimate: isLast && !message.isAnimated && !message.isStreaming,
                            onAnimationComplete: onAnimationComplete
                        )
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

// MARK: - Context Preview (Equatable to skip re-renders when userInput changes)
private struct ContextPreviewView: View, Equatable {
    let notes: [Note]
    @Binding var isExpanded: Bool

    static func == (lhs: ContextPreviewView, rhs: ContextPreviewView) -> Bool {
        // Only re-render when the note list changes (count or IDs)
        lhs.notes.map(\.id) == rhs.notes.map(\.id)
        && lhs.isExpanded == rhs.isExpanded
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.accentPrimary)
                        .font(.system(size: 14))
                    
                    Text("\(notes.count) Context Notes")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.textMain)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.textSub)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.bgSecondary.opacity(0.5))
            }
            
            if isExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(notes) { note in
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
        .clipShape(RoundedRectangle(cornerRadius: 0))
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
    }
}

#Preview {
    AIContextChatView(contextNotes: [
        Note(content: "Learned about SwiftUI state management today. The difference between @State and @Binding is important.", userId: "preview-user"),
        Note(content: "Completed the UI design for the project, using gradients and rounded cards.", userId: "preview-user")
    ])
    .modelContainer(DataService.shared.container!)
}
