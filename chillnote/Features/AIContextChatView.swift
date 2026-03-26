import SwiftUI
import SwiftData

private func sanitizeAssistantContent(_ text: String) -> String {
    let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
    var lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

    while let first = lines.first {
        let trimmed = first.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("source:") {
            lines.removeFirst()
            continue
        }
        break
    }

    return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
}

enum ChatInlineSegment: Equatable {
    case text(String)
    case citation(MessageCitation)
}

struct MessageCitation: Equatable, Hashable {
    let number: Int
    let noteID: UUID
    let noteIndex: Int
}

struct SlashCommandMatch: Equatable {
    let range: Range<String.Index>
    let query: String
    let matchedRecipes: [AgentRecipe]
}

enum AIChatMode {
    case defaultChat
    case recipeCommand(recipe: AgentRecipe, extraInstruction: String?)
}

struct ChatContentParser {
    private static let citationPattern = #"\[(\d+)\]"#

    static func parseAssistantSegments(_ text: String, contextNotes: [Note]) -> [ChatInlineSegment] {
        guard !text.isEmpty else { return [] }
        guard let regex = try? NSRegularExpression(pattern: citationPattern) else {
            return [.text(text)]
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else { return [.text(text)] }

        var segments: [ChatInlineSegment] = []
        var currentLocation = 0

        for match in matches {
            let matchRange = match.range
            if matchRange.location > currentLocation {
                let prefix = nsText.substring(with: NSRange(location: currentLocation, length: matchRange.location - currentLocation))
                if !prefix.isEmpty {
                    segments.append(.text(prefix))
                }
            }

            if match.numberOfRanges > 1,
               let numberRange = Range(match.range(at: 1), in: text),
               let number = Int(text[numberRange]),
               let note = contextNotes[safe: number - 1] {
                segments.append(.citation(MessageCitation(number: number, noteID: note.id, noteIndex: number - 1)))
            } else {
                segments.append(.text(nsText.substring(with: matchRange)))
            }

            currentLocation = matchRange.location + matchRange.length
        }

        if currentLocation < nsText.length {
            let suffix = nsText.substring(from: currentLocation)
            if !suffix.isEmpty {
                segments.append(.text(suffix))
            }
        }

        return mergeAdjacentTextSegments(segments)
    }

    static func detectSlashCommand(in input: String, recipes: [AgentRecipe]) -> SlashCommandMatch? {
        guard let tokenRange = slashTokenRange(in: input) else { return nil }
        let token = String(input[tokenRange])
        guard token.hasPrefix("/") else { return nil }

        let query = String(token.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedQuery = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        let matches = recipes.filter { recipe in
            guard !query.isEmpty else { return true }
            let id = recipe.id.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let name = recipe.localizedName.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            return id.contains(normalizedQuery) || name.contains(normalizedQuery)
        }

        return SlashCommandMatch(range: tokenRange, query: query, matchedRecipes: matches)
    }

    static func parseChatMode(for input: String, recipes: [AgentRecipe]) -> AIChatMode {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return .defaultChat }

        let body = String(trimmed.dropFirst())
        let command = body.split(maxSplits: 1, omittingEmptySubsequences: true, whereSeparator: \.isWhitespace)
        guard let rawID = command.first else { return .defaultChat }
        guard let recipe = recipes.first(where: { $0.id == rawID }) else { return .defaultChat }

        let extraInstruction: String?
        if command.count > 1 {
            let trailing = String(command[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            extraInstruction = trailing.isEmpty ? nil : trailing
        } else {
            extraInstruction = nil
        }

        return .recipeCommand(recipe: recipe, extraInstruction: extraInstruction)
    }

    private static func slashTokenRange(in input: String) -> Range<String.Index>? {
        guard !input.isEmpty else { return nil }
        let cursor = input.endIndex
        let prefix = input[..<cursor]
        let slashIndex = prefix.lastIndex(of: "/")
        guard let slashIndex else { return nil }

        if slashIndex > input.startIndex {
            let previous = input[input.index(before: slashIndex)]
            if !previous.isWhitespace && previous != "\n" {
                return nil
            }
        }

        let token = input[slashIndex..<cursor]
        if token.contains(where: \.isNewline) || token.contains(where: \.isWhitespace) {
            return nil
        }

        return slashIndex..<cursor
    }

    private static func mergeAdjacentTextSegments(_ segments: [ChatInlineSegment]) -> [ChatInlineSegment] {
        var merged: [ChatInlineSegment] = []
        for segment in segments {
            switch segment {
            case .text(let text):
                if case .text(let previous)? = merged.last {
                    merged[merged.count - 1] = .text(previous + text)
                } else {
                    merged.append(.text(text))
                }
            case .citation:
                merged.append(segment)
            }
        }
        return merged
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

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
    @State private var activePaywallContext: PaywallContext?
    @State private var showSubscription = false
    @StateObject private var recipeManager = RecipeManager.shared
    @State private var highlightedContextNoteID: UUID?
    @State private var highlightResetTask: Task<Void, Never>?
    @State private var slashCommandMatch: SlashCommandMatch?
    
    var initialQuery: String? = nil // Optional initial query to auto-send
    var onAnswer: ((String) -> Void)? = nil

    

    
    // Save note feedback
    @State private var savedMessageId: UUID?
    @EnvironmentObject private var syncManager: SyncManager
    
    private let recentHistoryLimit = 8
    private let summaryMessageLimit = 12
    private let summarySnippetLimit = 160
    
    private func openSubscriptionFromUpgrade() {
        activePaywallContext = nil
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
                    ZStack {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(messages) { message in
                                    ChatMessageBubble(
                                        message: message,
                                        contextNotes: contextNotes,
                                        isLast: message.id == messages.last?.id,
                                        isSaved: savedMessageId == message.id,
                                        onSave: message.role == .assistant ? {
                                            saveMessageAsNote(message)
                                        } : nil,
                                        onAnimationComplete: {
                                            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                                                messages[index].isAnimated = true
                                            }
                                        },
                                        onCitationTap: handleCitationTap
                                    )
                                    .id(message.id)
                                }
                            }
                            .padding(16)
                            .padding(.top, messages.isEmpty ? 0 : 40)
                        }
                        
                        if messages.isEmpty {
                            emptyStateView
                                .allowsHitTesting(false)
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
                        Button(L10n.text("ai_chat.error.dismiss")) {
                            errorMessage = nil
                        }
                        .font(.caption)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                }
                
            }
            .navigationTitle(L10n.text("ai_chat.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.text("common.close")) {
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
        .onDisappear {
            highlightResetTask?.cancel()
        }
        .sheet(item: $activePaywallContext) { context in
            UpgradeBottomSheet(
                content: context.content,
                onUpgrade: openSubscriptionFromUpgrade,
                onDismiss: { activePaywallContext = nil }
            )
            .presentationDetents([.height(context.content.preferredSheetHeight), .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
    }
}
    
    var contextPreviewSection: some View {
        ContextPreviewView(
            notes: contextNotes,
            isExpanded: $isContextExpanded,
            highlightedNoteID: highlightedContextNoteID
        )
    }

    // MARK: - Chat Input Bar (Text-only, floating, no background)
    var chatInputBar: some View {
        return VStack(alignment: .leading, spacing: 8) {
            if isInputFocused, let match = slashCommandMatch {
                SlashSkillsPanel(
                    recipes: match.matchedRecipes,
                    isEmptyLibrary: recipeManager.savedRecipes.isEmpty,
                    onSelect: applySlashRecipe
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(alignment: .bottom, spacing: 10) {
                // Multi-line text field
                TextField(L10n.text("ai_chat.input_placeholder"), text: $userInput, axis: .vertical)
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
                    .onChange(of: userInput) { _, newValue in
                        updateSlashCommandMatch(for: newValue)
                    }
                    .onChange(of: isInputFocused) { _, focused in
                        if focused {
                            updateSlashCommandMatch(for: userInput)
                        } else {
                            slashCommandMatch = nil
                        }
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
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color.bgPrimary.opacity(0.001)) // transparent but tappable
    }

    var emptyStateView: some View {
        VStack(spacing: 12) {
            Text(contextNotes.isEmpty ? L10n.text("ai_chat.empty.no_notes_title") : L10n.text("ai_chat.empty.ready_title"))
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.textMain)
                .multilineTextAlignment(.center)
            
            Text(contextNotes.isEmpty ? L10n.text("ai_chat.empty.no_notes_message") : L10n.text("ai_chat.empty.ready_message"))
                .font(.body)
                .foregroundColor(.textSub)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    
    
    func sendMessage() {
        let trimmed = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let chatMode = ChatContentParser.parseChatMode(for: trimmed, recipes: recipeManager.savedRecipes)
        
        // Add user message
        let userMessage = ChatMessage(role: .user, content: trimmed)
        messages.append(userMessage)
        let placeholder = ChatMessage(role: .assistant, content: "", isStreaming: true)
        messages.append(placeholder)
        userInput = ""
        isLoading = true
        errorMessage = nil
        slashCommandMatch = nil
        
        Task {
            do {
                // Build context from notes
                let context = buildContext()
                let conversationHistory = buildConversationHistory(excludingLatestUserMessage: true)
                let fullPrompt = makePrompt(for: chatMode, context: context, conversationHistory: conversationHistory, userMessage: trimmed)
                
                let languageRule = LanguageDetection.languagePreservationRule(for: trimmed)
                let systemInstruction = makeSystemInstruction(for: chatMode, languageRule: languageRule)
                
                let stream = GeminiService.shared.streamGenerateContent(
                    prompt: fullPrompt,
                    systemInstruction: systemInstruction,
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
                        let finalAnswer = sanitizeAssistantContent(messages[lastIndex].content)
                        messages[lastIndex].content = finalAnswer
                        if !finalAnswer.isEmpty {
                            onAnswer?(finalAnswer)
                        }
                    }
                    isLoading = false
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
                        activePaywallContext = .dailyChatLimit
                    } else {
                        errorMessage = String(
                            format: L10n.text("ai_chat.error.issue_format"),
                            message
                        )
                    }
                }
            }
        }
    }
    
    func buildContext() -> String {
        contextNotes.enumerated().map { index, note in
            """
            Note [\(index + 1)]
            Created: \(note.createdAt.formatted(date: .long, time: .shortened))
            Content: \(note.content)
            """
        }.joined(separator: "\n\n")
    }

    func makePrompt(
        for mode: AIChatMode,
        context: String,
        conversationHistory: (summary: String, recentTurns: String),
        userMessage: String
    ) -> String {
        switch mode {
        case .defaultChat:
            return """
            You are an AI assistant with access to user notes as long-term memory.

            Follow these rules in order:
            1) Prioritize facts from User Notes whenever possible.
            2) Use citations only when you are directly relying on a specific note. Citations must use the exact note numbers from User Notes, formatted as [1] or [1][3].
            3) If User Notes are insufficient, you may use general knowledge, but do not add citations for general knowledge.
            4) If a key fact is missing from the notes, ask one short follow-up question instead of guessing.
            5) Never invent a citation number that does not exist in User Notes.

            Conversation Summary:
            \(conversationHistory.summary)

            Recent Conversation Turns:
            \(conversationHistory.recentTurns)

            User Notes:
            \(context)

            Current User Question:
            \(userMessage)
            """
        case .recipeCommand(let recipe, let extraInstruction):
            let extra = extraInstruction?.isEmpty == false ? extraInstruction! : "No extra instruction."
            return """
            You are helping the user apply a saved Chill Skill inside chat.

            Selected Skill:
            ID: \(recipe.id)
            Name: \(recipe.localizedName)
            Skill Instruction:
            \(recipe.localizedPrompt)

            Extra User Instruction:
            \(extra)

            Conversation Summary:
            \(conversationHistory.summary)

            Recent Conversation Turns:
            \(conversationHistory.recentTurns)

            User Notes:
            \(context)

            Return only the final answer for the user. Do not repeat the slash command itself.
            If you directly rely on a specific note, cite it as [1] or [1][3] using only valid note numbers.
            """
        }
    }

    func makeSystemInstruction(for mode: AIChatMode, languageRule: String) -> String {
        switch mode {
        case .defaultChat:
            return """
            You are a helpful AI assistant.

            CRITICAL:
            \(languageRule)
            - Always prioritize the language of the User's question for your response, even if notes are in another language.
            - Be clear, direct, and accurate.
            - Only append citations like [1] when a sentence is directly supported by that note.
            - Do not cite general knowledge or guesses.
            """
        case .recipeCommand:
            return """
            You are a helpful AI assistant executing a saved writing skill inside chat.

            CRITICAL:
            \(languageRule)
            - Follow the selected skill faithfully.
            - Do not echo slash commands like /summarize in the answer.
            - Only append citations like [1] when the output directly uses a specific note.
            - Return only the answer body, with no meta commentary.
            """
        }
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
            let content = message.role == .assistant ? sanitizeAssistantContent(message.content) : message.content
            let snippet = summarizeSnippet(content, limit: summarySnippetLimit)
            return "- \(role): \(snippet)"
        }.joined(separator: "\n")
        
        let recentTurns = recent.map { message in
            let role = message.role == .user ? "User" : "Assistant"
            let content = message.role == .assistant ? sanitizeAssistantContent(message.content) : message.content
            return "\(role): \(content)"
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
        let content = message.role == .assistant ? sanitizeAssistantContent(message.content) : message.content
        let newNote = Note(content: content, userId: userId)
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
        highlightedContextNoteID = nil
        slashCommandMatch = nil
    }

    func updateSlashCommandMatch(for input: String) {
        guard isInputFocused else {
            slashCommandMatch = nil
            return
        }
        let match = ChatContentParser.detectSlashCommand(in: input, recipes: recipeManager.savedRecipes)
        if let match, !match.query.isEmpty, match.matchedRecipes.isEmpty {
            slashCommandMatch = nil
            return
        }
        slashCommandMatch = match
    }

    func applySlashRecipe(_ recipe: AgentRecipe) {
        guard let match = slashCommandMatch else { return }
        userInput.replaceSubrange(match.range, with: "/\(recipe.id) ")
        slashCommandMatch = nil
    }

    func handleCitationTap(_ citation: MessageCitation) {
        guard contextNotes.indices.contains(citation.noteIndex) else { return }
        highlightResetTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isContextExpanded = true
            highlightedContextNoteID = citation.noteID
        }
        highlightResetTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) {
                    highlightedContextNoteID = nil
                }
            }
        }
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

    func parsedSegments(for contextNotes: [Note]) -> [ChatInlineSegment] {
        guard role == .assistant, !isStreaming else { return [.text(content)] }
        return ChatContentParser.parseAssistantSegments(sanitizeAssistantContent(content), contextNotes: contextNotes)
    }
}

// MARK: - Chat Message Bubble
struct ChatMessageBubble: View {
    let message: ChatMessage
    let contextNotes: [Note]
    var isLast: Bool = false
    var isSaved: Bool = false
    var onSave: (() -> Void)? = nil
    var onAnimationComplete: (() -> Void)? = nil
    var onCitationTap: ((MessageCitation) -> Void)? = nil
    
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
                        if message.isStreaming && sanitizeAssistantContent(message.content).isEmpty {
                            ThinkingBubble()
                        } else {
                            if message.isStreaming || !(isLast && !message.isAnimated && !message.isStreaming) {
                                InteractiveAssistantText(
                                    segments: message.parsedSegments(for: contextNotes),
                                    onCitationTap: onCitationTap
                                )
                                .padding(12)
                                .background(Color.bgSecondary)
                                .cornerRadius(16)
                            } else {
                                TypewriterMarkdownText(
                                    content: sanitizeAssistantContent(message.content),
                                    isStreaming: message.isStreaming,
                                    shouldAnimate: isLast && !message.isAnimated && !message.isStreaming,
                                    onAnimationComplete: onAnimationComplete
                                )
                                .padding(12)
                                .background(Color.bgSecondary)
                                .cornerRadius(16)
                            }
                        }
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
                if message.role == .assistant, !message.isStreaming, let onSave = onSave {
                    Button(action: onSave) {
                        HStack(spacing: 6) {
                            Image(systemName: isSaved ? "checkmark.circle.fill" : "square.and.arrow.down")
                                .font(.system(size: 14))
                            Text(isSaved ? L10n.text("ai_chat.message.saved") : L10n.text("ai_chat.message.save_as_note"))
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

private struct ThinkingBubble: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.accentPrimary)

            Text(L10n.text("ai_chat.thinking"))
                .font(.bodyMedium)
                .foregroundColor(.textMain)

            ThinkingDots()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ThinkingDots: View {
    var body: some View {
        TimelineView(.animation) { context in
            let phase = Int(context.date.timeIntervalSinceReferenceDate * 2.4) % 3

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(index <= phase ? Color.accentPrimary : Color.textSub.opacity(0.25))
                        .frame(width: 6, height: 6)
                        .scaleEffect(index == phase ? 1.15 : 0.9)
                        .animation(.easeInOut(duration: 0.18), value: phase)
                }
            }
        }
        .frame(width: 28, height: 10)
    }
}

// MARK: - Context Preview (Equatable to skip re-renders when userInput changes)
private struct ContextPreviewView: View, Equatable {
    let notes: [Note]
    @Binding var isExpanded: Bool
    let highlightedNoteID: UUID?

    static func == (lhs: ContextPreviewView, rhs: ContextPreviewView) -> Bool {
        // Only re-render when the note list changes (count or IDs)
        lhs.notes.map(\.id) == rhs.notes.map(\.id)
        && lhs.isExpanded == rhs.isExpanded
        && lhs.highlightedNoteID == rhs.highlightedNoteID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                headerContent
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.bgSecondary.opacity(0.5))
            }
            
            if isExpanded {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(notes) { note in
                                ContextNoteCard(
                                    note: note,
                                    isHighlighted: highlightedNoteID == note.id
                                )
                                .id(note.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(Color.bgPrimary.opacity(0.5))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onChange(of: highlightedNoteID) { _, noteID in
                        guard let noteID else { return }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            proxy.scrollTo(noteID, anchor: .center)
                        }
                    }
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 0))
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
    }

    private var headerContent: some View {
        HStack {
            Image(systemName: "doc.text.fill")
                .foregroundColor(.accentPrimary)
                .font(.system(size: 14))

            Text(
                String(
                    format: L10n.text("ai_chat.context_notes_format"),
                    Int64(notes.count)
                )
            )
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.textMain)

            Spacer()

            Image(systemName: "chevron.down")
                .font(.caption)
                .foregroundColor(.textSub)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
    }
}

private struct ContextNoteCard: View {
    let note: Note
    let isHighlighted: Bool

    var body: some View {
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
        .background(isHighlighted ? Color.selectionHighlight : Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHighlighted ? Color.accentPrimary.opacity(0.75) : Color.black.opacity(0.05), lineWidth: isHighlighted ? 2 : 1)
        )
        .shadow(color: isHighlighted ? Color.accentPrimary.opacity(0.18) : Color.black.opacity(0.03), radius: isHighlighted ? 10 : 4, y: 2)
        .scaleEffect(isHighlighted ? 1.03 : 1.0)
    }
}

private struct InteractiveAssistantText: View {
    let segments: [ChatInlineSegment]
    let onCitationTap: ((MessageCitation) -> Void)?

    var body: some View {
        InteractiveMarkdownTextView(
            content: fullText,
            citations: citationsByNumber,
            onCitationTap: onCitationTap
        )
    }

    private var fullText: String {
        segments.reduce(into: "") { result, segment in
            switch segment {
            case .text(let text):
                result += text
            case .citation(let citation):
                result += "[\(citation.number)]"
            }
        }
    }

    private var citationsByNumber: [Int: MessageCitation] {
        segments.reduce(into: [:]) { result, segment in
            if case .citation(let citation) = segment {
                result[citation.number] = citation
            }
        }
    }
}

private struct SlashSkillIcon: View {
    let recipe: AgentRecipe

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.bgSecondary)
                .frame(width: 36, height: 36)

            if recipe.icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Image(systemName: recipe.systemIcon)
                    .font(.system(size: 18))
                    .foregroundColor(.accentPrimary)
            } else {
                Text(recipe.icon)
                    .font(.system(size: 18))
            }
        }
    }
}

