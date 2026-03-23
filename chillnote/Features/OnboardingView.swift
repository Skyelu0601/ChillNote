import SwiftUI
import AVFoundation
import StoreKit

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
        GrammarToken("Skills"),
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
        GrammarToken("Skills"),
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
    var onCompleted: (() -> Void)? = nil
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @StateObject private var storeService = StoreService.shared
    @State private var inputText: String = ""
    @State private var isVoiceMode: Bool = true
    
    // Voice Language Selection (Onboarding Step 1)
    @AppStorage(VoiceTranscriptionPreferences.modeStorageKey) private var voiceLanguageModeRawValue = VoiceTranscriptionLanguageMode.auto.rawValue
    @AppStorage(VoiceTranscriptionPreferences.hintStorageKey) private var voiceLanguageHint = ""
    @State private var languageSearchText = ""
    @FocusState private var isLanguageSearchFocused: Bool
    
    // Voice / Vibe Phase State
    @State private var voicePhaseState: VoicePhase = .idle // idle -> transcribing -> refining -> done
    @State private var processedResult: String = ""
    @State private var processingError: String?
    
    enum VoicePhase {
        case idle, transcribing, refining, done
    }

    private var onboardingProcessingStage: VoiceProcessingStage {
        voicePhaseState == .transcribing ? .transcribing : .refining
    }

    private var isVoiceProcessingPhase: Bool {
        voicePhaseState == .transcribing || voicePhaseState == .refining
    }
    
    // Skills Chain Phase State
    @State private var skillChainStep: Int = 0
    @State private var skillChainAdvanceRunID: Int = 0
    @State private var skillsIntroPhase: Int = -1
    @State private var skillsIntroAnimationRunID: Int = 0
    
    // Navigation / UI
    @State private var errorMessage: String? = nil
    @State private var currentPage = 0
    @State private var isSearchVisible = false
    @State private var showVoiceIntents = false // New state for showing extra intents

    
    private let voicePrompt = String(localized: "Remind me to finish the demo, write the launch post, make a few screenshots, and share it on X and LinkedIn tomorrow")

    struct OnboardingTwitterPreview {
        let authorName: String
        let handle: String
        let body: String
        let hashtags: String
    }

    struct OnboardingSkillDemoState {
        let rawContent: String
        let summarySkill: AgentRecipe
        let summaryContent: String
        let polishSkill: AgentRecipe
        let polishContent: String
        let twitterSkill: AgentRecipe
        let twitterPreview: OnboardingTwitterPreview
    }

    private let onboardingSkillDemo: OnboardingSkillDemoState = {
        let summarize = AgentRecipe.allRecipes.first(where: { $0.id == "summarize" })!
        let polish = AgentRecipe.allRecipes.first(where: { $0.id == "fix_grammar" })!
        let twitter = AgentRecipe.allRecipes.first(where: { $0.id == "twitter_post" })!

        return OnboardingSkillDemoState(
            rawContent: """
            it's 11pm and I'm staring at this project I've been working on for the past three weekends. I honestly don't know if I should hit 'publish' or not. it's not that I think it's bad - I actually think the idea is strong. it's more that I'm scared nobody will care. if I share it and get zero response, I don't know how I'll keep going. but I know logically that keeping it to myself is a guaranteed failure. the real fear isn't about failing publicly, it's about confirming that the thing I thought was special... actually isn't. that's the real fear. I have my day job tomorrow at 9am and I have to decide tonight. I keep checking to see if anyone noticed the teaser I dropped last week. nobody did.
            """,
            summarySkill: summarize,
            summaryContent: """
            - Decision Paralysis: Whether to share a new project tonight despite the fear of silence.
            - Core Insight: The fear isn't of failure, but of realizing your 'special' idea might not be special.
            - The Paradox: Staying hidden guarantees failure; sharing is the only way to find out.
            - Signal vs. Noise: A teaser posted last week got zero traction, adding to the anxiety.
            - Deadline: 9 AM day-job pressure creates a 'now or never' moment.
            """,
            polishSkill: polish,
            polishContent: """
            It’s 11 PM, and I’m staring at a project I’ve spent the last three weekends on. 

            The idea is good. I think. That’s the problem.

            If I share it and nobody cares, I don’t know if I’ll have the heart to keep going. But staying quiet is the only way to guarantee it fails. 

            The real fear isn’t public failure. It’s the possibility that this thing I care about just isn't special. 

            I posted a teaser last week. Nobody noticed. 

            One way to find out. Sharing tomorrow.
            """,
            twitterSkill: twitter,
            twitterPreview: OnboardingTwitterPreview(
                authorName: "Skye",
                handle: "@skyemakes",
                body: """
                It’s 11 PM. I’ve been staring at this 'Publish' button for an hour. Three weekends of work. My day job starts at 9 AM.

                Failure isn't the scary part. The scary part is finding out the thing I thought was special... isn't.

                Shipping anyway. 🚀
                """,
                hashtags: "#ChillNotes #Makers"
            )
        )
    }()

    private let skillsIntroSections: [(title: String, subtitle: String, color: Color, recipes: [AgentRecipe])] = {
        let recipes = AgentRecipe.allRecipes
        return [
            (
                title: "Think",
                subtitle: "",
                color: .orange,
                recipes: recipes.filter { ["summarize", "adhd_helper", "explain_like_5", "merge_notes"].contains($0.id) }
            ),
            (
                title: "Shape",
                subtitle: "",
                color: .teal,
                recipes: recipes.filter { ["fix_grammar", "translate", "expand"].contains($0.id) }
            ),
            (
                title: "Publish",
                subtitle: "",
                color: .accentPrimary,
                recipes: recipes.filter { ["twitter_post", "linkedin_post", "draft_email", "youtube_script"].contains($0.id) }
            )
        ]
    }()
    
    // MARK: - Final Step Data
    
    struct DemoNote: Identifiable {
        let id = UUID()
        let title: String
        let content: String
        let offset: CGSize
        let rotation: Double
        let color: Color
    }
    
    private var demoNotes: [DemoNote] {
        [
            DemoNote(
                title: String(localized: "onboarding.ask.note.context.title"),
                content: String(localized: "onboarding.ask.note.context.content"),
                offset: CGSize(width: -100, height: -80),
                rotation: -6,
                color: .blue
            ),
            DemoNote(
                title: String(localized: "onboarding.ask.note.source.title"),
                content: String(localized: "onboarding.ask.note.source.content"),
                offset: CGSize(width: 100, height: -50),
                rotation: 4,
                color: .purple
            ),
            DemoNote(
                title: String(localized: "onboarding.ask.note.flow.title"),
                content: String(localized: "onboarding.ask.note.flow.content"),
                offset: CGSize(width: 0, height: 80),
                rotation: -2,
                color: .orange
            )
        ]
    }
    
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
                    .opacity(currentPage == 5 && askPhase == .saved ? 0 : 1)
                
                if isSearchVisible {
                    searchBar
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                }

                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    voiceLanguagePage.tag(1)
                    voiceDemoPage.tag(2)
                    recipesIntroPage.tag(3)
                    grammarDemoPage.tag(4)
                    finalStepView.tag(5)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                if currentPage < 6 && !(currentPage == 5 && askPhase == .saved) {
                    pageIndicator
                }
            }
        }
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
        .onChange(of: skillChainStep) { _, newValue in
            handleSkillChainStepChange(to: newValue)
        }
        .onChange(of: speechRecognizer.permissionGranted) { _, granted in
            guard granted, currentPage == 2 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                guard currentPage == 2 else { return }
                speechRecognizer.prewarmRecordingSession()
            }
        }
    }
    
    // MARK: - Logic & Sequencing
    
    private func handlePageChange(to page: Int) {
        showVoiceIntents = false // Reset
        dismissLanguageSearchKeyboard()
        languageSearchText = "" // Reset language search when leaving page

        if page == 2 { // Voice Demo (was 1)
            speechRecognizer.checkPermissions()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                guard currentPage == 2, speechRecognizer.permissionGranted else { return }
                speechRecognizer.prewarmRecordingSession()
            }
        }

        if page == 3 {
            startSkillsIntroAnimation()
        } else {
            resetSkillsIntroAnimation()
        }

        if page == 3 || page == 4 {
            skillChainAdvanceRunID += 1
            skillChainStep = 0
        }

        if page == 5 {
            if storeService.availableProducts.isEmpty && !storeService.isLoadingProducts {
                Task {
                    await storeService.refreshProducts()
                }
            }
        }
    }

    private func handleSkillChainStepChange(to step: Int) {
        guard currentPage == 4 else { return }

        skillChainAdvanceRunID += 1
        let runID = skillChainAdvanceRunID

        guard step == 3 else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            guard currentPage == 4, skillChainStep == 3, skillChainAdvanceRunID == runID else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                currentPage = 5
            }
        }
    }
    
    private func startVoiceDemoSequence(text: String) {
        speechRecognizer.completeRecording()
        
        // Phase 1: Transcribing
        withAnimation { voicePhaseState = .transcribing }
        
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
            ForEach(0..<6, id: \.self) { index in
                Capsule()
                    .fill(currentPage == index ? Color.accentPrimary : Color.accentPrimary.opacity(0.2))
                    .frame(width: currentPage == index ? 20 : 8, height: 8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentPage)
            }
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            if currentPage < 5 || (currentPage == 5 && askPhase != .saved) {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentPage = 5
                        askPhase = .saved
                    }
                } label: {
                    Text("Skip")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.textSub)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.7))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()
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
                Text("For makers who build, write, and create.")
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
    
    // MARK: - Phase 1: Voice Language Selection
    private var voiceLanguagePage: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentPrimary.opacity(0.1))
                        .frame(width: 80, height: 80)
                    Image(systemName: "globe")
                        .font(.system(size: 32))
                        .foregroundColor(.accentPrimary)
                }
                .padding(.top, 20)
                
                    VStack(spacing: 6) {
                        Text("Which language do\nyou usually speak?")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.textMain)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.85)
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(1)
                }
            }
            .padding(.bottom, 16)
            .contentShape(Rectangle())
            .onTapGesture {
                dismissLanguageSearchKeyboard()
            }
            
            // Search Bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.textSub)
                    .font(.system(size: 15))
                TextField("Search language...", text: $languageSearchText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .font(.bodyMedium)
                    .focused($isLanguageSearchFocused)
                    .submitLabel(.search)
                if !languageSearchText.isEmpty {
                    Button { languageSearchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.textSub)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.bgSecondary.opacity(0.7))
            .cornerRadius(12)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
            
            // Language List
            let filteredLangs = voiceLanguageListFiltered
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredLangs) { option in
                            let isSelected = voiceLanguageHint.lowercased() == option.code.lowercased()
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    voiceLanguageHint = option.code
                                    voiceLanguageModeRawValue = VoiceTranscriptionLanguageMode.prefer.rawValue
                                }
                                dismissLanguageSearchKeyboard()
                            } label: {
                                HStack(spacing: 14) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option.name)
                                            .font(.bodyMedium)
                                            .foregroundColor(isSelected ? .accentPrimary : .textMain)
                                        Text(option.code)
                                            .font(.caption)
                                            .foregroundColor(.textSub)
                                    }
                                    Spacer()
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.accentPrimary)
                                            .font(.system(size: 20))
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(isSelected ? Color.accentPrimary.opacity(0.06) : Color.clear)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .id(option.code)
                            
                            Divider().padding(.leading, 24)
                        }
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissLanguageSearchKeyboard()
                }
                .onAppear {
                    // Auto-select based on system language if not already chosen
                    if voiceLanguageHint.isEmpty {
                        applySystemLanguageDefault()
                    }
                    // Scroll to current selection
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        let target = voiceLanguageHint.isEmpty ? "en" : voiceLanguageHint
                        withAnimation { proxy.scrollTo(target, anchor: .center) }
                    }
                }
            }
            
            // Continue Button
            VStack(spacing: 0) {
                Divider()
                primaryButton(
                    title: voiceLanguageHint.isEmpty ? "Skip" : "Continue",
                    icon: voiceLanguageHint.isEmpty ? "arrow.right" : "arrow.right"
                ) {
                    withAnimation { currentPage = 2 }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
            }
        }
    }
    
    private var voiceLanguageListFiltered: [VoiceLanguageOption] {
        let trimmed = languageSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return VoiceLanguageOption.all }
        return VoiceLanguageOption.all.filter {
            $0.code.localizedCaseInsensitiveContains(trimmed) ||
            $0.name.localizedCaseInsensitiveContains(trimmed)
        }
    }
    
    private func applySystemLanguageDefault() {
        // Pick the best matching option from system preferred languages
        for preferredLang in Locale.preferredLanguages {
            let normalized = preferredLang.trimmingCharacters(in: .whitespacesAndNewlines)
            // Exact match first
            if VoiceLanguageOption.all.contains(where: { $0.code.lowercased() == normalized.lowercased() }) {
                voiceLanguageHint = normalized
                voiceLanguageModeRawValue = VoiceTranscriptionLanguageMode.prefer.rawValue
                return
            }
            // Prefix match (e.g. "zh-Hans-CN" -> "zh-Hans")
            if let match = VoiceLanguageOption.all.first(where: {
                normalized.lowercased().hasPrefix($0.code.lowercased())
            }) {
                voiceLanguageHint = match.code
                voiceLanguageModeRawValue = VoiceTranscriptionLanguageMode.prefer.rawValue
                return
            }
        }
    }

    private func dismissLanguageSearchKeyboard() {
        isLanguageSearchFocused = false
    }
    
    // MARK: - Phase 1: Voice Demo (Merged with Intro)
    private var voiceDemoPage: some View {
        GeometryReader { proxy in
            let isIdleState = voicePhaseState == .idle
            let bottomReservedHeight: CGFloat = isIdleState ? (128 + proxy.safeAreaInsets.bottom) : (24 + proxy.safeAreaInsets.bottom)
            let topPadding: CGFloat = voicePhaseState == .done ? 24 : (isVoiceProcessingPhase ? 16 : 20)

            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        if isIdleState {
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

                            VStack(spacing: 8) {
                                Text("Speak your ideas")
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundColor(.textMain)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                                    .minimumScaleFactor(0.75)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .layoutPriority(1)
                            }

                            VStack(alignment: .leading, spacing: 16) {
                                sectionHeader(title: "Read this aloud")
                                Text(verbatim: "\"\(voicePrompt)\"")
                                    .font(.system(size: 18, weight: .medium, design: .rounded))
                                    .lineSpacing(6)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundColor(.textMain)
                                    .padding(20)
                                    .background(Color.bgSecondary.opacity(0.5))
                                    .cornerRadius(20)
                            }
                            .modifier(OnboardingCardModifier())
                        } else {
                            ZStack {
                                if voicePhaseState == .transcribing || voicePhaseState == .refining {
                                    VStack(alignment: .leading, spacing: 16) {
                                        VoiceProcessingWorkflowView(
                                            currentStage: onboardingProcessingStage,
                                            style: .detailed,
                                            showPersistentHint: false
                                        )
                                    }
                                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                                }

                                if voicePhaseState == .done {
                                    VStack(alignment: .leading, spacing: 20) {
                                        VStack(alignment: .leading, spacing: 16) {
                                            HStack {
                                                HStack(spacing: 8) {
                                                    Image(systemName: "sparkles")
                                                        .foregroundColor(.accentPrimary)
                                                        .font(.system(size: 16, weight: .semibold))

                                                    Text("Refined Note")
                                                        .font(.system(.subheadline, design: .rounded))
                                                        .fontWeight(.bold)
                                                        .foregroundColor(.textMain)
                                                }

                                                Spacer()

                                                Text("AI REFINED")
                                                    .font(.system(size: 10, weight: .black))
                                                    .tracking(1)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.accentPrimary.opacity(0.1))
                                                    .foregroundColor(.accentPrimary)
                                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                            }

                                            Divider().background(Color.textMain.opacity(0.05))

                                            JustifiedMarkdownText(
                                                content: processedResult,
                                                font: .systemFont(ofSize: 17, weight: .medium),
                                                textColor: UIColor(Color.textMain)
                                            )
                                            .frame(minHeight: 180, alignment: .topLeading)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                            if let error = processingError {
                                                Text(String(format: String(localized: "⚠️ %@"), error))
                                                    .font(.caption)
                                                    .foregroundColor(.orange)
                                            }
                                        }
                                        .modifier(OnboardingNoteCardModifier())
                                        .transition(.opacity.combined(with: .scale(scale: 1.02)))

                                        if showVoiceIntents {
                                            VStack(alignment: .leading, spacing: 16) {
                                                Text("ChillNote can also...")
                                                    .font(.system(.headline, design: .rounded))
                                                    .foregroundColor(.textSub)
                                                    .padding(.horizontal, 4)

                                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                                    OnboardingFeatureTip(icon: "wand.and.stars", text: "Clean filler words")
                                                    OnboardingFeatureTip(icon: "text.alignleft", text: "Fix grammar")
                                                    OnboardingFeatureTip(icon: "brain.head.profile", text: "Clarify thoughts")
                                                    OnboardingFeatureTip(icon: "list.bullet.rectangle", text: "Action items")
                                                }
                                            }
                                            .transition(.move(edge: .bottom).combined(with: .opacity))
                                            .padding(.top, 8)

                                            primaryButton(title: "Next Steps", icon: "arrow.right") {
                                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                                    currentPage = 3
                                                }
                                            }
                                            .padding(.top, 12)
                                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: max(proxy.size.height - bottomReservedHeight, 0), alignment: .top)
                    .padding(.top, topPadding)
                    .padding(.bottom, 16)
                }

                if isIdleState {
                    ChatInputBar(
                        text: $inputText,
                        isVoiceMode: $isVoiceMode,
                        speechRecognizer: speechRecognizer,
                        onSendText: {
                             if !inputText.isEmpty { startVoiceDemoSequence(text: inputText) }
                        },
                        onCancelVoice: { speechRecognizer.stopRecording(reason: .cancelled) },
                        onConfirmVoice: {
                            withAnimation {
                                voicePhaseState = .transcribing
                            }

                            speechRecognizer.stopRecording()

                            Task {
                                var attempts = 0
                                while speechRecognizer.transcript.isEmpty && attempts < 100 {
                                    try? await Task.sleep(nanoseconds: 100_000_000)
                                    attempts += 1
                                }

                                await MainActor.run {
                                    if !speechRecognizer.transcript.isEmpty {
                                        continueVoiceProcessing(text: speechRecognizer.transcript)
                                    } else {
                                        withAnimation {
                                            voicePhaseState = .idle
                                        }
                                    }
                                }
                            }
                        },
                        enforceVoiceQuota: false,
                        recordTriggerMode: .tapToRecord
                    )
                    .padding(.bottom, max(12, proxy.safeAreaInsets.bottom))
                } else {
                    Color.clear
                        .frame(height: max(12, proxy.safeAreaInsets.bottom))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Phase 2: Skills Intro
    private var recipesIntroPage: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 8)

            VStack(spacing: 6) {
                Text("From Idea to Sharing")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.textMain)
                    .multilineTextAlignment(.center)

                Text("AI Skills")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.textSub)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 4)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(Array(skillsIntroSections.enumerated()), id: \.offset) { index, section in
                        skillsLibraryFlowSection(
                            index: index,
                            section: section,
                            isVisible: isSkillsIntroSectionVisible(index),
                            isHighlighted: activeSkillsIntroSectionIndex == index
                        )

                        if index < skillsIntroSections.count - 1 {
                            skillsLibraryArrow(
                                section: section,
                                isVisible: isSkillsIntroArrowVisible(index),
                                isActive: activeSkillsIntroArrowIndex == index
                            )
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 2)
            }

            Spacer(minLength: 4)

            primaryButton(title: "Try Skills", icon: "arrow.right") {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    currentPage = 4
                }
            }
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Phase 3: Skill Chain Playground
    private var grammarDemoPage: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                Spacer(minLength: 10)

                singleNoteDemoCard
                    .padding(.horizontal, 20)

                Spacer(minLength: 4)

                skillChainControlBar
                    .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 20)
                .background(
                    LinearGradient(
                        colors: [Color.bgPrimary.opacity(0.0), Color.bgPrimary, Color.bgPrimary],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }

    private var skillChainControlBar: some View {
        return VStack(spacing: 12) {
            HStack(spacing: 8) {
                skillChainControlButton(
                    title: "Think",
                    skillName: onboardingSkillDemo.summarySkill.localizedName,
                    isActive: skillChainStep == 0,
                    isComplete: skillChainStep >= 1,
                    color: .orange,
                    action: {
                        advanceSkillChainIfNeeded(for: 0)
                    }
                )

                skillChainControlButton(
                    title: "Shape",
                    skillName: onboardingSkillDemo.polishSkill.localizedName,
                    isActive: skillChainStep == 1,
                    isComplete: skillChainStep >= 2,
                    color: .teal,
                    action: {
                        advanceSkillChainIfNeeded(for: 1)
                    }
                )

                skillChainControlButton(
                    title: "Publish",
                    skillName: onboardingSkillDemo.twitterSkill.localizedName,
                    isActive: skillChainStep == 2,
                    isComplete: skillChainStep >= 3,
                    color: .accentPrimary,
                    action: {
                        advanceSkillChainIfNeeded(for: 2)
                    }
                )
            }

            HStack(spacing: 8) {
                Image(systemName: skillChainFooterIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(skillChainFooterColor)

                Text(skillChainFooterText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.textSub)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.78))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(skillChainFooterColor.opacity(0.12), lineWidth: 1)
            )
        }
    }

    private func advanceSkillChainIfNeeded(for index: Int) {
        guard skillChainStep == index else { return }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            skillChainStep += 1
        }
    }

    private var skillChainFooterColor: Color {
        switch skillChainStep {
        case 0: return .orange
        case 1: return .teal
        default: return .accentPrimary
        }
    }

    private var skillChainFooterIcon: String {
        switch skillChainStep {
        case 0: return "hand.tap"
        case 1: return "wand.and.stars"
        case 2: return "megaphone"
        default: return "arrow.right.circle.fill"
        }
    }

    private var skillChainFooterText: String {
        switch skillChainStep {
        case 0:
            return "Tap Think to pull out the core idea."
        case 1:
            return "Tap Shape to turn it into a cleaner draft."
        case 2:
            return "Tap Publish to generate a shareable post."
        default:
            return "Nice. Opening the real notes flow for you..."
        }
    }

    private func skillChainControlButton(
        title: String,
        skillName: String,
        isActive: Bool,
        isComplete: Bool,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    if isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(color)
                    } else {
                        Circle()
                            .fill(isActive ? color : color.opacity(0.25))
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(color.opacity(isActive ? 0.35 : 0), lineWidth: 3)
                                    .scaleEffect(isActive ? 1.6 : 1.0)
                                    .opacity(isActive ? 0.5 : 0)
                            )
                    }

                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundColor(isActive || isComplete ? .textMain : .textSub.opacity(0.6))
                }

                Text(skillName)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(isActive || isComplete ? color : .textSub.opacity(0.5))
                    .lineLimit(2)

                if isActive {
                    Text("Tap to use")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                } else if isComplete {
                    Text("Applied")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(color.opacity(0.88))
                } else {
                    Text("Next")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.textSub.opacity(0.45))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(isActive ? 14 : 11)
            .background(
                isComplete ? color.opacity(0.08) :
                isActive   ? color.opacity(0.15) :
                             Color.bgSecondary.opacity(0.55)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isActive ? color.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
            .scaleEffect(isActive ? 1.04 : 1.0)
            .shadow(color: isActive ? color.opacity(0.2) : .clear, radius: 8, y: 3)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isActive)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isComplete)
        }
        .buttonStyle(.plain)
        .disabled(!isActive)
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityLabel("\(title), \(skillName)")
    }

    private var singleNoteDemoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentNoteCardTitle)
                        .font(.headline)
                        .foregroundColor(.textMain)

                    if !currentNoteCardBadge.isEmpty {
                        Text(currentNoteCardBadge)
                            .font(.caption2.weight(.black))
                            .tracking(1)
                            .foregroundColor(currentNoteAccent)
                    }
                }

                Spacer()

                Image(systemName: currentNoteIcon)
                    .foregroundColor(currentNoteAccent)
                    .padding(10)
                    .background(currentNoteAccent.opacity(0.1))
                    .clipShape(Circle())
            }

            Group {
                if skillChainStep < 3 {
                    ScrollView(.vertical, showsIndicators: false) {
                        Text(currentNoteTextContent)
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(.textMain)
                            .lineSpacing(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("text-\(skillChainStep)")
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                    .frame(maxHeight: currentNoteHeight)
                } else {
                    twitterPreviewCard
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: skillChainStep)
        }
        .modifier(OnboardingNoteCardModifier())
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(currentNoteAccent.opacity(0.2), lineWidth: 1)
        )
    }

    private var currentNoteCardTitle: String {
        switch skillChainStep {
        case 0:
            return "Original Note"
        case 1:
            return "Used Skill: \(onboardingSkillDemo.summarySkill.localizedName)"
        case 2:
            return "Used Skill: \(onboardingSkillDemo.polishSkill.localizedName)"
        default:
            return "Used Skill: \(onboardingSkillDemo.twitterSkill.localizedName)"
        }
    }

    private var currentNoteCardBadge: String {
        switch skillChainStep {
        case 0:
            return ""
        case 1:
            return "THINK"
        case 2:
            return "SHAPE"
        default:
            return "PUBLISH"
        }
    }

    private var currentNoteIcon: String {
        switch skillChainStep {
        case 0:
            return "doc.text"
        case 1:
            return onboardingSkillDemo.summarySkill.systemIcon
        case 2:
            return onboardingSkillDemo.polishSkill.systemIcon
        default:
            return "bubble.left.and.bubble.right.fill"
        }
    }

    private var currentNoteAccent: Color {
        switch skillChainStep {
        case 0:
            return .gray
        case 1:
            return .orange
        case 2:
            return .teal
        default:
            return .accentPrimary
        }
    }

    private var currentNoteTextContent: String {
        switch skillChainStep {
        case 0:
            return onboardingSkillDemo.rawContent
        case 1:
            return onboardingSkillDemo.summaryContent
        default:
            return onboardingSkillDemo.polishContent
        }
    }

    private var currentNoteHeight: CGFloat {
        switch skillChainStep {
        case 0:
            return 380
        case 1:
            return 380
        default:
            return 380
        }
    }

    private var twitterPreviewCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .top, spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color(white: 0.15))
                        .frame(width: 44, height: 44)
                    Text(onboardingSkillDemo.twitterPreview.authorName.prefix(1))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(onboardingSkillDemo.twitterPreview.authorName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.textMain)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.accentPrimary)
                        Spacer()
                        Text("2m")
                            .font(.system(size: 13))
                            .foregroundColor(.textSub)
                    }
                    Text(onboardingSkillDemo.twitterPreview.handle)
                        .font(.system(size: 13))
                        .foregroundColor(.textSub)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)

            // Body
            VStack(alignment: .leading, spacing: 10) {
                Text(onboardingSkillDemo.twitterPreview.body)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.textMain)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                Text(onboardingSkillDemo.twitterPreview.hashtags)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.accentPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)

            Divider().padding(.horizontal, 16)

            // Interaction Bar
            HStack(spacing: 0) {
                ForEach([
                    ("bubble.left", "12"),
                    ("arrow.2.squarepath", "48"),
                    ("heart", "203"),
                    ("chart.bar.xaxis", "4.2K")
                ], id: \.0) { icon, count in
                    HStack(spacing: 5) {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .regular))
                        Text(count)
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.textSub)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    }

    private func skillsLibraryFlowSection(
        index: Int,
        section: (title: String, subtitle: String, color: Color, recipes: [AgentRecipe]),
        isVisible: Bool,
        isHighlighted: Bool
    ) -> some View {
        let accentColor = isHighlighted ? section.color : .textSub

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                Text(String(format: "%02d", index + 1))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(accentColor)

                VStack(alignment: .leading, spacing: section.subtitle.isEmpty ? 0 : 2) {
                    Text(section.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.textMain)

                    if !section.subtitle.isEmpty {
                        Text(section.subtitle)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.textSub)
                    }
                }
                Spacer()
            }

            if #available(iOS 16.0, *) {
                FlowWrapLayout(spacing: 8) {
                    ForEach(section.recipes) { recipe in
                        skillLibraryChip(recipe: recipe, color: section.color)
                    }
                }
                .padding(.horizontal, 2)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(section.recipes) { recipe in
                        skillLibraryChip(recipe: recipe, color: section.color)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.black.opacity(isHighlighted ? 0.08 : 0.05), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
        .shadow(color: Color.black.opacity(isHighlighted ? 0.05 : 0.03), radius: isHighlighted ? 10 : 6, y: 4)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 10)
        .animation(.spring(response: 0.55, dampingFraction: 0.84), value: isVisible)
        .animation(.easeInOut(duration: 0.25), value: isHighlighted)
    }

    private func skillLibraryChip(recipe: AgentRecipe, color: Color) -> some View {
        HStack(spacing: 5) {
            if recipe.icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Image(systemName: recipe.systemIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color)
            } else {
                Text(recipe.icon)
                    .font(.system(size: 14))
            }
            Text(recipe.localizedName)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.textMain)
                .lineLimit(1)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Color.bgSecondary.opacity(0.72))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(color.opacity(0.12), lineWidth: 1))
    }

    private func skillsLibraryArrow(
        section: (title: String, subtitle: String, color: Color, recipes: [AgentRecipe]),
        isVisible: Bool,
        isActive: Bool
    ) -> some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, section.color.opacity(0.16)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)

            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(section.color.opacity(isActive ? 0.9 : 0.55))
                .padding(6)
                .background(Color.white.opacity(isActive ? 0.95 : 0.7))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(section.color.opacity(isActive ? 0.18 : 0.08), lineWidth: 1)
                )

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [section.color.opacity(0.16), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 30)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : -4)
        .animation(.easeOut(duration: 0.35), value: isVisible)
        .animation(.easeInOut(duration: 0.22), value: isActive)
    }

    private var activeSkillsIntroSectionIndex: Int? {
        switch skillsIntroPhase {
        case 0: return 0
        case 2: return 1
        case 4: return 2
        default: return nil
        }
    }

    private var activeSkillsIntroArrowIndex: Int? {
        switch skillsIntroPhase {
        case 1: return 0
        case 3: return 1
        default: return nil
        }
    }

    private func isSkillsIntroSectionVisible(_ index: Int) -> Bool {
        guard skillsIntroPhase >= 0 else { return false }
        return index <= skillsIntroPhase / 2
    }

    private func isSkillsIntroArrowVisible(_ index: Int) -> Bool {
        guard skillsIntroPhase >= 1 else { return false }
        return index < (skillsIntroPhase + 1) / 2
    }

    private func resetSkillsIntroAnimation() {
        skillsIntroAnimationRunID += 1
        skillsIntroPhase = -1
    }

    private func startSkillsIntroAnimation() {
        let runID = skillsIntroAnimationRunID + 1
        skillsIntroAnimationRunID = runID
        skillsIntroPhase = -1

        let timeline: [(delay: Double, phase: Int)] = [
            (0.12, 0),
            (0.72, 1),
            (1.18, 2),
            (1.72, 3),
            (2.18, 4)
        ]

        for step in timeline {
            DispatchQueue.main.asyncAfter(deadline: .now() + step.delay) {
                guard currentPage == 3, skillsIntroAnimationRunID == runID else { return }
                withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                    skillsIntroPhase = step.phase
                }
            }
        }
    }
    
    // MARK: - Phase 5 (Ask)
    
    // MARK: - Phase 5 (Ask Interactive Demo)
    
    @State private var askPhase: AskPhase = .idle
    @State private var streamedAnswer: String = ""
    private var finalAnswer: String {
        String(localized: "onboarding.ask.final_answer")
    }

    private var yearlyProduct: Product? {
        storeService.availableProducts.first(where: { $0.subscription?.subscriptionPeriod.unit == .year })
        ?? storeService.availableProducts.first(where: { $0.id.lowercased().contains("year") })
    }
    
    private var onboardingPaywall: some View {
        VStack(spacing: 16) {
            // Dismiss button at Top Right
            HStack {
                Spacer()
                Button {
                    completeOnboarding()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.textMain.opacity(0.4))
                        .padding(8)
                        .background(Color.black.opacity(0.05))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            
            // Header
            VStack(spacing: 8) {
                ZStack {
                    Image("chillohead_touming")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 20))
                        .foregroundColor(.yellow)
                        .offset(x: 30, y: -20)
                }
                
                Text(String(localized: "You're all set!"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.textMain)
                
                Text(String(localized: "Unlock the full power of ChillNote"))
                    .font(.bodyMedium)
                    .foregroundColor(.textSub)
            }
            
            // Value Recap Card
            VStack(spacing: 16) {
                // Ensure BenefitRow matches the design from SubscriptionView
                BenefitRow(icon: "waveform", iconColor: .orange, title: "10-Minute Deep Dives", subtitle: "Capture long thoughts without interruption")
                BenefitRow(icon: "bubble.left.and.bubble.right.fill", iconColor: Color(red: 0.43, green: 0.44, blue: 0.78), title: "Unlimited Chat", subtitle: "Ask Chillo anything about your notes.")
                BenefitRow(icon: "wand.and.stars", iconColor: .blue, title: "Infinite Tidy & Polish", subtitle: "Instantly turn messy ramblings into structured notes.")
                BenefitRow(icon: "slider.horizontal.3", iconColor: .teal, title: "Custom Chill Skills", subtitle: "Create personalized AI Skills with Pro")
            }
            .padding(20)
            .background(Color.white.opacity(0.6))
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.04), radius: 15, x: 0, y: 5)
            .padding(.horizontal, 24)
            
            Spacer(minLength: 16)
            
            // CTA Area
            VStack(spacing: 12) {
                if let product = yearlyProduct {
                    let displayInfo = storeService.subscriptionDisplayInfo(for: product)

                    VStack(spacing: 10) {
                        VStack(spacing: 2) {
                            Text(product.displayPrice)
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .foregroundColor(.textMain)

                            Text(displayInfo.billingPeriodText)
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.textSub)
                        }

                        if let renewalText = displayInfo.renewalText {
                            Text(renewalText)
                                .font(.caption)
                                .foregroundColor(.textSub)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }
                    }

                    Button {
                        Task {
                            await storeService.purchase(product)
                            await MainActor.run {
                                completeOnboarding()
                            }
                        }
                    } label: {
                        Text(displayInfo.ctaText)
                            .font(.title3.weight(.bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accentPrimary)
                            .clipShape(Capsule())
                            .shadow(color: Color.accentPrimary.opacity(0.4), radius: 15, y: 8)
                    }
                    .disabled(storeService.isPurchasing)

                    Text(String(localized: "Easily manage or cancel in your Apple ID Settings."))
                        .font(.caption2)
                        .foregroundColor(.textSub.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else if storeService.isLoadingProducts {
                    VStack(spacing: 10) {
                        ProgressView()
                            .tint(.accentPrimary)

                        Text(String(localized: "Loading subscription details..."))
                            .font(.caption)
                            .foregroundColor(.textSub)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else if let error = storeService.productsErrorMessage {
                    VStack(spacing: 12) {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.textSub)
                            .multilineTextAlignment(.center)

                        Button {
                            Task {
                                await storeService.refreshProducts()
                            }
                        } label: {
                            Text(String(localized: "Retry"))
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.accentPrimary)
                                .clipShape(Capsule())
                        }

                        Button {
                            completeOnboarding()
                        } label: {
                            Text(String(localized: "Continue on Free Plan"))
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.textSub)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Text(String(localized: "Subscription details are temporarily unavailable."))
                            .font(.caption)
                            .foregroundColor(.textSub)
                            .multilineTextAlignment(.center)

                        Button {
                            Task {
                                await storeService.refreshProducts()
                            }
                        } label: {
                            Text(String(localized: "Try Again"))
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.accentPrimary)
                                .clipShape(Capsule())
                        }

                        Button {
                            completeOnboarding()
                        } label: {
                            Text(String(localized: "Continue on Free Plan"))
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.textSub)
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            
            // Legal & Restore Footer
            VStack(spacing: 12) {
                Button {
                    Task { await storeService.restorePurchases() }
                } label: {
                    Text(String(localized: "Restore Purchases"))
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.textSub)
                        .underline()
                }
                
                HStack(spacing: 16) {
                    Link(String(localized: "Terms of Use"), destination: URL(string: "https://www.chillnoteai.com/terms.html")!)
                    Link(String(localized: "Privacy Policy"), destination: URL(string: "https://www.chillnoteai.com/privacy.html")!)
                }
                .font(.system(size: 10))
                .foregroundColor(.textSub.opacity(0.6))
            }
            .padding(.bottom, 20)
        }
    }

    private var finalStepView: some View {
        Group {
            if askPhase == .saved {
                onboardingPaywall
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                VStack {
                    Spacer().frame(height: 20)
                    
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Ask Your Notes")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.textMain)
                            Text(askPhase == .idle ? "Select notes and ask anything about them" : "Reading your notes and building an answer...")
                                .font(.body)
                                .foregroundColor(.textSub)
                                .transition(.opacity)
                                .id(askPhase == .idle) // Force transition
                        }
                        
                        // Interactive Stage
                        ZStack {
                            // 1. Background Floating Notes (Context)
                            ForEach(demoNotes) { note in
                                ContextNoteCard(note: note, isGathered: askPhase != .idle && askPhase != .saved)
                                    .zIndex(1)
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
                                    
                                    ScrollView(.vertical, showsIndicators: true) {
                                        Text(streamedAnswer)
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .lineSpacing(2)
                                            .foregroundColor(.textMain)
                                            .frame(maxWidth: .infinity, alignment: .topLeading)
                                            .animation(nil, value: streamedAnswer) // No animation on text change for typing effect
                                    }
                                    .frame(minHeight: 180, maxHeight: askPhase == .review ? 280 : 260)
                                    
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
                            }
                        }
                        .frame(height: askPhase == .review ? 480 : 390)
                        
                        // 3. User Controls
                        if askPhase == .idle {
                            Button {
                                startAskDemo()
                            } label: {
                                Text(L10n.text("onboarding.ask.demo_prompt"))
                                    .font(.headline)
                                    .foregroundColor(.accentPrimary)
                                .padding(.vertical, 16)
                                .padding(.horizontal, 32)
                                .background(Color.accentPrimary.opacity(0.1))
                                .cornerRadius(30)
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    
                    Spacer(minLength: 8)
                }
            }
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

    private func completeOnboarding() {
        requestPermissions {
            onCompleted?()
            withAnimation { isCompleted = true }
        }
    }
    
    private func requestPermissions(completion: @escaping () -> Void) {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { _ in DispatchQueue.main.async { completion() } }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { _ in DispatchQueue.main.async { completion() } }
        }
    }
    
}

// MARK: - Custom Views & Modifiers

struct OnboardingFeatureTip: View {
    let icon: String
    let text: LocalizedStringKey
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.accentPrimary.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.accentPrimary)
            }
            
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.textMain)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.white.opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentPrimary.opacity(0.05), lineWidth: 1)
        )
    }
}

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

struct OnboardingNoteCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(24)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                    
                    // Subtle premium gradient
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [Color.mellowYellow.opacity(0.2), Color.clear, Color.accentPrimary.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.06), radius: 20, x: 0, y: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [Color.accentPrimary.opacity(0.2), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
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
