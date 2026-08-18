import SwiftUI
import UIKit
import AVFoundation

struct OnboardingFlowView: View {
    let onFinish: () -> Void

    @State private var currentPage = 0
    @State private var saveVideoDemoCompleted = false
    @State private var extractIdeasDemoCompleted = false
    @State private var generateHooksDemoCompleted = false
    @State private var showsLockedSwipeHint = false
    @State private var lockedSwipeHintRequest = 0

    private let pages: [OnboardingPage] = [
        .hero,
        .saveVideo,
        .extractIdeas,
        .captureShowcase,
        .generateHooks,
        .aiSkills
    ]

    private var isLastPage: Bool {
        currentPage == pages.count - 1
    }

    private var isHeroPage: Bool {
        pages.indices.contains(currentPage) && pages[currentPage] == .hero
    }

    private var isDemoLocked: Bool {
        guard pages.indices.contains(currentPage) else { return false }
        switch pages[currentPage] {
        case .saveVideo:
            return !saveVideoDemoCompleted
        case .extractIdeas:
            return !extractIdeasDemoCompleted
        case .generateHooks:
            return !generateHooksDemoCompleted
        case .hero, .captureShowcase, .aiSkills:
            return false
        }
    }

    private var firstIncompleteDemoPageIndex: Int? {
        if !saveVideoDemoCompleted {
            return pages.firstIndex(of: .saveVideo)
        }
        if !extractIdeasDemoCompleted {
            return pages.firstIndex(of: .extractIdeas)
        }
        if !generateHooksDemoCompleted {
            return pages.firstIndex(of: .generateHooks)
        }
        return nil
    }

    init(initialPage: Int = 0, onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        let clampedPage = max(0, min(initialPage, pages.count - 1))
        _currentPage = State(initialValue: clampedPage)
    }

    var body: some View {
        ZStack {
            BrandBackground()

            TabView(selection: pageSelection) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    pageView(for: page, isActive: currentPage == index)
                        .padding(.horizontal, BrandTokens.Space.s4)
                        .padding(.top, BrandTokens.Space.s4)
                        .padding(.bottom, BrandTokens.Space.s2)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .scrollDisabled(true)
            .simultaneousGesture(
                DragGesture(minimumDistance: 24)
                    .onEnded(handlePagingDrag)
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: currentPage)
        }
        .background(Color.bgPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            if !isDemoLocked {
                actionBar
                    .padding(.horizontal, BrandTokens.Space.s4)
                    .padding(.top, BrandTokens.Space.s2)
                    .padding(.bottom, BrandTokens.Space.s3)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.bgPrimary.opacity(0.0),
                                Color.bgPrimary.opacity(0.92),
                                Color.bgPrimary
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .overlay(alignment: .bottom) {
            if showsLockedSwipeHint {
                OnboardingLockedSwipeHint()
                    .padding(.bottom, BrandTokens.Space.s4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .task(id: lockedSwipeHintRequest) {
            guard showsLockedSwipeHint else { return }
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                showsLockedSwipeHint = false
            }
        }
    }

    @ViewBuilder
    private func pageView(for page: OnboardingPage, isActive: Bool) -> some View {
        switch page {
        case .hero:
            OnboardingHeroPage()
        case .saveVideo:
            OnboardingSaveVideoPage(isActive: isActive, isFlowComplete: $saveVideoDemoCompleted)
        case .extractIdeas:
            OnboardingExtractIdeasPage(isActive: isActive, isFlowComplete: $extractIdeasDemoCompleted)
        case .captureShowcase:
            OnboardingCaptureShowcasePage()
        case .generateHooks:
            OnboardingGenerateHooksPage(isActive: isActive, isFlowComplete: $generateHooksDemoCompleted)
        case .aiSkills:
            OnboardingAISkillsPage(isActive: isActive)
        }
    }

    private var actionBar: some View {
        VStack(spacing: BrandTokens.Space.s2) {
            Button {
                OnboardingHaptics.primaryAction(isFinalStep: isLastPage)
                handlePrimaryAction()
            } label: {
                HStack(spacing: BrandTokens.Space.s1) {
                    Text(L10n.text(primaryActionTitleKey))
                        .id(primaryActionTitleKey)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    if shouldShowNextArrow {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                            .transition(.opacity.combined(with: .scale(scale: 0.82)))
                    }
                }
                .brandPrimaryCTAStyle()
            }
            .buttonStyle(OnboardingPressButtonStyle(scale: 0.97))

            if isHeroPage {
                Button {
                    OnboardingHaptics.lightTap()
                    onFinish()
                } label: {
                    (Text(L10n.text("onboarding.flow.login.prompt")) +
                     Text(" ") +
                     Text(L10n.text("onboarding.flow.login.action")).fontWeight(.bold))
                    .font(.brandBody)
                    .foregroundStyle(Color.textSub)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, BrandTokens.Space.s1)
                }
                .buttonStyle(OnboardingPressButtonStyle(scale: 0.97))
                .accessibilityLabel(Text("\(L10n.text("onboarding.flow.login.prompt")) \(L10n.text("onboarding.flow.login.action"))"))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: primaryActionTitleKey)
    }

    private var primaryActionTitleKey: String {
        guard pages.indices.contains(currentPage) else { return "common.next" }
        switch pages[currentPage] {
        case .hero:
            return "onboarding.flow.action.get_started"
        case .generateHooks:
            return "onboarding.flow.action.explore_creator_skills"
        case .aiSkills:
            return "onboarding.flow.action.start_creating"
        case .saveVideo, .extractIdeas, .captureShowcase:
            return "common.next"
        }
    }

    private var shouldShowNextArrow: Bool {
        !isHeroPage && !isLastPage
    }

    private var pageSelection: Binding<Int> {
        Binding(
            get: { currentPage },
            set: requestPage
        )
    }

    private func handlePagingDrag(_ value: DragGesture.Value) {
        let horizontalDistance = value.translation.width
        let verticalDistance = value.translation.height
        guard abs(horizontalDistance) > abs(verticalDistance),
              abs(horizontalDistance) >= 52 else { return }

        let requestedPage = horizontalDistance < 0 ? currentPage + 1 : currentPage - 1
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            requestPage(requestedPage)
        }
    }

    private func requestPage(_ requestedPage: Int) {
        guard pages.indices.contains(requestedPage) else { return }
        guard let firstIncompleteDemoPageIndex,
              requestedPage > firstIncompleteDemoPageIndex else {
            showsLockedSwipeHint = false
            currentPage = requestedPage
            return
        }

        OnboardingHaptics.waitingHint()
        lockedSwipeHintRequest += 1
        withAnimation(.easeOut(duration: 0.2)) {
            showsLockedSwipeHint = true
        }
    }

    private func handlePrimaryAction() {
        guard !isDemoLocked else { return }
        if isLastPage {
            onFinish()
            return
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            requestPage(currentPage + 1)
        }
    }
}

private enum OnboardingPage: Int {
    case hero
    case saveVideo
    case extractIdeas
    case captureShowcase
    case generateHooks
    case aiSkills

    var id: Int { rawValue }
}

private struct OnboardingPressButtonStyle: ButtonStyle {
    let scale: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

private enum OnboardingHaptics {
    static func lightTap() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred(intensity: 0.55)
    }

    static func primaryAction(isFinalStep: Bool) {
        if isFinalStep {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } else {
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        }
    }

    static func playDemo() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred(intensity: 0.45)
    }

    static func ctaReady() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred(intensity: 0.62)
    }

    static func waitingHint() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred(intensity: 0.38)
    }
}

