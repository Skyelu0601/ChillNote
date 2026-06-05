import SwiftUI
import UIKit
import AVKit
import AVFoundation

struct OnboardingFlowView: View {
    let onFinish: () -> Void

    @State private var currentPage = 0
    private let initialPage: Int

    private let pages: [OnboardingPage] = [
        .hero,
        .captureShowcase,
        .shareExtension,
        .aiSkills
    ]

    private var isLastPage: Bool {
        currentPage == pages.count - 1
    }

    init(initialPage: Int = 0, onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        self.initialPage = initialPage
        let clampedPage = max(0, min(initialPage, pages.count - 1))
        _currentPage = State(initialValue: clampedPage)
    }

    var body: some View {
        ZStack {
            BrandBackground()

            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    pageView(for: page)
                        .padding(.horizontal, BrandTokens.Space.s4)
                        .padding(.top, BrandTokens.Space.s4)
                        .padding(.bottom, BrandTokens.Space.s2)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: currentPage)
        }
        .background(Color.bgPrimary.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            if !isLastPage {
                Button {
                    onFinish()
                } label: {
                    Text(L10n.text("common.skip"))
                        .font(.brandLabel)
                        .foregroundStyle(Color.textSub)
                        .padding(.horizontal, BrandTokens.Space.s2)
                        .padding(.vertical, BrandTokens.Space.s1)
                }
                .buttonStyle(OnboardingPressButtonStyle(scale: 0.94))
                .padding(.trailing, BrandTokens.Space.s3)
                .padding(.top, BrandTokens.Space.s1)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .safeAreaInset(edge: .bottom) {
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
        }
    }

    @ViewBuilder
    private func pageView(for page: OnboardingPage) -> some View {
        switch page {
        case .hero:
            OnboardingHeroPage()
        case .captureShowcase:
            OnboardingCaptureShowcasePage()
        case .shareExtension:
            OnboardingShareExtensionPage()
        case .aiSkills:
            OnboardingAISkillsPage()
        }
    }

    private var actionBar: some View {
        Button {
            handlePrimaryAction()
        } label: {
            HStack(spacing: BrandTokens.Space.s1) {
                Text(L10n.text(isLastPage ? "onboarding.flow.action.get_started" : "common.next"))
                    .id(isLastPage)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                if !isLastPage {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .transition(.opacity.combined(with: .scale(scale: 0.82)))
                }
            }
            .brandPrimaryCTAStyle()
        }
        .buttonStyle(OnboardingPressButtonStyle(scale: 0.97))
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isLastPage)
    }

    private func handlePrimaryAction() {
        if isLastPage {
            onFinish()
            return
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            currentPage += 1
        }
    }
}

private enum OnboardingPage: Int, CaseIterable {
    case hero
    case captureShowcase
    case shareExtension
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

// MARK: - Hero Page

private struct OnboardingHeroPage: View {
    /// Radius of the icon orbit. Tuned to sit just outside the 246pt outer ring.
    private let orbitRadius: CGFloat = 138

    /// Order around the circle, starting from the top and going clockwise.
    /// Each icon sits exactly 60° from its neighbors.
    private let heroIcons: [HeroRingIcon] = [
        // 12 o'clock
        HeroRingIcon(id: "idea",   icon: .system(name: "lightbulb.fill"),        tint: Color(red: 0.98, green: 0.73, blue: 0.17)),
        // 2 o'clock
        HeroRingIcon(id: "reels",  icon: .reels,                                 tint: .clear),
        // 4 o'clock
        HeroRingIcon(id: "yt",     icon: .youtube,                               tint: Color(red: 1.0, green: 0.23, blue: 0.19)),
        // 6 o'clock
        HeroRingIcon(id: "todo",   icon: .system(name: "checkmark.circle.fill"), tint: Color(red: 0.20, green: 0.72, blue: 0.37)),
        // 8 o'clock
        HeroRingIcon(id: "mic",    icon: .system(name: "mic.fill"),              tint: Color(red: 0.53, green: 0.42, blue: 0.97)),
        // 10 o'clock
        HeroRingIcon(id: "tiktok", icon: .tiktok,                                tint: .clear)
    ]

    @State private var breathe = false
    @State private var activeIconIndex = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LaunchScreenWordmark()

            Text(L10n.text("onboarding.flow.page1.subtitle"))
                .font(.brandTitle2)
                .foregroundStyle(Color.textMain.opacity(0.72))
                .padding(.top, BrandTokens.Space.s2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 28)

