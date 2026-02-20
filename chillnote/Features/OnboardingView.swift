import SwiftUI
import AVFoundation

enum OnboardingGrammarDemoContent {
    struct GrammarToken: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let fixed: String?
        var isTypo: Bool { fixed != nil }
        
        init(_ text: String, fixed: String? = nil) {
            self.text = text
            self.fixed = fixed
        }
    }

    static let demoTokens: [GrammarToken] = [
        GrammarToken("Chill"),
        GrammarToken("Recipes"),
        GrammarToken("turn", fixed: "turns"),
        GrammarToken("your"),
        GrammarToken("notes"),
        GrammarToken("into"),
        GrammarToken("instent", fixed: "instant"),
        GrammarToken("actions,"),
        GrammarToken("so"),
        GrammarToken("instead"),
        GrammarToken("writing", fixed: "of writing"),
        GrammarToken("prompt", fixed: "prompts"),
        GrammarToken("from"),
        GrammarToken("scratch,"),
        GrammarToken("you"),
        GrammarToken("can"),
        GrammarToken("just"),
        GrammarToken("chose", fixed: "choose"),
        GrammarToken("what"),
        GrammarToken("you"),
        GrammarToken("want"),
        GrammarToken("and"),
        GrammarToken("run"),
        GrammarToken("it"),
        GrammarToken("on", fixed: "in"),
        GrammarToken("one"),
        GrammarToken("tap."),
        GrammarToken("From"),
        GrammarToken("quick"),
        GrammarToken("sumarize", fixed: "summary"),
        GrammarToken("to"),
        GrammarToken("social"),
        GrammarToken("post"),
        GrammarToken("generatoin,", fixed: "generation,"),
        GrammarToken("Chill"),
        GrammarToken("Recipes"),
        GrammarToken("help", fixed: "helps"),
        GrammarToken("you"),
        GrammarToken("move"),
        GrammarToken("from"),
        GrammarToken("rough"),
        GrammarToken("thoughts"),
        GrammarToken("to"),
        GrammarToken("finish", fixed: "finished"),
        GrammarToken("output"),
        GrammarToken("faster,"),
        GrammarToken("with"),
        GrammarToken("less"),
        GrammarToken("frictions", fixed: "friction"),
        GrammarToken("and"),
        GrammarToken("more"),
        GrammarToken("flows.", fixed: "flow."),
    ]
    
    // Legacy support if needed, or remove
    static let typoText = demoTokens.map { $0.text }.joined(separator: " ")
    static let fixedText = demoTokens.map { $0.fixed ?? $0.text }.joined(separator: " ")
    static let typoWords: [String] = demoTokens.filter { $0.isTypo }.map { $0.text.trimmingCharacters(in: .punctuationCharacters) }
}

struct OnboardingView: View {
    @Binding var isCompleted: Bool
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var inputText: String = ""
    @State private var isVoiceMode: Bool = true
    
    // Voice / Vibe Phase State
    @State private var voicePhaseState: VoicePhase = .idle // idle -> transcribing -> refining -> done
    @State private var rawTranscript: String = ""
    @State private var processedResult: String = ""
    @State private var processingError: String?
    
    enum VoicePhase {
        case idle, transcribing, refining, done
    }

    private var onboardingProcessingStage: VoiceProcessingStage {
        voicePhaseState == .transcribing ? .transcribing : .refining
    }
    
    // Recipes Phase State
    @State private var grammarResult: String? = nil
    // @State private var askAnswer: String? = nil // Removed
    @State private var isFixingGrammar = false
    @State private var isRecipesMenuOpen = false
    
    // Navigation / UI
    @State private var errorMessage: String? = nil
    @State private var currentPage = 0
    @State private var isSearchVisible = false
    
    @State private var showRecipesBar = false
    @State private var scanOffset: CGFloat = -300 // For scan animation
    
    // Pulse animation state
    @State private var isRecipesButtonPulsing = false
    @State private var isAskButtonPulsing = false
    @State private var isErrorPulsing = false
    @State private var showKoalaHint = false // New hint state
    @State private var isFixGrammarPulsing = false // Pulse for specific item
    @State private var showVoiceIntents = false // New state for showing extra intents

    
    private let voicePrompt = String(localized: "Remind me to buy beef, tomatoes, and pasta")
    
    private let typoText = OnboardingGrammarDemoContent.typoText
    // private let askQuestion = "Who is ChillNote designed for?" // Removed
    