private func onboardingOptionalTitleText(_ key: String) -> String {
    let value = L10n.text(key)
    guard value != key, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return ""
    }
    return value
}

private enum OnboardingPhoneFrameMetrics {
    static let outerCornerRadius: CGFloat = 28
    static let screenCornerRadius: CGFloat = 22
    static let horizontalBezel: CGFloat = 6
    static let verticalBezel: CGFloat = 7
}

private struct OnboardingLockedSwipeHint: View {
    var body: some View {
        Text(L10n.text("onboarding.flow.demo.almost_done"))
            .font(.brandBody.weight(.semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, BrandTokens.Space.s3)
            .padding(.vertical, BrandTokens.Space.s2)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.76))
            )
            .shadow(color: Color.black.opacity(0.14), radius: 10, x: 0, y: 5)
            .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Hero Page

private struct OnboardingHeroPage: View {
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            LaunchScreenWordmark()

            Text(L10n.text("onboarding.flow.page1.subtitle"))
                .font(.brandTitle2)
                .foregroundStyle(Color.textMain.opacity(0.72))
                .padding(.top, BrandTokens.Space.s2)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 330)

            Spacer(minLength: 24)

            LoopingDemoPhoneView(resourceName: "demo1")
                .frame(maxWidth: 270)

            Spacer(minLength: 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 28)
        .accessibilityIdentifier("onboarding.page.hero")
    }
}

private struct LoopingDemoPhoneView: View {
    let resourceName: String
    @StateObject private var player: LoopingDemoVideoPlayer

    init(resourceName: String) {
        self.resourceName = resourceName
        _player = StateObject(wrappedValue: LoopingDemoVideoPlayer(resourceName: resourceName, ext: "mov"))
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: OnboardingPhoneFrameMetrics.outerCornerRadius, style: .continuous)
                .fill(Color.black)
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(Color.black)
                        .frame(width: 92, height: 25)
                        .padding(.top, 10)
                }

            ZStack {
                if let avPlayer = player.player {
                    VideoPlayerLayerView(player: avPlayer, videoGravity: .resizeAspectFill)
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: OnboardingPhoneFrameMetrics.screenCornerRadius, style: .continuous))
            .padding(.horizontal, OnboardingPhoneFrameMetrics.horizontalBezel)
            .padding(.vertical, OnboardingPhoneFrameMetrics.verticalBezel)
        }
        .aspectRatio(0.56, contentMode: .fit)
        .overlay {
            RoundedRectangle(cornerRadius: OnboardingPhoneFrameMetrics.outerCornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.34),
                            Color.white.opacity(0.05),
                            Color.black.opacity(0.42)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
                .padding(0.5)
        }
        .shadow(color: Color.shadowColor.opacity(0.34), radius: 24, x: 0, y: 16)
        .accessibilityHidden(true)
        .onAppear { player.play() }
        .onDisappear { player.pause() }
    }
}

@MainActor
private final class LoopingDemoVideoPlayer: ObservableObject {
    @Published private(set) var player: AVPlayer?
    private var endObserver: NSObjectProtocol?