private struct InteractiveMarkdownTextView: UIViewRepresentable {
    let content: String
    let citations: [Int: MessageCitation]
    let onCitationTap: ((MessageCitation) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onCitationTap: onCitationTap)
    }

    func makeUIView(context: Context) -> CitationTextView {
        let textView = CitationTextView()
        textView.delegate = context.coordinator
        return textView
    }

    func updateUIView(_ textView: CitationTextView, context: Context) {
        context.coordinator.onCitationTap = onCitationTap
        context.coordinator.citations = citations
        textView.attributedText = makeAttributedText()
        textView.linkTextAttributes = [
            .foregroundColor: UIColor(Color.accentPrimary),
            .underlineStyle: 0
        ]
        textView.invalidateIntrinsicContentSize()
    }

    private func makeAttributedText() -> NSAttributedString {
        let font = UIFont.preferredFont(forTextStyle: .callout)
        let color = UIColor(Color.textMain)
        let attributed = NSMutableAttributedString(
            attributedString: RichTextConverter.markdownToAttributedString(content, baseFont: font, textColor: color)
        )

        attributed.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: attributed.length), options: []) { value, range, _ in
            if let style = value as? NSParagraphStyle {
                let mutableStyle = style.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
                mutableStyle.alignment = .natural
                attributed.addAttribute(.paragraphStyle, value: mutableStyle, range: range)
            }
        }

        let nsString = attributed.string as NSString
        guard let regex = try? NSRegularExpression(pattern: #"\[(\d+)\]"#) else {
            return attributed
        }

        for match in regex.matches(in: attributed.string, range: NSRange(location: 0, length: nsString.length)) {
            guard match.numberOfRanges > 1 else { continue }
            let numberString = nsString.substring(with: match.range(at: 1))
            guard let number = Int(numberString), citations[number] != nil else { continue }
            let url = URL(string: "chillnote-citation://\(number)")!
            attributed.addAttributes([
                .link: url,
                .foregroundColor: UIColor(Color.accentPrimary),
                .font: UIFont.systemFont(ofSize: font.pointSize - 2, weight: .semibold)
            ], range: match.range)
        }

        return attributed
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var citations: [Int: MessageCitation] = [:]
        var onCitationTap: ((MessageCitation) -> Void)?

        init(onCitationTap: ((MessageCitation) -> Void)?) {
            self.onCitationTap = onCitationTap
        }

        func textView(
            _ textView: UITextView,
            shouldInteractWith URL: URL,
            in characterRange: NSRange,
            interaction: UITextItemInteraction
        ) -> Bool {
            guard URL.scheme == "chillnote-citation",
                  let host = URL.host,
                  let number = Int(host),
                  let citation = citations[number] else {
                return true
            }
            onCitationTap?(citation)
            return false
        }
    }
}

