import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @Binding var isCompleted: Bool
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var inputText: String = ""
    @State private var isVoiceMode: Bool = true
    
    @State private var todoItems: [String] = []
    @State private var hasVoiceResult = false
    @State private var grammarResult: String? = nil
    @State private var askAnswer: String? = nil
    @State private var isFixingGrammar = false
    @State private var showKoalaBar = false
    @State private var errorMessage: String? = nil
    @State private var currentPage = 0
    @State private var showAskPrompt = false
    @State private var showAskChat = false
    @State private var isSearchVisible = false
    @State private var isKoalaMenuOpen = false
    
    private let voicePrompt = "This Saturday I'm cooking dinner. Please remind me to buy: beef, tomatoes, onions, pasta, and cream. Also get red wine and candles."
    private let typoText = """
ChillNote is a ntoe app for speach and quick ideas.
You can press the mic and tawk, then it truns voice into text.
It also find taskes and make a todo list fast.
With Chill Recipies, you can chose actions like sumarize or translate.
The app is desinged for pepole who hate typing and want fast capture.
It help you keep thougts, plans, and work notes all in one place.
"""
    private let askQuestion = "Who is ChillNote designed for?"
    
    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                topBar
                
                if isSearchVisible {
                    searchBar
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                }

                TabView(selection: $currentPage) {
                    voicePage
                        .tag(0)

                    grammarPage
                        .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentPage)
                
                pageIndicator
            }
        }
        .fullScreenCover(isPresented: $showAskChat) {
            if let contextNote = buildContextNote() {
                AIContextChatView(contextNotes: [contextNote], initialQuery: askQuestion, onAnswer: { answer in
                    askAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        showAskPrompt = true
                    }
                })
            }
        }
        .onChange(of: speechRecognizer.transcript) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                todoItems = parseTodoItems(from: trimmed)
                hasVoiceResult = true
            }
            speechRecognizer.completeRecording()
        }
        .onChange(of: speechRecognizer.recordingState) { _, newValue in
            if case .error(let message) = newValue {
                errorMessage = message
            }
        }
        .onChange(of: grammarResult) { _, newValue in
            if newValue != nil {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showAskPrompt = true
                }
            }
        }
        .onChange(of: currentPage) { _, newValue in
            if newValue != 1 {
                showKoalaBar = false
                isKoalaMenuOpen = false
            }
        }
    }
    
    private var topBar: some View {
        HStack {
            Button("Skip") {
                completeOnboarding()
            }
            .font(.bodyMedium)
            .foregroundColor(.textSub)
            
            Spacer()
            
            Text("ChillNote")
                .font(.displayMedium)
                .foregroundColor(.textMain)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isSearchVisible.toggle()
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(isSearchVisible ? .accentPrimary : .textMain.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                
                Button {
                    if currentPage == 1 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            showKoalaBar.toggle()
                        }
                    }
                } label: {
                    Image("chillohead_touming")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }
    
    private var voicePage: some View {
        VStack(spacing: 18) {
            if !hasVoiceResult {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(title: "Voice input")
                    
                    Text("Read this aloud to try voice input:")
                        .font(.bodySmall)
                        .foregroundColor(.textSub)
                    
                    Text(voicePrompt)
                        .font(.bodyMedium)
                        .foregroundColor(.textMain)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.bgSecondary)
                        )
                    
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .cardStyle()
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            if hasVoiceResult {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(title: "To-do list")
                    
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(todoItems, id: \.self) { item in
                            HStack(spacing: 10) {
                                Image(systemName: "square")
                                    .foregroundColor(.textSub)
                                Text(item)
                                    .font(.bodyMedium)
                                    .foregroundColor(.textMain)
                            }
                        }
                    }
                }
                .cardStyle()
                .transition(.scale.combined(with: .opacity))
            }
            
            Spacer(minLength: 12)
            
            if !hasVoiceResult {
                ChatInputBar(
                    text: $inputText,
                    isVoiceMode: $isVoiceMode,
                    speechRecognizer: speechRecognizer,
                    onSendText: {},
                    onCancelVoice: {
                        speechRecognizer.stopRecording(reason: .cancelled)
                    },
                    onConfirmVoice: {
                        speechRecognizer.stopRecording()
                    },
                    onCreateBlankNote: {}
                )
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Spacer(minLength: 12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
    
    private var grammarPage: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(title: "Fix Grammar")
                    
                    Text(grammarResult ?? typoText)
                        .font(.bodySmall)
                        .foregroundColor(.textMain)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.bgSecondary)
                        )
                        .transition(.opacity.combined(with: .scale))
                    
                    if isFixingGrammar {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Fixing grammar...")
                                .font(.caption)
                                .foregroundColor(.textSub)
                        }
                    } else if grammarResult == nil {
                        Text("Tap the Koala button to fix grammar.")
                            .font(.bodySmall)
                            .foregroundColor(.textSub)
                    } else {
                        Text("Grammar fixed.")
                            .font(.bodySmall)
                            .foregroundColor(.textSub)
                    }
                }
                .cardStyle()
                
                if showAskPrompt {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader(title: "Ask")
                        
                        Text(askQuestion)
                            .font(.bodyMedium)
                            .foregroundColor(.textMain)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.accentPrimary.opacity(0.12))
                            )
                        
                        if let askAnswer {
                            Text(askAnswer)
                                .font(.bodySmall)
                                .foregroundColor(.textMain)
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.bgSecondary)
                                )
                        } else {
                            Text("Tap Koala > Ask to get the answer.")
                                .font(.bodySmall)
                                .foregroundColor(.textSub)
                        }
                    }
                    .cardStyle()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                Spacer(minLength: 12)
                
                Button {
                    completeOnboarding()
                } label: {
                    Text("Get Started")
                        .font(.bodyMedium.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.textMain)
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            
                if showKoalaBar {
                    HomeSelectionBottomBar(
                        isMenuOpen: $isKoalaMenuOpen,
                        onAskAI: {
                            guard grammarResult != nil else { return }
                            showAskChat = true
                        },
                        onActionSelected: { recipe in
                            runAction(recipe)
                        },
                        actionsOverride: onboardingActions
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    
    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .fill(currentPage == index ? Color.accentPrimary : Color.accentPrimary.opacity(0.2))
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.bottom, 10)
    }
    
    
    private func runAction(_ recipe: AgentRecipe) {
        if recipe.id == "translate" {
            return
        }
        
        guard !isFixingGrammar else { return }
        isFixingGrammar = true
        errorMessage = nil
        
        let textToProcess = grammarResult ?? typoText
        var systemInstruction = recipe.prompt
        systemInstruction += "\n\n" + LanguageDetection.languagePreservationRule(for: textToProcess)
        let prompt = "Process the following notes:\n\n\(textToProcess)"
        
        Task {
            do {
                let result = try await GeminiService.shared.generateContent(
                    prompt: prompt,
                    systemInstruction: systemInstruction
                )
                await MainActor.run {
                    grammarResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
                    isFixingGrammar = false
                    if askAnswer == nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            showAskChat = true
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isFixingGrammar = false
                }
            }
        }
    }
    
    private func parseTodoItems(from transcript: String) -> [String] {
        let normalized = transcript.lowercased()
        let fallback = ["Beef", "Tomatoes", "Onions", "Pasta", "Cream", "Red Wine", "Candles"]
        
        guard let buyRange = normalized.range(of: "buy") else {
            return fallback
        }
        
        var itemsText = String(normalized[buyRange.upperBound...])
        if let colonRange = itemsText.range(of: ":") {
            itemsText = String(itemsText[colonRange.upperBound...])
        }
        itemsText = itemsText
            .replacingOccurrences(of: "also get", with: ",")
            .replacingOccurrences(of: "and", with: ",")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "please", with: "")
        
        let items = itemsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { $0.capitalized }
        
        return items.isEmpty ? fallback : items
    }
    
    private func buildContextNote() -> Note? {
        let content = grammarResult?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !content.isEmpty else { return nil }
        let userId = AuthService.shared.currentUserId ?? "onboarding"
        return Note(content: content, userId: userId)
    }
    
    private var onboardingActions: [AgentRecipe] {
        if let fix = AgentRecipe.allRecipes.first(where: { $0.id == "fix_grammar" }) {
            return [fix]
        }
        return []
    }
    
    private func completeOnboarding() {
        requestPermissions {
            withAnimation {
                isCompleted = true
            }
        }
    }
    
    private func requestPermissions(completion: @escaping () -> Void) {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { _ in
                DispatchQueue.main.async {
                    completion()
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { _ in
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }
    
    private func sectionHeader(title: String) -> some View {
        Text(title)
            .font(.bodyMedium.weight(.semibold))
            .foregroundColor(.textMain)
    }
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.textSub)
                .font(.system(size: 16, weight: .semibold))
            
            TextField("home.search.placeholder", text: .constant(""))
                .font(.bodyMedium)
                .foregroundColor(.textMain)
                .disabled(true)
            
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.textSub)
                .font(.system(size: 16))
                .opacity(0.35)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.03), lineWidth: 1)
        )
    }
}