    init(resourceName: String, ext: String) {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: ext) else { return }
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .none
        self.player = player

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }
    }

    func play() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }
}

// MARK: - Capture Showcase

private struct OnboardingCaptureShowcasePage: View {
    @State private var revealPhase = 0
    @State private var animateVoice = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(highlightedTitle)
                .font(.brandDisplay)
                .foregroundStyle(Color.textMain)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, BrandTokens.Space.s5)

            Spacer(minLength: 22)

            IdeaCaptureBoard(
                revealPhase: revealPhase,
                animateVoice: animateVoice
            )

            Spacer(minLength: 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("onboarding.page.capture")
        .task(id: revealPhase >= 2) {
            guard revealPhase >= 2, !animateVoice else { return }
            try? await Task.sleep(nanoseconds: 100_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                animateVoice = true
            }
        }
        .task {
            guard revealPhase == 0 else { return }
            let reveals: [(phase: Int, delay: UInt64)] = [
                (1, 120_000_000),
                (2, 320_000_000),
                (6, 480_000_000)
            ]
            for reveal in reveals {
                let phase = reveal.phase
                let delay = reveal.delay
                try? await Task.sleep(nanoseconds: delay)
                withAnimation(.easeOut(duration: 0.2)) {
                    revealPhase = phase
                }
            }
        }
    }

    private var highlightedTitle: AttributedString {
        var prefix = AttributedString(L10n.text("onboarding.flow.capture.title.prefix"))
        prefix.foregroundColor = Color.textMain

        var highlight = AttributedString(L10n.text("onboarding.flow.capture.title.highlight"))
        highlight.foregroundColor = Color.accentPrimary

        var suffix = AttributedString(onboardingOptionalTitleText("onboarding.flow.capture.title.suffix"))
        suffix.foregroundColor = Color.textMain

        return prefix + highlight + suffix
    }
}

private struct IdeaCaptureBoard: View {
    let revealPhase: Int
    let animateVoice: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            IdeaCaptureMethodRow(
                kind: .text,
                isVisible: revealPhase >= 1,
                animateVoice: animateVoice
            )

            Divider()
                .opacity(revealPhase >= 2 ? 1 : 0)

            IdeaCaptureMethodRow(
                kind: .voice,
                isVisible: revealPhase >= 2,
                animateVoice: animateVoice
            )

            Divider()
                .opacity(revealPhase >= 6 ? 1 : 0)

            IdeaCaptureMethodRow(
                kind: .links,
                isVisible: revealPhase >= 6,
                animateVoice: animateVoice
            )
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: BrandTokens.Radius.card, style: .continuous)
                .fill(Color.white.opacity(0.96))
                .brandShadow(BrandTokens.Shadow.card)
        )
    }
}

private struct IdeaCaptureMethodRow: View {
    let kind: IdeaCaptureMethodKind
    let isVisible: Bool
    let animateVoice: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IdeaCaptureMethodIcon(kind: kind, animateVoice: kind == .voice && isVisible && animateVoice)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 7) {
                Text(L10n.text(kind.titleKey))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.textMain)

                if kind == .voice {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(IdeaVoiceCapability.allCases) { capability in
                            IdeaVoiceCapabilityChip(
                                titleKey: capability.titleKey
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.top, 1)
                } else {
                    Text(L10n.text(kind.bodyKey))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textSub)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .layoutPriority(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(kind.background(isVisible: isVisible))
        .opacity(isVisible ? 1 : 0)
        .scaleEffect((kind == .voice || isVisible) ? 1 : 0.98)
        .accessibilityHidden(!isVisible)
    }
}

private enum IdeaCaptureMethodKind {
    case text
    case voice
    case links

    var iconName: String {
        switch self {
        case .text: return "pencil.line"
        case .voice: return "waveform"
        case .links: return "link"
        }
    }

    var titleKey: String {
        switch self {
        case .text: return "onboarding.flow.capture.text.title"
        case .voice: return "onboarding.flow.capture.voice.title"
        case .links: return "onboarding.flow.capture.links.title"
        }
    }

    var bodyKey: String {
        switch self {
        case .text: return "onboarding.flow.capture.text.body"
        case .voice: return ""
        case .links: return "onboarding.flow.capture.links.body"
        }
    }

    func background(isVisible: Bool) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(backgroundColor(isVisible: isVisible))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(strokeColor(isVisible: isVisible), lineWidth: 1)
            )
    }

    private func backgroundColor(isVisible: Bool) -> Color {
        guard isVisible else { return Color.bgSecondary.opacity(0.45) }
        switch self {
        case .text:
            return Color.bgSecondary.opacity(0.82)
        case .voice:
            return Color.accentPrimary.opacity(0.08)
        case .links:
            return Color(red: 0.18, green: 0.62, blue: 0.42).opacity(0.08)
        }
    }

    private func strokeColor(isVisible: Bool) -> Color {
        guard isVisible else { return Color.black.opacity(0.03) }
        switch self {
        case .text:
            return Color.black.opacity(0.05)
        case .voice:
            return Color.accentPrimary.opacity(0.18)
        case .links:
            return Color(red: 0.18, green: 0.62, blue: 0.42).opacity(0.16)
        }
    }

    var tint: Color {
        switch self {
        case .text:
            return Color.textMain
        case .voice:
            return Color.accentPrimary
        case .links:
            return Color(red: 0.18, green: 0.62, blue: 0.42)
        }
    }
}