            ZStack {
                Circle().stroke(Color.accentPrimary.opacity(0.06), lineWidth: 1).frame(width: 246, height: 246)
                Circle().stroke(Color.accentPrimary.opacity(0.08), lineWidth: 1).frame(width: 194, height: 194)
                Circle().fill(Color.accentPrimary.opacity(0.12)).frame(width: 132, height: 132).blur(radius: 18)
                Circle().fill(Color.accentPrimary).frame(width: 104, height: 104).blur(radius: 0.4).opacity(0.18).offset(y: 10)

                NoteDetailLightningBallIcon(size: 114)
                    .scaleEffect(breathe ? 1.06 : 1.0)
                    .shadow(color: Color.accentPrimary.opacity(0.18), radius: 18, x: 0, y: 10)
                    .overlay {
                        Circle()
                            .stroke(Color.accentPrimary.opacity(0.16), lineWidth: 1.5)
                            .scaleEffect(breathe ? 1.28 : 1.02)
                            .opacity(breathe ? 0 : 1)
                    }

                ForEach(Array(heroIcons.enumerated()), id: \.element.id) { index, icon in
                    // Angles measured clockwise from 12 o'clock: 0°, 60°, 120°, …
                    // In screen coords (+y down), 12 o'clock corresponds to -π/2.
                    let theta = -Double.pi / 2 + Double(index) * (Double.pi / 3)
                    FloatingIconCard(icon: icon.icon, tint: icon.tint, isActive: activeIconIndex == index)
                        .offset(x: orbitRadius * CGFloat(cos(theta)),
                                y: orbitRadius * CGFloat(sin(theta)))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .onAppear {
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                    breathe = true
                }
            }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 900_000_000)
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                        activeIconIndex = (activeIconIndex + 1) % heroIcons.count
                    }
                }
            }

            Spacer(minLength: 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 28)
        .accessibilityIdentifier("onboarding.page.hero")
    }
}

// MARK: - Capture Showcase

private struct OnboardingCaptureShowcasePage: View {
    @State private var breathe = false
    @State private var revealPhase = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(highlightedTitle)
                .font(.brandDisplay)
                .foregroundStyle(Color.textMain)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, BrandTokens.Space.s5)

            Spacer(minLength: 24)

            CaptureNoteScreenshot(breathe: breathe, revealPhase: revealPhase)

            Spacer(minLength: 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("onboarding.page.capture")
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
        .task {
            for phase in 1...4 {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                    revealPhase = phase
                }
                try? await Task.sleep(nanoseconds: 520_000_000)
            }
        }
    }

    private var highlightedTitle: AttributedString {
        var prefix = AttributedString(L10n.text("onboarding.flow.capture.title.prefix"))
        prefix.foregroundColor = Color.textMain

        var highlight = AttributedString(L10n.text("onboarding.flow.capture.title.highlight"))
        highlight.foregroundColor = Color.accentPrimary

        var suffix = AttributedString(L10n.text("onboarding.flow.capture.title.suffix"))
        suffix.foregroundColor = Color.textMain

        return prefix + highlight + suffix
    }
}

private struct CaptureNoteScreenshot: View {
    let breathe: Bool
    let revealPhase: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CaptureInputChipRow(revealPhase: revealPhase)

            VStack(alignment: .leading, spacing: 12) {
                CaptureSourceCard()
                    .onboardingReveal(isVisible: revealPhase >= 1, yOffset: 8)

                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.text("onboarding.flow.capture.note.title"))
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(Color.textMain)
                        .lineLimit(2)
                        .onboardingReveal(isVisible: revealPhase >= 1, yOffset: 6)

                    CaptureNoteSection(
                        label: L10n.text("quick_capture.media_link.description_heading"),
                        text: L10n.text("onboarding.flow.capture.note.description")
                    )
                    .onboardingReveal(isVisible: revealPhase >= 2, yOffset: 6)

                    CaptureAuthorRow()
                        .onboardingReveal(isVisible: revealPhase >= 2, yOffset: 6)

                    CaptureNoteSection(
                        label: L10n.text("quick_capture.media_link.hook_heading"),
                        text: L10n.text("onboarding.flow.capture.note.hook")
                    )
                    .onboardingReveal(isVisible: revealPhase >= 3, yOffset: 6)

                    FadingTranscriptBlock()
                        .onboardingReveal(isVisible: revealPhase >= 4, yOffset: 6)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.black.opacity(0.05), lineWidth: 1)
                        )
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: BrandTokens.Radius.card, style: .continuous)
                .fill(Color.white.opacity(0.96))
                .brandShadow(BrandTokens.Shadow.card)
        )
        .scaleEffect(breathe ? 1.01 : 1.0)
        .frame(maxWidth: .infinity)
    }
}