private final class CitationTextView: UITextView {
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        isEditable = false
        isScrollEnabled = false
        backgroundColor = .clear
        textContainerInset = .zero
        textContainer.lineFragmentPadding = 0
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .vertical)
        dataDetectorTypes = []
    }

    override var intrinsicContentSize: CGSize {
        let width = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width - 64
        let size = sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: UIView.noIntrinsicMetric, height: size.height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
    }
}

private struct SlashSkillsPanel: View {
    let recipes: [AgentRecipe]
    let isEmptyLibrary: Bool
    let onSelect: (AgentRecipe) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.text("ai_chat.skills_title"))
                .font(.caption.weight(.semibold))
                .foregroundColor(.textSub)

            if isEmptyLibrary {
                Text(L10n.text("ai_chat.skills_empty"))
                    .font(.subheadline)
                    .foregroundColor(.textSub)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(recipes) { recipe in
                            Button {
                                onSelect(recipe)
                            } label: {
                                HStack(spacing: 12) {
                                    SlashSkillIcon(recipe: recipe)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("/\(recipe.id)")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.textMain)
                                        Text(recipe.localizedDescription)
                                            .font(.caption)
                                            .foregroundColor(.textSub)
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.bouncy)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
    }
}

#Preview {
    AIContextChatView(contextNotes: [
        Note(content: "Learned about SwiftUI state management today. The difference between @State and @Binding is important.", userId: "preview-user"),
        Note(content: "Completed the UI design for the project, using gradients and rounded cards.", userId: "preview-user")
    ])
    .modelContainer(DataService.shared.container!)
}