private struct IdeaCaptureMethodIcon: View {
    let kind: IdeaCaptureMethodKind
    let animateVoice: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(kind.tint.opacity(0.12))
                .frame(width: 40, height: 40)

            switch kind {
            case .voice:
                HStack(spacing: 2) {
                    ForEach(0..<4, id: \.self) { index in
                        Capsule()
                            .fill(kind.tint)
                            .frame(width: 3, height: animateVoice ? CGFloat([14, 20, 12, 18][index]) : CGFloat([18, 12, 20, 14][index]))
                    }
                }
                .frame(height: 22)
            case .text, .links:
                Image(systemName: kind.iconName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(kind.tint)
            }
        }
    }
}

private enum IdeaVoiceCapability: String, CaseIterable, Identifiable {
    case removeFiller
    case extractTodos
    case fixGrammar
    case clarifyThoughts

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .removeFiller: return "onboarding.flow.capture.voice.capability.remove_filler"
        case .extractTodos: return "onboarding.flow.capture.voice.capability.extract_todos"
        case .fixGrammar: return "onboarding.flow.capture.voice.capability.fix_grammar"
        case .clarifyThoughts: return "onboarding.flow.capture.voice.capability.clarify_thoughts"
        }
    }
}

private struct IdeaVoiceCapabilityChip: View {
    let titleKey: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.accentPrimary)

            Text(L10n.text(titleKey))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.textMain)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.88))
                .overlay(
                    Capsule()
                        .stroke(Color.accentPrimary.opacity(0.16), lineWidth: 1)
                )
        )
    }
}

private struct OnboardingGenerateHooksPage: View {
    let isActive: Bool
    @Binding var isFlowComplete: Bool
    @State private var revealMessage = false
    @State private var videoCompleted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(highlightedTitle)
                .font(.brandDisplay)
                .foregroundStyle(Color.textMain)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, BrandTokens.Space.s5)

            ShareDemoStageView(
                step: .generateHooks,
                isActive: isActive,
                onComplete: complete
            )
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, BrandTokens.Space.s4)

            if revealMessage {
                OnboardingGenerateHooksTransition()
                    .padding(.top, BrandTokens.Space.s4)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            Spacer(minLength: 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("onboarding.page.generate_hooks")
        .animation(.easeOut(duration: 0.26), value: revealMessage)
        .task(id: videoCompleted) {
            guard videoCompleted, !isFlowComplete else { return }
            try? await Task.sleep(nanoseconds: 260_000_000)
            withAnimation(.easeOut(duration: 0.26)) {
                revealMessage = true
            }
            try? await Task.sleep(nanoseconds: 520_000_000)
            OnboardingHaptics.ctaReady()
            isFlowComplete = true
        }
    }

    private func complete() {
        videoCompleted = true
    }

    private var highlightedTitle: AttributedString {
        var prefix = AttributedString(L10n.text("onboarding.flow.generate_hooks.title.prefix"))
        prefix.foregroundColor = Color.textMain

        var highlight = AttributedString(L10n.text("onboarding.flow.generate_hooks.title.highlight"))
        highlight.foregroundColor = Color.accentPrimary

        var suffix = AttributedString(onboardingOptionalTitleText("onboarding.flow.generate_hooks.title.suffix"))
        suffix.foregroundColor = Color.textMain

        return prefix + highlight + suffix
    }
}

private struct OnboardingGenerateHooksTransition: View {
    var body: some View {
        HStack(alignment: .center, spacing: BrandTokens.Space.s2) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.accentPrimary)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(Color.accentPrimary.opacity(0.12))
                )

            Text(L10n.text("onboarding.flow.generate_hooks.transition"))
                .font(.brandBody.weight(.semibold))
                .foregroundStyle(Color.textMain)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, BrandTokens.Space.s3)
        .padding(.vertical, BrandTokens.Space.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.accentPrimary.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.accentPrimary.opacity(0.16), lineWidth: 1)
                )
        )
        .shadow(color: Color.accentPrimary.opacity(0.08), radius: 16, x: 0, y: 8)
    }
}

// MARK: - AI Skills Page

private struct OnboardingAISkillsPage: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealPhase = 1

    private var isCompactHeight: Bool {
        UIScreen.main.bounds.height <= 700
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(highlightedTitle)
                .font(.brandDisplay)
                .foregroundStyle(Color.textMain)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, BrandTokens.Space.s5)

            AISkillsDesignedDemoCard(
                isCompactHeight: isCompactHeight,
                revealPhase: revealPhase
            )
            .padding(.top, isCompactHeight ? 16 : 32)

            Spacer(minLength: isCompactHeight ? 18 : 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("onboarding.page.ai_skills")
        .task(id: isActive) {
            guard isActive else {
                revealPhase = 1
                return
            }

            let finalPhase = AISkillsLibraryPreviewItem.previewItems.count + 2
            guard !reduceMotion else {
                revealPhase = finalPhase
                return
            }

            revealPhase = 1
            try? await Task.sleep(nanoseconds: 300_000_000)

            for phase in 2...finalPhase {
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.24)) {
                    revealPhase = phase
                }
                try? await Task.sleep(
                    nanoseconds: phase == finalPhase ? 280_000_000 : 220_000_000
                )
            }
        }
    }

    private var highlightedTitle: AttributedString {
        var title = AttributedString(L10n.text("onboarding.flow.ai_skills.title"))
        title.foregroundColor = Color.textMain
        let highlight = L10n.text("onboarding.flow.ai_skills.title.highlight")

        if let highlightRange = title.range(of: highlight) {
            title[highlightRange].foregroundColor = Color.accentPrimary
        }

        return title
    }
}