    // Expanded Recipe List for "Wall"
    // Note: Categories mapped to existing cases in AgentRecipeCategory
    private let allRecipes: [AgentRecipe] = [
        AgentRecipe(id: "fix", icon: "✅", systemIcon: "checkmark", name: "Fix Grammar", description: "", prompt: "", category: .organize),
        AgentRecipe(id: "sum", icon: "📝", systemIcon: "doc.text", name: "Summarize", description: "", prompt: "", category: .organize),
        AgentRecipe(id: "mail", icon: "✉️", systemIcon: "envelope", name: "Email", description: "", prompt: "", category: .organize),
        AgentRecipe(id: "trans", icon: "🌍", systemIcon: "globe", name: "Translate", description: "", prompt: "", category: .organize),
        AgentRecipe(id: "blog", icon: "✍️", systemIcon: "pen.tip", name: "Blog Post", description: "", prompt: "", category: .publish),
        AgentRecipe(id: "tweet", icon: "🐦", systemIcon: "bird", name: "Tweet", description: "", prompt: "", category: .publish),
        AgentRecipe(id: "code", icon: "👨‍💻", systemIcon: "chevron.left.forwardslash.chevron.right", name: "Code Review", description: "", prompt: "", category: .organize),
        AgentRecipe(id: "idea", icon: "💡", systemIcon: "lightbulb", name: "Brainstorm", description: "", prompt: "", category: .organize),
        AgentRecipe(id: "plan", icon: "📅", systemIcon: "calendar", name: "Plan Day", description: "", prompt: "", category: .organize),
        AgentRecipe(id: "poem", icon: "🎭", systemIcon: "theatermasks", name: "Poem", description: "", prompt: "", category: .publish),
        AgentRecipe(id: "meet", icon: "🤝", systemIcon: "person.2", name: "Meeting Notes", description: "", prompt: "", category: .organize)
    ]
    
    // MARK: - Final Step Data
    
    struct DemoNote: Identifiable {
        let id = UUID()
        let title: String
        let content: String
        let offset: CGSize
        let rotation: Double
        let color: Color
    }
    
    private let demoNotes: [DemoNote] = [
        DemoNote(title: "Memory.note", content: "Ask helps you recall details instantly. No more digging through folders.", offset: CGSize(width: -100, height: -80), rotation: -6, color: .blue),
        DemoNote(title: "Connection.note", content: "Connects dots across different topics to synthesize new insights.", offset: CGSize(width: 100, height: -50), rotation: 4, color: .purple),
        DemoNote(title: "Creation.note", content: "Don't let answers disappear—save them as new notes instantly.", offset: CGSize(width: 0, height: 80), rotation: -2, color: .orange)
    ]
    
    enum AskPhase {
        case idle       // Showing floating notes
        case thinking   // Notes gathering
        case answering  // Text streaming
        case review     // Answer complete, waiting for save
        case saved      // Saved animation done
    }
    
    // Page Definitions
    