private struct CaptureInputChipRow: View {
    let revealPhase: Int

    private let chips: [CaptureInputChip] = [
        CaptureInputChip(icon: "link", labelKey: "onboarding.flow.capture.chip.link", isSelected: true),
        CaptureInputChip(icon: "mic.fill", labelKey: "onboarding.flow.capture.chip.voice", isSelected: false),
        CaptureInputChip(icon: "photo.fill", labelKey: "onboarding.flow.capture.chip.photo", isSelected: false),
        CaptureInputChip(icon: "music.note", labelKey: "onboarding.flow.capture.chip.media", isSelected: false)
    ]

    var body: some View {
        HStack(spacing: 7) {
            ForEach(chips) { chip in
                HStack(spacing: 5) {
                    Image(systemName: chip.icon)
                        .font(.system(size: 10, weight: .bold))
                    Text(L10n.text(chip.labelKey))
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                }
                .foregroundStyle(chip.isSelected ? Color.accentPrimary : Color.textSub)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(chip.isSelected ? Color.accentPrimary.opacity(0.10) : Color.white.opacity(0.92))
                        .overlay(
                            Capsule()
                                .stroke(chip.isSelected ? Color.accentPrimary.opacity(0.22) : Color.black.opacity(0.05), lineWidth: 1)
                        )
                )
                .scaleEffect(chip.isSelected && revealPhase == 0 ? 1.04 : 1)
                .shadow(
                    color: chip.isSelected && revealPhase == 0 ? Color.accentPrimary.opacity(0.16) : .clear,
                    radius: 8,
                    x: 0,
                    y: 3
                )
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private extension View {
    func onboardingReveal(isVisible: Bool, yOffset: CGFloat) -> some View {
        opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : yOffset)
    }
}

private struct CaptureInputChip: Identifiable {
    let icon: String
    let labelKey: String
    let isSelected: Bool

    var id: String { labelKey }
}

private struct CaptureSourceCard: View {
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 34, height: 34)
                Text(verbatim: "TT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "TikTok")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textSub)
                Text(L10n.text("onboarding.flow.capture.source.title"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textMain)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "arrow.up.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.textSub)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.bgSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
        )
    }
}

private struct CaptureNoteSection: View {
    let label: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.textSub)
                .tracking(0.5)
                .textCase(.uppercase)
            Text(verbatim: text)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.textMain)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct CaptureAuthorRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.text("quick_capture.media_link.author_label"))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.textSub)
                .tracking(0.5)
                .textCase(.uppercase)

            HStack(spacing: 8) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.35, blue: 0.42), Color(red: 0.98, green: 0.68, blue: 0.20)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 26, height: 26)
                    .overlay(
                        Text(verbatim: "CM")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    )
                Text(L10n.text("onboarding.flow.capture.note.author"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textMain)
                Spacer(minLength: 0)
            }
        }
    }
}

private struct FadingTranscriptBlock: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(L10n.text("quick_capture.media_link.transcript_heading"))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.textSub)
                .tracking(0.5)
                .textCase(.uppercase)

            ZStack(alignment: .bottom) {
                Text(L10n.text("onboarding.flow.capture.note.transcript"))
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(Color.textMain.opacity(0.82))
                    .lineSpacing(2)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 28)
            }
        }
    }
}

// MARK: - AI Skills Page

private struct OnboardingAISkillsPage: View {
    private var isCompactHeight: Bool {
        UIScreen.main.bounds.height <= 700
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    Text(highlightedTitle)
                        .font(.brandDisplay)
                        .foregroundStyle(Color.textMain)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    Image(systemName: "bolt.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Color.accentPrimary))
                        .shadow(color: Color.accentPrimary.opacity(0.22), radius: 10, x: 0, y: 5)
                        .padding(.top, 4)
                        .accessibilityHidden(true)
                }

                Text(L10n.text("onboarding.flow.ai_skills.creator_subtitle"))
                    .font(.system(size: 17, weight: .semibold, design: .default))
                    .foregroundStyle(Color.textSub)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, isCompactHeight ? 14 : BrandTokens.Space.s5)

            Spacer(minLength: isCompactHeight ? 16 : 32)

            AISkillsDesignedDemoCard(isCompactHeight: isCompactHeight)