private struct AISkillsDesignedDemoCard: View {
    let isCompactHeight: Bool
    let revealPhase: Int

    private var visibleSkills: [AISkillsLibraryPreviewItem] {
        let visibleCount = min(max(revealPhase, 1), AISkillsLibraryPreviewItem.previewItems.count)
        return AISkillsLibraryPreviewItem.previewItems.prefix(visibleCount).compactMap { item in
            guard let recipe = AgentRecipe.allRecipes.first(where: { $0.id == item.recipeID }) else {
                return nil
            }
            return AISkillsLibraryPreviewItem(
                recipeID: item.recipeID,
                status: item.status,
                recipe: recipe
            )
        }
    }

    private var showsBuildYourOwn: Bool {
        revealPhase > AISkillsLibraryPreviewItem.previewItems.count
    }

    private var showsLibrarySummary: Bool {
        revealPhase > AISkillsLibraryPreviewItem.previewItems.count + 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompactHeight ? 10 : 12) {
            HStack(alignment: .center, spacing: 10) {
                Text(L10n.text("recipes.section.library"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.textSub)
                    .tracking(0.5)
                    .textCase(.uppercase)

                Spacer(minLength: 0)

                if showsLibrarySummary {
                    AISkillsLibraryIconStack()
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(visibleSkills.enumerated()), id: \.element.id) { index, item in
                    AISkillsLibraryPreviewRow(item: item, isCompactHeight: isCompactHeight)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))

                    if index < visibleSkills.count - 1 {
                        Divider()
                            .padding(.leading, isCompactHeight ? 52 : 58)
                            .transition(.opacity)
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )

            if showsBuildYourOwn {
                AISkillsBuildYourOwnRow()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(isCompactHeight ? 12 : 14)
        .background(
            RoundedRectangle(cornerRadius: BrandTokens.Radius.card, style: .continuous)
                .fill(Color.white.opacity(0.96))
                .brandShadow(BrandTokens.Shadow.card)
        )
    }
}

private struct AISkillsLibraryPreviewItem: Identifiable {
    enum Status {
        case installed
        case new
    }

    let recipeID: String
    let status: Status
    var recipe: AgentRecipe?

    var id: String { recipeID }

    static let previewItems: [AISkillsLibraryPreviewItem] = [
        .init(recipeID: "hook_generator", status: .installed),
        .init(recipeID: "rewrite", status: .installed),
        .init(recipeID: "caption_pack", status: .installed),
        .init(recipeID: "repurpose_pack", status: .installed),
        .init(recipeID: "humanizer", status: .new),
        .init(recipeID: "style_match", status: .new)
    ]
}

private struct AISkillsLibraryPreviewRow: View {
    let item: AISkillsLibraryPreviewItem
    let isCompactHeight: Bool

    var body: some View {
        if let recipe = item.recipe {
            HStack(spacing: isCompactHeight ? 10 : 12) {
                CreatorSkillIcon(
                    recipe: recipe,
                    size: isCompactHeight ? 16 : 18,
                    container: isCompactHeight ? 36 : 40
                )

                Text(recipe.localizedName)
                    .font(.system(size: isCompactHeight ? 14 : 15, weight: .semibold))
                    .foregroundStyle(Color.textMain)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)

                Spacer(minLength: 8)

                AISkillsLibraryStatusBadge(status: item.status)
            }
            .frame(minHeight: isCompactHeight ? 43 : 48)
            .padding(.horizontal, isCompactHeight ? 10 : 12)
            .padding(.vertical, isCompactHeight ? 4 : 5)
        }
    }
}

private struct AISkillsBuildYourOwnRow: View {
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondaryHighlight)
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentSecondary)
            }
            .frame(width: 40, height: 40)

            Text(L10n.text("onboarding.flow.ai_skills.demo.build_your_own"))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.textMain)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(L10n.text("recipes.custom.create.badge"))
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(Color.accentPrimary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.selectionHighlight))

            Spacer(minLength: 0)

            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.accentPrimary)
        }
        .frame(minHeight: 54)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.white.opacity(0.90))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
        )
    }
}

private struct AISkillsLibraryStatusBadge: View {
    let status: AISkillsLibraryPreviewItem.Status

    var body: some View {
        Text(title)
            .font(.system(size: 10.5, weight: .bold))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(background))
    }

    private var title: String {
        switch status {
        case .installed:
            return L10n.text("recipes.section.installed")
        case .new:
            return L10n.text("common.new")
        }
    }

    private var foreground: Color {
        switch status {
        case .installed:
            return Color.accentPrimary
        case .new:
            return Color.accentSecondary
        }
    }

    private var background: Color {
        switch status {
        case .installed:
            return Color.selectionHighlight
        case .new:
            return Color.secondaryHighlight
        }
    }
}