    var body: some View {
        ZStack {
            // Gradient Background
            LinearGradient(
                colors: [Color.bgPrimary, Color.accentPrimary.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                topBar
                    .opacity(currentPage == 6 ? 0 : 1)
                
                if isSearchVisible {
                    searchBar
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                }

                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    voiceDemoPage.tag(1)
                    recipesIntroPage.tag(2)
                    grammarDemoPage.tag(3)
                    finalStepView.tag(4)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                if currentPage < 4 {
                    pageIndicator
                }
            }
            
            // Bottom Bars Overlay
            VStack {
                Spacer()
                if showRecipesBar {
                    onboardingBottomBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 50) // Moved up
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentPage)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: askPhase)
        
        // Voice Logic Triggers
        .onChange(of: speechRecognizer.transcript) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            
            // Only trigger once when enough text is captured to simulate the demo
            if trimmed.count > 10 && voicePhaseState == .idle {
                 startVoiceDemoSequence(text: trimmed)
            }
        }
        
        .onChange(of: currentPage) { _, newValue in
            handlePageChange(to: newValue)
        }
        .onChange(of: speechRecognizer.permissionGranted) { _, granted in
            guard granted, currentPage == 1 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                speechRecognizer.prewarmRecordingSession()
            }
        }
    }
    
    // MARK: - Logic & Sequencing
    
    private func handlePageChange(to page: Int) {
        withAnimation {
            showVoiceIntents = false // Reset
            isRecipesMenuOpen = false
            isRecipesButtonPulsing = false
            isErrorPulsing = false
            isAskButtonPulsing = false
            showRecipesBar = false
            showKoalaHint = false
            isFixGrammarPulsing = false
        }

        if page == 1 {
            speechRecognizer.checkPermissions()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                speechRecognizer.prewarmRecordingSession()
            }
        }
        
        if page == 3 { // Recipes Demo
            // Don't show bar immediately. Guide user to Koala.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    showKoalaHint = true
                }
            }
        } else if page == 4 { // Final
            //  No specific setup needed for new Ask flow, 
            //  as it starts in .idle state driven by user interaction.
        }
    }
    
    private func startVoiceDemoSequence(text: String) {
        speechRecognizer.completeRecording()
        
        // Phase 1: Transcribing
        withAnimation { voicePhaseState = .transcribing }
        rawTranscript = text
        
        // Phase 2: Refining (Call real AI)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 0.5)) {
                voicePhaseState = .refining
            }
            
            // Call real AI processing
            Task {
                do {
                    let result = try await VoiceProcessingService.shared.processTranscript(text)
                    
                    // Phase 3: Show result
                    await MainActor.run {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                            voicePhaseState = .done
                            processedResult = result
                            processingError = nil
                            
                            // Show extra intents after a delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                withAnimation {
                                    showVoiceIntents = true
                                }
                            }
                        }
                    }
                } catch {
                    // Handle error gracefully
                    await MainActor.run {
                        withAnimation {
                            voicePhaseState = .done
                            processedResult = text // Fallback to raw text
                            processingError = String(localized: "AI processing unavailable")
                        }
                    }
                }
            }
        }
    }
    
    private func continueVoiceProcessing(text: String) {
        speechRecognizer.completeRecording()
        rawTranscript = text
        
        // Phase 2: Refining (Call real AI)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 0.5)) {
                voicePhaseState = .refining
            }
            
            // Call real AI processing
            Task {
                do {
                    let result = try await VoiceProcessingService.shared.processTranscript(text)
                    
                    // Phase 3: Show result
                    await MainActor.run {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                            voicePhaseState = .done
                            processedResult = result
                            processingError = nil
                            
                            // Show extra intents after a delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                withAnimation {
                                    showVoiceIntents = true
                                }
                            }
                        }
                    }
                } catch {
                    // Handle error gracefully
                    await MainActor.run {
                        withAnimation {
                            voicePhaseState = .done
                            processedResult = text // Fallback to raw text
                            processingError = String(localized: "AI processing unavailable")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Components Helper
    
    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(currentPage == index ? Color.accentPrimary : Color.accentPrimary.opacity(0.2))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            Button("Skip") { completeOnboarding() }
            .font(.bodyMedium)
            .foregroundColor(.textSub)
            .opacity(currentPage == 4 ? 0 : 1)
            
            Spacer()
            
            if currentPage == 3 || currentPage == 4 {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        if currentPage == 3 { 
                            showRecipesBar = true
                            showKoalaHint = false
                            isRecipesButtonPulsing = true
                        }
                    }
                } label: {
                ZStack {
                        Image("chillohead_touming")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(showKoalaHint && isErrorPulsing ? 10 : -10))
                            .animation(showKoalaHint ? .easeInOut(duration: 1.5).repeatForever(autoreverses: true) : .default, value: isErrorPulsing)
                            .onChange(of: showKoalaHint) { _, newValue in
                                if newValue { isErrorPulsing = true }
                            }
                    }
                }
                .buttonStyle(.plain)
                .overlay(alignment: .topTrailing) {
                    if showKoalaHint {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 16, height: 16)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .offset(x: 2, y: -2)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }
    
    // MARK: - Phase 0: Welcome
    private var welcomePage: some View {
        VStack(spacing: 40) {
            Spacer()
            Image("chillohead_touming")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
            
            VStack(spacing: 16) {
                Text("Welcome to ChillNote")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.textMain)
                    .multilineTextAlignment(.center)
                Text("For minds that refuse to be boxed in.")
                    .font(.bodyMedium)
                    .foregroundColor(.textSub)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .lineSpacing(4)
            }
            Spacer()
            primaryButton(title: "Start", icon: "arrow.right") {
                withAnimation { currentPage = 1 }
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Phase 1: Voice Demo (Merged with Intro)
    private var voiceDemoPage: some View {
        VStack {
            Spacer(minLength: 12)
            
            VStack(spacing: 24) {
                if voicePhaseState == .idle {
                    // Icon
                    CustomMicIcon()
                        .frame(width: 72, height: 72)
                        .padding(18)
                        .background(
                            Circle()
                                .fill(Color.accentPrimary.opacity(0.1))
                                .background(
                                    Circle()
                                        .stroke(Color.accentPrimary.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .padding(.bottom, 8)

                    // Intro Header
                    VStack(spacing: 8) {
                        Text("Say it.\nSave it.")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(.textMain)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Initial Prompt
                    VStack(alignment: .leading, spacing: 16) {
                        sectionHeader(title: "Read this aloud")
                        Text(verbatim: "\"\(voicePrompt)\"")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .lineSpacing(6)
                            .foregroundColor(.textMain)
                            .padding(20)
                            .background(Color.bgSecondary.opacity(0.5))
                            .cornerRadius(20)
                    }
                    .modifier(OnboardingCardModifier())
                    
                } else if voicePhaseState == .transcribing || voicePhaseState == .refining {
                    // Processing State
                    VStack(alignment: .leading, spacing: 16) {
                        VoiceProcessingWorkflowView(
                            currentStage: onboardingProcessingStage,
                            style: .detailed,
                            showPersistentHint: true
                        )
                        
                        // Show raw transcript during processing (or placeholder)
                        if !rawTranscript.isEmpty {
                            Text(rawTranscript)
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .lineSpacing(6)
                                .foregroundColor(voicePhaseState == .refining ? .textSub.opacity(0.5) : .textMain)
                        } else {
                            Text("Processing audio...")
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(.textSub.opacity(0.5))
                                .italic()
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
                    .cornerRadius(24)
                    
                } else {
                    // Done - Show AI Result
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("✨ Your Note")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.textMain)
                                Spacer()
                            }
                            
                            Divider().background(Color.black.opacity(0.05))
                            
                            // Display AI processed result with proper markdown rendering
                            JustifiedMarkdownText(
                                content: processedResult,
                                font: .systemFont(ofSize: 17),
                                textColor: UIColor(Color.textMain)
                            )
                            .frame(minHeight: 120)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            if let error = processingError {
                                Text(
                                    String(
                                        format: String(localized: "⚠️ %@"),
                                        error
                                    )
                                )
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        .modifier(OnboardingCardModifier())
                        
                        if showVoiceIntents {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("You can also say...")
                                    .font(.headline)
                                    .foregroundColor(.textSub)
                                
                                VStack(spacing: 12) {
                                    HStack {
                                        Image(systemName: "envelope")
                                            .foregroundColor(.accentPrimary)
                                        Text("Draft an email to my boss")
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.6))
                                    .cornerRadius(12)
                                    
                                    HStack {
                                        Image(systemName: "bird")
                                            .foregroundColor(.accentPrimary)
                                        Text("Tweet about this launch")
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.6))
                                    .cornerRadius(12)
                                }
                                .font(.subheadline)
                                .foregroundColor(.textMain)
                                
                                Button {
                                    withAnimation { currentPage = 2 }
                                } label: {
                                    HStack {
                                        Text("Next Steps")
                                        Image(systemName: "arrow.right")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.accentPrimary)
                                    .padding(.top, 10)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                }
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            
            Spacer(minLength: 120)
            
            // Mic Control
            if voicePhaseState == .idle {
                ChatInputBar(
                    text: $inputText,
                    isVoiceMode: $isVoiceMode,
                    speechRecognizer: speechRecognizer,
                    onSendText: {
                         if !inputText.isEmpty { startVoiceDemoSequence(text: inputText) }
                    },
                    onCancelVoice: { speechRecognizer.stopRecording(reason: .cancelled) },
                    onConfirmVoice: {
                        // Immediately show processing UI
                        withAnimation {
                            voicePhaseState = .transcribing
                        }
                        
                        // Stop recording and wait for transcription in background
                        speechRecognizer.stopRecording()
                        
                        // Monitor for transcript completion
                        Task {
                            // Wait for transcript to be ready
                            var attempts = 0
                            while speechRecognizer.transcript.isEmpty && attempts < 100 {
                                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                                attempts += 1
                            }
                            
                            await MainActor.run {
                                if !speechRecognizer.transcript.isEmpty {
                                    continueVoiceProcessing(text: speechRecognizer.transcript)
                                } else {
                                    // Timeout fallback
                                    withAnimation {
                                        voicePhaseState = .idle
                                    }
                                }
                            }
                        }
                    },
                    onCreateBlankNote: {},
                    enforceVoiceQuota: false,
                    recordTriggerMode: .tapToRecord
                )
                .padding(.bottom, 20)
            } else {
                Spacer(minLength: 80)
            }
        }
    }
    
    // MARK: - Phase 2: Recipes Intro (Wall)
    private var recipesIntroPage: some View {
        ZStack {
            // Recipe Wall Background
            GeometryReader { geo in
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 20) {
                    ForEach(allRecipes) { recipe in
                        VStack(spacing: 8) {
                            Text(recipe.icon).font(.largeTitle).opacity(0.3)
                        }
                        .frame(width: 80, height: 80)
                    }
                }
                .rotationEffect(.degrees(-10))
                .scaleEffect(1.2)
                .opacity(0.5) // Increased visibility from 0.15 to 0.5
                .offset(y: -50)
            }
            
            // Custom Layout to remove icon and split text
            VStack(spacing: 30) {
                Spacer()
                // Icon Removed
                
                VStack(spacing: 16) {
                    Text("Don't prompt\nJust tap")
                        .font(.system(size: 40, weight: .bold, design: .rounded)) // Larger & Split
                        .foregroundColor(.textMain)
                        .multilineTextAlignment(.center)
                        
                    Text("Complex tasks made instant")
                        .font(.body)
                        .foregroundColor(.textSub)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .lineSpacing(4)
                }
                Spacer()
                primaryButton(title: "Try Recipes", icon: "arrow.right", action: {
                    withAnimation { currentPage = 3 }
                })
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Phase 3: Recipes Demo (Grammar Scan)
    private var grammarDemoPage: some View {
        VStack {
            Spacer()
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        sectionHeader(title: "Chill Recipes")
                        Spacer()
                    }
                    
                    if grammarResult == nil {
                        Text("Fix messy thoughts, fast")
                            .font(.subheadline).foregroundColor(.textSub)
                    }
                    
                    // Text Container with Scan Effect
                    ZStack(alignment: .leading) {
                        if #available(iOS 16.0, *) {
                            AnimatedGrammarTextView(
                                tokens: OnboardingGrammarDemoContent.demoTokens,
                                isFixing: isFixingGrammar
                            )
                        } else {
                            if let result = grammarResult {
                                // Fixed Text
                                Text(result)
                                    .font(.system(size: 16, design: .rounded))
                                    .lineSpacing(6)
                                    .foregroundColor(.textMain)
                                    .transition(.opacity)
                            } else {
                                // Typo Text
                                TypoTextView(text: typoText, typos: OnboardingGrammarDemoContent.typoWords)
                            }
                        }
                        
                        // Scanner Beam
                        if isFixingGrammar && grammarResult == nil {
                            Rectangle()
                                .fill(
                                    LinearGradient(colors: [.clear, .accentPrimary.opacity(0.5), .clear], startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: 50)
                                .offset(x: scanOffset)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.bgSecondary.opacity(0.5)))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay {
                        if grammarResult != nil {
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.green.opacity(0.3), lineWidth: 2)
                                .shadow(color: .green.opacity(0.2), radius: 10)
                        }
                    }
                    
                    if grammarResult != nil {
                        Button { withAnimation { currentPage = 4 } } label: {
                            HStack { Text("Next: Ask AI"); Image(systemName: "arrow.right") }
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.accentPrimary)
                        }
                    }
                }
                .modifier(OnboardingCardModifier())
            }
            .padding(.horizontal, 20)
            Spacer()
            Spacer().frame(height: 100)
        }
    }
    
    // MARK: - Phase 5 (Ask)
    
    // MARK: - Phase 5 (Ask Interactive Demo)
    
    @State private var askPhase: AskPhase = .idle
    @State private var streamedAnswer: String = ""
    @State private var finalAnswer = "Based on your notes, Ask transforms static storage into active creation:\n\n1. Instant Recall\n2. Connection of ideas\n3. Saving new insights"
    
    private var finalStepView: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 30) {
                // Header
                if askPhase == .saved {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .transition(.scale.combined(with: .opacity))
                        
                        Text("You're ready.")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.textMain)
                    }
                } else {
                    VStack(spacing: 8) {
                        Text("Ask Your Notes")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.textMain)
                        Text(askPhase == .idle ? "Select notes to ask questions" : "Analyzing your knowledge base...")
                            .font(.body)
                            .foregroundColor(.textSub)
                            .transition(.opacity)
                            .id(askPhase == .idle) // Force transition
                    }
                }
                
                // Interactive Stage
                ZStack {
                    // 1. Background Floating Notes (Context)
                    ForEach(demoNotes) { note in
                        ContextNoteCard(note: note, isGathered: askPhase != .idle && askPhase != .saved)
                            .zIndex(askPhase == .saved ? 0 : 1) // Move behind when saved
                            .opacity(askPhase == .saved ? 0 : 1)
                    }
                    
                    // 2. AI Answer Card
                    if askPhase != .idle && askPhase != .thinking {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image("chillohead_touming")
                                    .resizable().scaledToFit().frame(width: 24, height: 24)
                                Text("Chill AI")
                                    .font(.caption.bold())
                                    .foregroundColor(.accentPrimary)
                                Spacer()
                            }
                            
                            Text(streamedAnswer)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.textMain)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(height: 120, alignment: .topLeading) // Reserve space
                                .animation(nil, value: streamedAnswer) // No animation on text change for typing effect
                            
                            if askPhase == .review {
                                Button {
                                    saveNoteAction()
                                } label: {
                                    HStack {
                                        Text("Save as Note")
                                        Image(systemName: "square.and.arrow.down")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.accentPrimary)
                                    .cornerRadius(12)
                                    .shadow(color: .accentPrimary.opacity(0.3), radius: 8, y: 4)
                                }
                                .transition(.scale.combined(with: .opacity).combined(with: .move(edge: .bottom)))
                            }
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(.ultraThinMaterial)
                                .background(Color.white.opacity(0.5))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                        .padding(.horizontal, 30)
                        .transition(.scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .bottom)))
                        .zIndex(10)
                        // Fly away animation
                        .offset(y: askPhase == .saved ? 400 : 0)
                        .scaleEffect(askPhase == .saved ? 0.1 : 1)
                        .opacity(askPhase == .saved ? 0 : 1)
                    }
                }
                .frame(height: 320)
                
                // 3. User Controls
                if askPhase == .idle {
                    Button {
                        startAskDemo()
                    } label: {
                        Text("Ask: \"Summarize core values\"")
                            .font(.headline)
                            .foregroundColor(.accentPrimary)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 32)
                        .background(Color.accentPrimary.opacity(0.1))
                        .cornerRadius(30)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else if askPhase == .saved {
                    Button {
                        completeOnboarding()
                    } label: {
                        HStack { Text("Get Started").font(.title3.weight(.bold)); Image(systemName: "arrow.right") }
                            .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 18)
                            .background(Capsule().fill(Color.accentPrimary))
                            .shadow(color: Color.accentPrimary.opacity(0.4), radius: 15, y: 8)
                    }
                    .padding(.horizontal, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            
            Spacer()
            Spacer().frame(height: 50)
        }
    }
    
    // MARK: - Final Step Helpers
    
    private func startAskDemo() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            askPhase = .thinking
        }
        
        // Simulate Thinking
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                askPhase = .answering
                streamText()
            }
        }
    }
    
    private func streamText() {
        streamedAnswer = ""
        let chars = Array(finalAnswer)
        var index = 0
        
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            if index < chars.count {
                streamedAnswer.append(chars[index])
                index += 1
            } else {
                timer.invalidate()
                withAnimation {
                    askPhase = .review
                }
            }
        }
    }
    
    private func saveNoteAction() {
        withAnimation(.easeIn(duration: 0.5)) {
            askPhase = .saved
        }
    }

    struct ContextNoteCard: View {
        let note: DemoNote
        let isGathered: Bool
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle().fill(note.color).frame(width: 8, height: 8)
                    Text(note.title)
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                    Spacer()
                }
                Text(note.content)
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(width: 180, height: 140)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            // Gather Transform
            .rotationEffect(.degrees(isGathered ? Double.random(in: -5...5) : note.rotation))
            .offset(isGathered ? .zero : note.offset)
            .scaleEffect(isGathered ? 0.9 : 1.0)
            .opacity(isGathered ? 0.6 : 1.0)
        }
    }

    
    // MARK: - Reusable
    

    
    private func primaryButton(title: LocalizedStringKey, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
             HStack { Text(title).font(.title3.weight(.bold)); Image(systemName: icon).font(.body.weight(.bold)) }
            .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 18)
            .background(Color.accentPrimary).clipShape(Capsule())
            .shadow(color: Color.accentPrimary.opacity(0.4), radius: 15, y: 8)
        }
        .padding(.horizontal, 32)
    }
    
    private func sectionHeader(title: LocalizedStringKey) -> some View {
        Text(title).font(.title3.weight(.bold)).foregroundColor(.textMain)
    }
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass").foregroundColor(.textSub)
            TextField("Search notes...", text: .constant("")).disabled(true)
        }
        .padding(12).background(Color.white.opacity(0.6)).cornerRadius(16)
    }

    // Actions
    private func runAction(_ recipe: AgentRecipe) {
        if recipe.id == "fix" { performGrammarFix(recipe) }
    }
    
    private func performGrammarFix(_ recipe: AgentRecipe) {
        isFixingGrammar = true
        errorMessage = nil
        
        // Start Scan Animation
        scanOffset = -300
        withAnimation(.linear(duration: 1.5)) {
            scanOffset = 300
        }
        
        // Simulated delay for scan animation, then show the corrected copy.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                grammarResult = OnboardingGrammarDemoContent.fixedText
                // Keep isFixingGrammar true to maintain the fixed state in AnimatedGrammarTextView
            }
        }
    }
    
    // Removed old askAIAboutNote function as it is replaced by startAskDemo

    
    private func completeOnboarding() {
        requestPermissions { withAnimation { isCompleted = true } }
    }
    
    private func requestPermissions(completion: @escaping () -> Void) {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { _ in DispatchQueue.main.async { completion() } }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { _ in DispatchQueue.main.async { completion() } }
        }
    }
    
    // Bottom Bar (Recipes & Ask)
    private var onboardingBottomBar: some View {
        VStack(spacing: 8) {
            if isRecipesMenuOpen {
                VStack(spacing: 16) {
                    HStack { Text("Chill Recipes").font(.headline).foregroundColor(.secondary); Spacer() }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        // Show only Fix Grammar
                        ForEach(allRecipes.filter { $0.id == "fix" }) { recipe in
                            Button {
                                runAction(recipe)
                                withAnimation { isRecipesMenuOpen = false }
                            } label: {
                                VStack(spacing: 10) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 18)
                                            .fill(Color.bgSecondary)
                                            .frame(width: 60, height: 60)
                                            .overlay {
                                                if recipe.id == "fix" && isFixGrammarPulsing {
                                                     RoundedRectangle(cornerRadius: 18)
                                                        .stroke(Color.accentPrimary, lineWidth: 3)
                                                        .scaleEffect(isErrorPulsing ? 1.1 : 1)
                                                        .opacity(isErrorPulsing ? 0 : 1)
                                                        .onAppear { isErrorPulsing = true }
                                                }
                                            }
                                        Text(recipe.icon).font(.largeTitle)
                                    }
                                    Text(recipe.localizedName).font(.caption).foregroundColor(recipe.id == "fix" ? .primary : .secondary).lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .modifier(OnboardingCardModifier())
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Only show Recipes Button Bar on Page 3 (Recipes Demo)
            if currentPage == 3 {
                // Recipes Button
                Button { withAnimation { 
                    isRecipesMenuOpen.toggle()
                    isRecipesButtonPulsing = false
                    if isRecipesMenuOpen { isFixGrammarPulsing = true }
                } } label: {
                    HStack { Text("Chill Recipes").font(.headline); Image(systemName: "chevron.up").rotationEffect(.degrees(isRecipesMenuOpen ? 180 : 0)) }
                        .foregroundColor(.accentPrimary).frame(maxWidth: .infinity).frame(height: 56)
                        .background(Color.white).clipShape(Capsule())
                        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                        .overlay(
                            Capsule().stroke(Color.accentPrimary, lineWidth: 3)
                                .scaleEffect(isRecipesButtonPulsing ? 1.05 : 1).opacity(isRecipesButtonPulsing ? 0 : 1)
                                .animation(isRecipesButtonPulsing ? .easeOut(duration: 1).repeatForever(autoreverses: false) : .default, value: isRecipesButtonPulsing)
                        )
                }
            }
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Custom Views & Modifiers

struct CustomMicIcon: View {
    @State private var animateGradient = false
    
    var body: some View {
        ZStack {
            // Capsule Body
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.accentPrimary, .purple.opacity(0.6)],
                        startPoint: animateGradient ? .topLeading : .bottomLeading,
                        endPoint: animateGradient ? .bottomTrailing : .topTrailing
                    )
                )
                .overlay(
                    LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .top, endPoint: .center)
                        .mask(Capsule())
                )
                .shadow(color: .accentPrimary.opacity(0.5), radius: 15, x: 0, y: 5)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        animateGradient.toggle()
                    }
                }
            
            // Grid / Mesh detail
            VStack(spacing: 3) {
                ForEach(0..<6) { _ in
                    Rectangle().fill(Color.white.opacity(0.2)).frame(height: 1)
                }
            }
            .mask(Capsule().padding(4))
        }
    }
}