            Spacer(minLength: isCompactHeight ? 18 : 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("onboarding.page.ai_skills")
    }

    private var highlightedTitle: AttributedString {
        var prefix = AttributedString(L10n.text("onboarding.flow.ai_skills.title.prefix"))
        prefix.foregroundColor = Color.textMain

        var content = AttributedString(L10n.text("onboarding.flow.ai_skills.title.highlight"))
        content.foregroundColor = Color.accentPrimary

        return prefix + content
    }
}

private struct AISkillsDesignedDemoCard: View {
    let isCompactHeight: Bool

    @State private var selectedDemo: AISkillDemoSelection = .hooks
    @State private var shouldAutoAdvance = true

    var body: some View {
        VStack(alignment: .leading, spacing: isCompactHeight ? 12 : 14) {
            HStack(spacing: 8) {
                ForEach(AISkillDemoSelection.allCases) { tab in
                    AISkillDemoTabPill(tab: tab, isSelected: selectedDemo == tab) {
                        shouldAutoAdvance = false
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            selectedDemo = tab
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.text("onboarding.flow.ai_skills.demo.output.label"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.textSub)
                    .tracking(0.5)
                    .textCase(.uppercase)

                VStack(alignment: .leading, spacing: 9) {
                    ForEach(selectedDemo.rows) { row in
                        AISkillDemoOutputRow(labelKey: row.labelKey, textKey: row.textKey)
                    }
                }
                .id(selectedDemo)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.accentPrimary.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.accentPrimary.opacity(0.14), lineWidth: 1)
                    )
            )

            AISkillsBuildYourOwnRow()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: BrandTokens.Radius.card, style: .continuous)
                .fill(Color.white.opacity(0.96))
                .brandShadow(BrandTokens.Shadow.card)
        )
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                guard shouldAutoAdvance else { continue }
                guard let nextDemo = selectedDemo.next else {
                    shouldAutoAdvance = false
                    continue
                }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                    selectedDemo = nextDemo
                }
            }
        }
    }
}

private enum AISkillDemoSelection: String, CaseIterable, Identifiable {
    case hooks
    case captionPack
    case humanizer
    case repurpose

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .hooks: return "quote.opening"
        case .captionPack: return "text.bubble.fill"
        case .humanizer: return "pencil.and.scribble"
        case .repurpose: return "arrow.triangle.2.circlepath"
        }
    }

    var titleKey: String {
        switch self {
        case .hooks: return "agent_recipe.hook_generator.name"
        case .captionPack: return "agent_recipe.caption_pack.name"
        case .humanizer: return "agent_recipe.humanizer.name"
        case .repurpose: return "onboarding.flow.ai_skills.demo.tab.repurpose"
        }
    }

    var rows: [AISkillDemoOutputRowModel] {
        switch self {
        case .hooks:
            return [
                .init(labelKey: "onboarding.flow.ai_skills.demo.hooks.direct.label", textKey: "onboarding.flow.ai_skills.demo.hooks.direct.text"),
                .init(labelKey: "onboarding.flow.ai_skills.demo.hooks.question.label", textKey: "onboarding.flow.ai_skills.demo.hooks.question.text"),
                .init(labelKey: "onboarding.flow.ai_skills.demo.hooks.contrast.label", textKey: "onboarding.flow.ai_skills.demo.hooks.contrast.text")
            ]
        case .captionPack:
            return [
                .init(labelKey: "onboarding.flow.ai_skills.demo.caption.tiktok.label", textKey: "onboarding.flow.ai_skills.demo.caption.tiktok.text"),
                .init(labelKey: "onboarding.flow.ai_skills.demo.caption.youtube.label", textKey: "onboarding.flow.ai_skills.demo.caption.youtube.text"),
                .init(labelKey: "onboarding.flow.ai_skills.demo.caption.reels.label", textKey: "onboarding.flow.ai_skills.demo.caption.reels.text")
            ]
        case .humanizer:
            return [
                .init(labelKey: "onboarding.flow.ai_skills.demo.humanizer.before.label", textKey: "onboarding.flow.ai_skills.demo.humanizer.before.text"),
                .init(labelKey: "onboarding.flow.ai_skills.demo.humanizer.after.label", textKey: "onboarding.flow.ai_skills.demo.humanizer.after.text")
            ]
        case .repurpose:
            return [
                .init(labelKey: "onboarding.flow.ai_skills.demo.repurpose.thread.label", textKey: "onboarding.flow.ai_skills.demo.repurpose.thread.text"),
                .init(labelKey: "onboarding.flow.ai_skills.demo.repurpose.linkedin.label", textKey: "onboarding.flow.ai_skills.demo.repurpose.linkedin.text"),
                .init(labelKey: "onboarding.flow.ai_skills.demo.repurpose.newsletter.label", textKey: "onboarding.flow.ai_skills.demo.repurpose.newsletter.text")
            ]
        }
    }

    var next: AISkillDemoSelection? {
        switch self {
        case .hooks: return .captionPack
        case .captionPack: return .humanizer
        case .humanizer: return .repurpose
        case .repurpose: return nil
        }
    }
}