struct HomeSelectionBottomBar: View {
    @Binding var isMenuOpen: Bool
    let onAskAI: () -> Void
    let onActionSelected: (AgentRecipe) -> Void
    let actionsOverride: [AgentRecipe]?

    private var actions: [AgentRecipe] {
        if let override = actionsOverride, !override.isEmpty {
            return override
        }
        return AgentRecipe.allRecipes
    }

    var body: some View {
        VStack(spacing: 8) {
            if isMenuOpen {
                VStack(spacing: 8) {
                    ForEach(actions) { recipe in
                        Button {
                            onActionSelected(recipe)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                isMenuOpen = false
                            }
                        } label: {
                            HStack {
                                Image(systemName: recipe.systemIcon)
                                    .foregroundColor(.accentPrimary)
                                Text(recipe.name)
                                    .foregroundColor(.textMain)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(Color.bgSecondary)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(Material.ultraThin)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.1), radius: 12, y: 6)
            }

            HStack(spacing: 12) {
                Button(action: onAskAI) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("Ask AI")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentPrimary)
                    .cornerRadius(16)
                }

                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        isMenuOpen.toggle()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt")
                        Text("Actions")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.accentPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.accentPrimary, lineWidth: 1)
                    )
                    .cornerRadius(16)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }
}

private extension View {
    func cardStyle() -> some View {
        self
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
            )
    }
}

#Preview {
    OnboardingView(isCompleted: .constant(false))
}