struct TypoTextView: View {
    let text: String
    let typos: [String]
    
    var body: some View {
        if #available(iOS 16.0, *) {
            WavyTypoTextBlock(text: text, typos: typos)
        } else {
            Text(text)
        }
    }
}

@available(iOS 16.0, *)
private struct WavyTypoTextBlock: View {
    let text: String
    let typos: [String]

    private var words: [String] {
        text.split(separator: " ").map(String.init)
    }

    var body: some View {
        FlowWrapLayout(spacing: 4) {
            ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                TypoWordView(word: word, isTypo: isTypoWord(word))
            }
        }
    }

    private func isTypoWord(_ word: String) -> Bool {
        let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
        return typos.contains(cleanWord)
    }
}

@available(iOS 16.0, *)
private struct TypoWordView: View {
    let word: String
    let isTypo: Bool

    var body: some View {
        VStack(spacing: 1) {
            Text(word)
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(.textMain)
            if isTypo {
                WaveUnderline()
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .frame(height: 4)
            }
        }
    }
}

@available(iOS 16.0, *)
private struct WaveUnderline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let amplitude = max(0.8, rect.height * 0.28)
        let wavelength: CGFloat = 6

        path.move(to: CGPoint(x: 0, y: midY))

        var x: CGFloat = 0
        while x <= rect.width {
            let y = midY + sin((x / wavelength) * .pi * 2) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
            x += 1
        }

        return path
    }
}