private struct AISkillsLibraryIconStack: View {
    private var recipes: [AgentRecipe] {
        ["hook_generator", "rewrite", "caption_pack", "repurpose_pack"].compactMap { id in
            AgentRecipe.allRecipes.first { $0.id == id }
        }
    }

    var body: some View {
        HStack(spacing: -7) {
            ForEach(recipes) { recipe in
                CreatorSkillIcon(recipe: recipe, size: 13, container: 28)
                    .background(Circle().fill(Color.white))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: Color.shadowColor.opacity(0.18), radius: 4, x: 0, y: 2)
            }

            Text(verbatim: "10+")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(Color.accentPrimary)
                .frame(width: 31, height: 28)
                .background(
                    Capsule()
                        .fill(Color.accentPrimary.opacity(0.10))
                        .overlay(Capsule().stroke(Color.accentPrimary.opacity(0.16), lineWidth: 1))
                )
                .padding(.leading, 3)
        }
    }
}

// MARK: - Share Extension Page

private struct OnboardingSaveVideoPage: View {
    let isActive: Bool
    @Binding var isFlowComplete: Bool
    @State private var revealVideo = false
    @State private var platformRevealPhase = 0
    @State private var videoCompleted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(highlightedTitle)
                .font(.brandDisplay)
                .foregroundStyle(Color.textMain)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, BrandTokens.Space.s5)

            ShareDemoStageView(
                step: .share,
                isActive: isActive,
                onComplete: complete
            )
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, BrandTokens.Space.s3)
            .opacity(revealVideo ? 1 : 0)
            .offset(y: revealVideo ? 0 : 10)
            .allowsHitTesting(revealVideo)
            .accessibilityHidden(!revealVideo)

            if platformRevealPhase > 0 {
                VStack(spacing: 12) {
                    if platformRevealPhase >= 1 {
                        Text(L10n.text("onboarding.flow.save_video.platforms"))
                            .font(.brandBody.weight(.semibold))
                            .foregroundStyle(Color.textMain)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }

                    ShareSupportedPlatformsRow(visibleCount: max(0, platformRevealPhase - 1))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, BrandTokens.Space.s3)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            Spacer(minLength: 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("onboarding.page.save_video")
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: revealVideo)
        .animation(.easeOut(duration: 0.24), value: platformRevealPhase)
        .task {
            guard !revealVideo else { return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                revealVideo = true
            }
        }
        .task(id: videoCompleted) {
            guard videoCompleted, !isFlowComplete else { return }
            for phase in 1...4 {
                try? await Task.sleep(nanoseconds: phase == 1 ? 160_000_000 : 280_000_000)
                withAnimation(.easeOut(duration: 0.24)) {
                    platformRevealPhase = phase
                }
            }
            try? await Task.sleep(nanoseconds: 260_000_000)
            OnboardingHaptics.ctaReady()
            isFlowComplete = true
        }
    }

    private func complete() {
        videoCompleted = true
    }

    private var highlightedTitle: AttributedString {
        var prefix = AttributedString(L10n.text("onboarding.flow.save_video.title.prefix"))
        prefix.foregroundColor = Color.textMain

        var highlight = AttributedString(L10n.text("onboarding.flow.save_video.title.highlight"))
        highlight.foregroundColor = Color.accentPrimary

        var suffix = AttributedString(onboardingOptionalTitleText("onboarding.flow.save_video.title.suffix"))
        suffix.foregroundColor = Color.textMain

        return prefix + highlight + suffix
    }
}

private struct OnboardingExtractIdeasPage: View {
    let isActive: Bool
    @Binding var isFlowComplete: Bool
    @State private var sectionRevealPhase = 0
    @State private var videoCompleted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(highlightedTitle)
                .font(.brandDisplay)
                .foregroundStyle(Color.textMain)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, BrandTokens.Space.s5)

            ShareDemoStageView(
                step: .importNote,
                isActive: isActive,
                onComplete: complete
            )
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, BrandTokens.Space.s4)

            if sectionRevealPhase > 0 {
                ExtractedVideoSectionsCard(visibleCount: max(0, sectionRevealPhase - 1))
                    .padding(.top, BrandTokens.Space.s3)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            Spacer(minLength: 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("onboarding.page.extract_ideas")
        .animation(.easeOut(duration: 0.24), value: sectionRevealPhase)
        .task(id: videoCompleted) {
            guard videoCompleted, !isFlowComplete else { return }
            for phase in 1...5 {
                try? await Task.sleep(nanoseconds: phase == 1 ? 160_000_000 : 260_000_000)
                withAnimation(.easeOut(duration: 0.24)) {
                    sectionRevealPhase = phase
                }
            }
            try? await Task.sleep(nanoseconds: 260_000_000)
            OnboardingHaptics.ctaReady()
            isFlowComplete = true
        }
    }

    private func complete() {
        videoCompleted = true
    }

    private var highlightedTitle: AttributedString {
        var title = AttributedString(L10n.text("onboarding.flow.extract_ideas.title"))
        title.foregroundColor = Color.textMain
        let highlight = L10n.text("onboarding.flow.extract_ideas.title.highlight")

        if let highlightRange = title.range(of: highlight) {
            title[highlightRange].foregroundColor = Color.accentPrimary
        }

        return title
    }
}

private struct ExtractedVideoSectionsCard: View {
    var visibleCount = 4