private struct AISkillDemoOutputRowModel: Identifiable {
    let labelKey: String
    let textKey: String

    var id: String { labelKey }
}

private struct AISkillDemoTabPill: View {
    let tab: AISkillDemoSelection
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentPrimary : Color.black.opacity(0.045))
                        .frame(width: 30, height: 30)

                    Image(systemName: tab.icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isSelected ? .white : Color.textSub)
                }

                Text(L10n.text(tab.titleKey))
                    .font(.system(size: 11.5, weight: isSelected ? .bold : .semibold))
                    .foregroundStyle(isSelected ? Color.textMain : Color.textSub)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.82)
                    .frame(height: 28, alignment: .top)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 5)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(isSelected ? Color.accentPrimary.opacity(0.08) : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(isSelected ? Color.accentPrimary.opacity(0.18) : Color.black.opacity(0.05), lineWidth: 1)
                )
        )
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct AISkillDemoOutputRow: View {
    let labelKey: String
    let textKey: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Text(L10n.text(labelKey))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.accentPrimary))
                .padding(.top, 1)

            Text(L10n.text(textKey))
                .font(.system(size: 13.5, weight: .regular))
                .foregroundStyle(Color.textMain)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}

private struct AISkillsBuildYourOwnRow: View {
    private let icons = [
        "wand.and.stars",
        "list.bullet.rectangle",
        "envelope.fill",
        "checkmark.circle.fill",
        "sparkles"
    ]

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: -8) {
                ForEach(Array(icons.enumerated()), id: \.offset) { index, icon in
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(index == 0 ? .white : Color.accentPrimary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(index == 0 ? Color.accentPrimary : Color.white)
                                .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 1))
                        )
                        .shadow(color: Color.shadowColor.opacity(0.25), radius: 5, x: 0, y: 3)
                }

                Text(verbatim: "+12")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(Color.accentPrimary)
                    .frame(width: 30, height: 28)
                    .background(
                        Capsule()
                            .fill(Color.accentPrimary.opacity(0.10))
                            .overlay(Capsule().stroke(Color.accentPrimary.opacity(0.16), lineWidth: 1))
                    )
                    .padding(.leading, 2)
            }

            Text(L10n.text("onboarding.flow.ai_skills.demo.build_your_own"))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.textMain)

            Spacer(minLength: 0)

            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.accentPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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

// MARK: - Share Extension Page

private struct OnboardingShareExtensionPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text(highlightedTitle)
                    .font(.brandDisplay)
                    .foregroundStyle(Color.textMain)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L10n.text("onboarding.flow.share.subtitle"))
                    .font(.brandBody)
                    .foregroundStyle(Color.textSub)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, BrandTokens.Space.s4)

            Spacer(minLength: 24)

            ShareDemoVideoView()
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("onboarding.page.share")
    }

    private var highlightedTitle: AttributedString {
        var prefix = AttributedString(L10n.text("onboarding.flow.share.title.prefix"))
        prefix.foregroundColor = Color.textMain

        var highlight = AttributedString(L10n.text("onboarding.flow.share.title.highlight"))
        highlight.foregroundColor = Color.accentPrimary

        var suffix = AttributedString(L10n.text("onboarding.flow.share.title.suffix"))
        suffix.foregroundColor = Color.textMain

        return prefix + highlight + suffix
    }
}

private struct ShareDemoVideoView: View {
    @StateObject private var loader = LoopingVideoLoader(resourceName: "share_extension_demo", ext: "mov")
    @State private var hasAppeared = false

    /// Cap the video at this height; width is derived from the natural aspect ratio.
    private let maxHeight: CGFloat = 560