@available(iOS 16.0, *)
private struct FlowWrapLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth, height: currentY + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct OnboardingCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(24)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 10)
    }
}

extension View {
    func triggerScaleAnimation() -> some View {
        self.modifier(ScaleAppearModifier())
    }
}

struct ScaleAppearModifier: ViewModifier {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
    }
}

// MARK: - Animated Grammar Views

@available(iOS 16.0, *)
struct AnimatedGrammarTextView: View {
    let tokens: [OnboardingGrammarDemoContent.GrammarToken]
    let isFixing: Bool
    
    @State private var fixedIndices: Set<Int> = []
    
    var body: some View {
        FlowWrapLayout(spacing: 4) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { index, token in
                AnimatedWordView(
                    token: token,
                    isFixed: fixedIndices.contains(index)
                )
            }
        }
        .onChange(of: isFixing) { _, newValue in
             if newValue {
                 startFixingAnimation()
             } else {
                 fixedIndices.removeAll()
             }
        }
    }
    
    private func startFixingAnimation() {
        let totalDuration = 1.5
        let count = Double(tokens.count)
        
        for (index, token) in tokens.enumerated() {
            if token.isTypo {
                // Calculate delay based on index (approximate position)
                let delay = (Double(index) / count) * totalDuration
                
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        _ = fixedIndices.insert(index)
                    }
                }
            }
        }
    }
}

@available(iOS 16.0, *)
struct AnimatedWordView: View {
    let token: OnboardingGrammarDemoContent.GrammarToken
    let isFixed: Bool
    
    var body: some View {
        VStack(spacing: 0) { // Tighter spacing
            ZStack {
                // Original Text
                if !isFixed {
                    Text(token.text)
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(.textMain)
                        .transition(.opacity)
                }
                
                // Fixed Text
                if isFixed {
                    Text(token.fixed ?? token.text)
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(.textMain)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isFixed)
            
            // Wavy line
            ZStack {
                if token.isTypo && !isFixed {
                    WaveUnderline()
                        .stroke(Color.red, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        .frame(height: 4)
                        .transition(.opacity)
                } 
            }
            .frame(height: 4)
            .animation(.easeOut(duration: 0.2), value: isFixed)
        }
    }
}