    private let sectionKeys = [
        "onboarding.flow.extract_ideas.section.description",
        "onboarding.flow.extract_ideas.section.author",
        "onboarding.flow.extract_ideas.section.link",
        "onboarding.flow.extract_ideas.section.transcript"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("onboarding.flow.extract_ideas.saved_as"))
                .font(.brandLabel)
                .foregroundStyle(Color.textSub)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(Array(sectionKeys.enumerated()), id: \.element) { index, key in
                    let isVisible = index < visibleCount

                    HStack(spacing: 7) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.accentPrimary)

                        Text(L10n.text(key))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.textMain)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.88))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.accentPrimary.opacity(0.12), lineWidth: 1)
                            )
                    )
                    .opacity(isVisible ? 1 : 0)
                    .scaleEffect(isVisible ? 1 : 0.96)
                    .accessibilityHidden(!isVisible)
                    .animation(
                        .easeOut(duration: 0.22).delay(Double(index) * 0.025),
                        value: visibleCount
                    )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: BrandTokens.Radius.card, style: .continuous)
                .fill(Color.white.opacity(0.72))
                .brandShadow(BrandTokens.Shadow.card)
        )
    }
}

private struct ShareSupportedPlatformsRow: View {
    var visibleCount = 3

    private let platforms: [ShareSupportedPlatform] = [
        .init(name: "TikTok", style: .tiktok),
        .init(name: "YouTube", style: .youtube),
        .init(name: "Reels", style: .reels)
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(platforms.enumerated()), id: \.element.id) { index, platform in
                let isVisible = index < visibleCount

                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text(verbatim: platform.name)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)
                }
                .foregroundStyle(platform.style.foreground)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(platform.style.background)
                        .overlay(
                            Capsule()
                                .stroke(platform.style.stroke, lineWidth: 1)
                        )
                )
                .opacity(isVisible ? 1 : 0)
                .scaleEffect(isVisible ? 1 : 0.96)
                .accessibilityHidden(!isVisible)
                .animation(
                    .easeOut(duration: 0.22).delay(Double(index) * 0.025),
                    value: visibleCount
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: "TikTok, YouTube, Reels"))
    }
}

private struct ShareSupportedPlatform: Identifiable {
    let name: String
    let style: ShareSupportedPlatformStyle

    var id: String { name }
}

private enum ShareSupportedPlatformStyle {
    case tiktok
    case youtube
    case reels

    var foreground: Color {
        switch self {
        case .tiktok:
            return .white
        case .youtube:
            return Color(red: 1.0, green: 0.09, blue: 0.09)
        case .reels:
            return .white
        }
    }

    var background: AnyShapeStyle {
        switch self {
        case .tiktok:
            return AnyShapeStyle(Color.black.opacity(0.92))
        case .youtube:
            return AnyShapeStyle(Color(red: 1.0, green: 0.09, blue: 0.09).opacity(0.12))
        case .reels:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.72, blue: 0.18),
                        Color(red: 0.95, green: 0.22, blue: 0.48),
                        Color(red: 0.47, green: 0.27, blue: 0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    var stroke: Color {
        switch self {
        case .tiktok:
            return Color(red: 0.18, green: 0.95, blue: 0.90).opacity(0.34)
        case .youtube:
            return Color(red: 1.0, green: 0.09, blue: 0.09).opacity(0.22)
        case .reels:
            return Color.white.opacity(0.22)
        }
    }
}

private enum ShareDemoStep: String, Identifiable {
    case share
    case importNote
    case generateHooks

    var id: String { rawValue }

    var resourceName: String {
        switch self {
        case .share: return "demo1"
        case .importNote: return "demo2"
        case .generateHooks: return "demo3"
        }
    }

}

private struct ShareDemoStageView: View {
    let step: ShareDemoStep
    let isActive: Bool
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let maxPhoneWidth: CGFloat = 260
    private var phoneAspectRatio: CGFloat {
        step == .generateHooks ? 0.52 : 0.56
    }

    @StateObject private var loader: ShareDemoVideoLoader

    init(step: ShareDemoStep, isActive: Bool, onComplete: @escaping () -> Void) {
        self.step = step
        self.isActive = isActive
        self.onComplete = onComplete
        _loader = StateObject(wrappedValue: ShareDemoVideoLoader(resourceName: step.resourceName, ext: "mov", onComplete: onComplete))
    }

    var body: some View {
        Button {
            OnboardingHaptics.playDemo()
            loader.togglePlayback()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: OnboardingPhoneFrameMetrics.outerCornerRadius, style: .continuous)
                    .fill(Color.black)
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(Color.black)
                            .frame(width: 94, height: 26)
                            .padding(.top, 10)
                    }

                ZStack {
                    if let player = loader.player {
                        VideoPlayerLayerView(player: player, videoGravity: .resizeAspectFill)
                    } else {
                        ProgressView()
                            .tint(.white)
                    }

                    if loader.playbackState == .idle || loader.playbackState == .paused || loader.playbackState == .completed {
                        Circle()
                            .fill(Color.accentPrimary)
                            .frame(width: 68, height: 68)
                            .shadow(color: Color.accentPrimary.opacity(0.28), radius: 16, x: 0, y: 8)
                            .overlay {
                                Image(systemName: loader.playbackState == .completed ? "arrow.counterclockwise" : "play.fill")
                                    .font(.system(size: 23, weight: .bold))
                                    .foregroundStyle(Color.white)
                                    .offset(x: loader.playbackState == .paused ? 2 : 0)
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
                .overlay(alignment: .bottom) {
                    OnboardingVideoProgressBar(progress: loader.progress)
                        .padding(.horizontal, 3)
                        .padding(.bottom, 3)
                }
                .clipShape(RoundedRectangle(cornerRadius: OnboardingPhoneFrameMetrics.screenCornerRadius, style: .continuous))
                .padding(.horizontal, OnboardingPhoneFrameMetrics.horizontalBezel)
                .padding(.vertical, OnboardingPhoneFrameMetrics.verticalBezel)
            }
            .aspectRatio(phoneAspectRatio, contentMode: .fit)
            .frame(maxWidth: maxPhoneWidth)
            .shadow(color: Color.shadowColor.opacity(0.45), radius: 16, x: 0, y: 9)
        }
        .buttonStyle(OnboardingPressButtonStyle(scale: 0.985))
        .disabled(!isActive)
        .accessibilityLabel(Text(L10n.text(accessibilityLabelKey)))
        .accessibilityValue(Text(L10n.text("onboarding.flow.demo.accessibility.progress", Int(loader.progress * 100))))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: loader.playbackState)
        .task(id: isActive) {
            guard isActive else {
                loader.resetIfIncomplete()
                return
            }

            if loader.playbackState == .failed {
                onComplete()
                return
            }

            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled,
                  isActive,
                  loader.playbackState == .idle,
                  UIAccessibility.isVideoAutoplayEnabled else { return }
            loader.playFromBeginning()
        }
        .onDisappear {
            loader.pause()
        }
    }

    private var accessibilityLabelKey: String {
        switch loader.playbackState {
        case .playing:
            return "onboarding.flow.demo.accessibility.pause"
        case .completed:
            return "onboarding.flow.demo.accessibility.replay"
        case .idle, .paused, .failed:
            return "onboarding.flow.demo.accessibility.play"
        }
    }
}

private struct OnboardingVideoProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.24))

                Capsule()
                    .fill(Color.accentPrimary)
                    .frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }
}