    var body: some View {
        Group {
            if let player = loader.player, let aspect = loader.aspectRatio {
                VideoPlayerLayerView(player: player)
                    .aspectRatio(aspect, contentMode: .fit)
                    .frame(maxHeight: maxHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.shadowColor.opacity(0.45), radius: 14, x: 0, y: 8)
            } else {
                ProgressView()
                    .frame(height: 200)
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 8)
        .onAppear {
            loader.play()
            withAnimation(.easeOut(duration: 0.38)) {
                hasAppeared = true
            }
        }
        .onDisappear { loader.pause() }
    }
}

private struct VideoPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private final class PlayerContainerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

@MainActor
private final class LoopingVideoLoader: ObservableObject {
    @Published private(set) var player: AVPlayer?
    @Published private(set) var aspectRatio: CGFloat?
    private var loopObserver: NSObjectProtocol?

    init(resourceName: String, ext: String) {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: ext) else { return }
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .none
        self.player = player

        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }

        Task { [weak self] in
            do {
                let tracks = try await asset.loadTracks(withMediaType: .video)
                guard let track = tracks.first else { return }
                let size = try await track.load(.naturalSize)
                let transform = try await track.load(.preferredTransform)
                let applied = size.applying(transform)
                let w = abs(applied.width)
                let h = abs(applied.height)
                guard w > 0, h > 0 else { return }
                await MainActor.run {
                    self?.aspectRatio = w / h
                }
            } catch {
                // Leave aspectRatio nil; view falls back to a ProgressView.
            }
        }
    }

    func play() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        player?.seek(to: .zero)
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    deinit {
        if let loopObserver {
            NotificationCenter.default.removeObserver(loopObserver)
        }
    }
}

// MARK: - Shared visual helpers (reused by Hero)

private struct LaunchScreenWordmark: View {
    var body: some View {
        HStack(spacing: 0) {
            Text(verbatim: "Chill")
                .font(.custom("AvenirNext-DemiBold", size: 60))
                .foregroundColor(Color(red: 0.184, green: 0.525, blue: 1.0))

            Text(verbatim: "Note")
                .font(.custom("AvenirNext-HeavyItalic", size: 62))
                .foregroundColor(Color(red: 0.365, green: 0.569, blue: 0.961))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "ChillNote"))
    }
}

private struct FloatingIconCard: View {
    let icon: FloatingIcon
    let tint: Color
    let isActive: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isActive ? Color.white : Color.white.opacity(0.96))
                .frame(width: 52, height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isActive ? Color.accentPrimary.opacity(0.26) : Color.clear, lineWidth: 1)
                )
                .shadow(
                    color: isActive ? Color.accentPrimary.opacity(0.20) : Color.shadowColor.opacity(0.9),
                    radius: isActive ? 16 : 14,
                    x: 0,
                    y: isActive ? 8 : 6
                )

            switch icon {
            case .system(let name):
                Image(systemName: name)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(tint)
            case .youtube:
                YouTubeGlyph()
                    .frame(width: 23, height: 17)
            case .tiktok:
                TikTokGlyph()
                    .frame(width: 25, height: 27)
            case .reels:
                ReelsGlyph()
                    .frame(width: 25, height: 25)
            }
        }
        .scaleEffect(isActive ? 1.09 : 1)
        .accessibilityHidden(true)
        .animation(.spring(response: 0.34, dampingFraction: 0.76), value: isActive)
    }
}

private enum FloatingIcon {
    case system(name: String)
    case youtube
    case tiktok
    case reels
}

private struct HeroRingIcon: Identifiable {
    let id: String
    let icon: FloatingIcon
    let tint: Color
}

private struct YouTubeGlyph: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                .fill(Color(red: 1.0, green: 0.0, blue: 0.0))
            Image(systemName: "play.fill")
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: 1)
        }
    }
}

/// TikTok wordmark stand-in: a music note with the signature cyan/magenta offset.
private struct TikTokGlyph: View {
    var body: some View {
        ZStack {
            Image(systemName: "music.note")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(Color(red: 0.13, green: 0.93, blue: 0.95))
                .offset(x: -2, y: 2)
            Image(systemName: "music.note")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(Color(red: 1.0, green: 0.16, blue: 0.40))
                .offset(x: 2, y: -2)
            Image(systemName: "music.note")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(Color.black)
        }
    }
}

/// Instagram Reels stand-in: gradient camera + play triangle.
private struct ReelsGlyph: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.69, blue: 0.21), // amber
                            Color(red: 0.96, green: 0.27, blue: 0.45), // pink
                            Color(red: 0.61, green: 0.27, blue: 0.91)  // purple
                        ],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    )
                )
            Triangle()
                .fill(.white)
                .frame(width: 9, height: 11)
                .offset(x: 1)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    OnboardingFlowView(onFinish: {})
}