private enum ShareDemoPlaybackState: Equatable {
    case idle
    case playing
    case paused
    case completed
    case failed
}

private struct VideoPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    var videoGravity: AVLayerVideoGravity = .resizeAspect

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = videoGravity
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.playerLayer.player = player
        uiView.playerLayer.videoGravity = videoGravity
    }
}

private final class PlayerContainerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

@MainActor
private final class ShareDemoVideoLoader: ObservableObject {
    @Published private(set) var player: AVPlayer?
    @Published private(set) var progress: Double = 0
    @Published private(set) var playbackState: ShareDemoPlaybackState = .idle

    private let onComplete: () -> Void
    private var endObserver: NSObjectProtocol?
    private nonisolated(unsafe) var timeObserver: Any?
    private nonisolated(unsafe) var observedPlayer: AVPlayer?
    private var hasCompleted = false

    init(resourceName: String, ext: String, onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: ext) else {
            playbackState = .failed
            return
        }
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .pause
        self.player = player
        observedPlayer = player

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.05, preferredTimescale: 600),
            queue: .main
        ) { [weak self, weak player] time in
            Task { @MainActor in
                guard let self, let player else { return }
                let duration = player.currentItem?.duration.seconds ?? 0
                guard duration.isFinite, duration > 0 else { return }
                self.progress = min(max(time.seconds / duration, 0), 1)
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.completeIfNeeded()
            }
        }
    }

    func togglePlayback() {
        switch playbackState {
        case .playing:
            pause()
        case .paused:
            resume()
        case .idle, .completed:
            playFromBeginning()
        case .failed:
            break
        }
    }

    func playFromBeginning() {
        guard let player else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        progress = 0
        playbackState = .playing
        player.seek(to: .zero)
        player.play()
    }

    private func resume() {
        guard let player else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        playbackState = .playing
        player.play()
    }

    func pause() {
        guard playbackState == .playing else { return }
        player?.pause()
        playbackState = .paused
    }

    func resetIfIncomplete() {
        guard !hasCompleted, playbackState != .failed else { return }
        player?.pause()
        player?.seek(to: .zero)
        progress = 0
        playbackState = .idle
    }

    private func completeIfNeeded() {
        let shouldNotifyCompletion = !hasCompleted
        hasCompleted = true
        progress = 1
        playbackState = .completed
        player?.pause()
        if shouldNotifyCompletion {
            onComplete()
        }
    }

    deinit {
        if let timeObserver, let observedPlayer {
            observedPlayer.removeTimeObserver(timeObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }
}

// MARK: - Shared visual helpers

private struct LaunchScreenWordmark: View {
    var body: some View {
        HStack(spacing: 0) {
            Text(verbatim: "Chill")
                .font(.custom("AvenirNext-DemiBold", size: 60))
                .foregroundColor(Color(red: 0.184, green: 0.525, blue: 1.0))

            Text(verbatim: "Script")
                .font(.custom("AvenirNext-HeavyItalic", size: 62))
                .foregroundColor(Color(red: 0.365, green: 0.569, blue: 0.961))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "ChillScript"))
    }
}

#Preview {
    OnboardingFlowView(onFinish: {})
}
