import SwiftUI
import UIKit

struct OnboardingFlowView: View {
    let onFinish: () -> Void

    @State private var currentPage = 0
    private let initialPage: Int

    private let pages: [OnboardingPage] = [
        .positioning,
        .voiceFirst,
        .aiProcessing,
        .skillsWorkflow,
        .customSkills,
        .askNotes
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
            backgroundView

            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    onboardingPageView(for: page)
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 16)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: currentPage)
        }
        .background(Color.bgPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            onboardingActionBar
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 16)
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
    private func onboardingPageView(for page: OnboardingPage) -> some View {
        if page == .positioning {
            OnboardingHeroPage(currentPage: currentPage, totalPages: pages.count)
        } else if page == .voiceFirst {
            OnboardingVoiceFirstPage(currentPage: currentPage, totalPages: pages.count)
        } else if page == .aiProcessing {
            OnboardingAIProcessingPage(currentPage: currentPage, totalPages: pages.count)
        } else if page == .skillsWorkflow {
            OnboardingSkillsWorkflowPage(currentPage: currentPage, totalPages: pages.count)
        } else if page == .customSkills {
            OnboardingCustomSkillsPage(currentPage: currentPage, totalPages: pages.count)
        } else if page == .askNotes {
            OnboardingAskNotesPage(currentPage: currentPage, totalPages: pages.count)
        } else {
            OnboardingPlaceholderPage(
                page: page,
                currentPage: currentPage,
                totalPages: pages.count
            )
        }
    }

    private var backgroundView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.bgPrimary,
                    Color.white.opacity(0.96),
                    Color.brandBlueSoft.opacity(0.45)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.accentPrimary.opacity(0.08))
                .frame(width: 240, height: 240)
                .blur(radius: 14)
                .offset(x: 138, y: -270)

            Circle()
                .fill(Color.accentPrimary.opacity(0.07))
                .frame(width: 210, height: 210)
                .blur(radius: 18)
                .offset(x: -140, y: 320)
        }
    }

    private var onboardingActionBar: some View {
        HStack {
            Spacer(minLength: 0)

            Button {
                handlePrimaryAction()
            } label: {
                HStack(spacing: 8) {
                    Text(L10n.text(isLastPage ? "onboarding.flow.action.get_started" : "common.next"))
                        .font(.system(size: 16, weight: .semibold, design: .default))

                    if !isLastPage {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, isLastPage ? 22 : 20)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(Color.accentPrimary)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.accentPrimary.opacity(0.22), radius: 10, x: 0, y: 4)
            }
        }
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
    case positioning
    case voiceFirst
    case aiProcessing
    case skillsWorkflow
    case customSkills
    case askNotes

    var id: Int { rawValue }

    var titleKey: String {
        switch self {
        case .positioning:
            return "onboarding.flow.page1.title"
        case .voiceFirst:
            return "onboarding.flow.page2.title"
        case .aiProcessing:
            return "onboarding.flow.page3.title"
        case .skillsWorkflow:
            return "onboarding.flow.page4.title"
        case .customSkills:
            return "onboarding.flow.page5.title"
        case .askNotes:
            return "onboarding.flow.page6.title"
        }
    }

    var subtitleKey: String {
        switch self {
        case .positioning:
            return "onboarding.flow.page1.subtitle"
        case .voiceFirst:
            return "onboarding.flow.page2.subtitle"
        case .aiProcessing:
            return "onboarding.flow.page3.subtitle"
        case .skillsWorkflow:
            return "onboarding.flow.page4.subtitle"
        case .customSkills:
            return "onboarding.flow.page5.subtitle"
        case .askNotes:
            return "onboarding.flow.page6.subtitle"
        }
    }

    var placeholderIcon: String {
        switch self {
        case .positioning:
            return "sparkles"
        case .voiceFirst:
            return "waveform"
        case .aiProcessing:
            return "wand.and.stars"
        case .skillsWorkflow:
            return "square.stack.3d.up"
        case .customSkills:
            return "slider.horizontal.3"
        case .askNotes:
            return "bubble.left.and.text.bubble.right"
        }
    }
}

private struct OnboardingHeroPage: View {
    let currentPage: Int
    let totalPages: Int

    private let heroIcons: [HeroRingIcon] = [
        HeroRingIcon(
            id: "mail",
            icon: .system(name: "envelope.fill"),
            tint: Color(red: 0.35, green: 0.68, blue: 0.98),
            offset: CGSize(width: -114, height: -94)
        ),
        HeroRingIcon(
            id: "idea",
            icon: .system(name: "lightbulb.fill"),
            tint: Color(red: 0.98, green: 0.73, blue: 0.17),
            offset: CGSize(width: 0, height: -132)
        ),
        HeroRingIcon(
            id: "x",
            icon: .xBrand,
            tint: Color.textMain,
            offset: CGSize(width: 116, height: -88)
        ),
        HeroRingIcon(
            id: "youtube",
            icon: .youtube,
            tint: Color(red: 1.0, green: 0.23, blue: 0.19),
            offset: CGSize(width: 118, height: 82)
        ),
        HeroRingIcon(
            id: "todo",
            icon: .system(name: "checkmark.circle.fill"),
            tint: Color(red: 0.20, green: 0.72, blue: 0.37),
            offset: CGSize(width: 0, height: 138)
        ),
        HeroRingIcon(
            id: "sparkles",
            icon: .system(name: "sparkles"),
            tint: Color(red: 0.53, green: 0.42, blue: 0.97),
            offset: CGSize(width: -118, height: 82)
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LaunchScreenWordmark()
                .padding(.horizontal, 24)

            Text(L10n.text("onboarding.flow.page1.subtitle"))
                .font(.system(size: 32, weight: .bold, design: .default))
                .foregroundStyle(Color.textMain)
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 28)

            ZStack {
                Circle()
                    .stroke(Color.accentPrimary.opacity(0.06), lineWidth: 1)
                    .frame(width: 246, height: 246)

                Circle()
                    .stroke(Color.accentPrimary.opacity(0.08), lineWidth: 1)
                    .frame(width: 194, height: 194)

                Circle()
                    .fill(Color.accentPrimary.opacity(0.12))
                    .frame(width: 132, height: 132)
                    .blur(radius: 18)

                Circle()
                    .fill(Color.accentPrimary)
                    .frame(width: 104, height: 104)
                    .blur(radius: 0.4)
                    .opacity(0.18)
                    .offset(y: 10)

                Circle()
                    .fill(Color.bgPrimary)
                    .frame(width: 114, height: 114)
                    .overlay(
                        Circle()
                            .stroke(Color.accentPrimary.opacity(0.7), lineWidth: 2)
                    )
                    .overlay(
                        Image(systemName: "mic.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(Color.textMain)
                    )
                    .shadow(color: Color.accentPrimary.opacity(0.16), radius: 18, x: 0, y: 10)

                ForEach(heroIcons) { icon in
                    FloatingIconCard(icon: icon.icon, tint: icon.tint)
                        .offset(x: icon.offset.width, y: icon.offset.height)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)

            Spacer(minLength: 32)

            Spacer(minLength: 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 28)
        .accessibilityIdentifier("onboarding.page.0")
    }
}

private struct OnboardingPlaceholderPage: View {
    let page: OnboardingPage
    let currentPage: Int
    let totalPages: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color.accentPrimary.opacity(0.1))
                        .frame(width: 92, height: 92)

                    Image(systemName: page.placeholderIcon)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Color.accentPrimary)
                }

                Text(L10n.text(page.titleKey))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textMain)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L10n.text(page.subtitleKey))
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.textMain.opacity(0.64))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)

            Spacer()

            Spacer(minLength: 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 28)
        .accessibilityIdentifier("onboarding.page.\(page.id)")
    }
}

private struct OnboardingVoiceFirstPage: View {
    let currentPage: Int
    let totalPages: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.text("onboarding.flow.page2.title"))
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundStyle(Color.textMain)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L10n.text("onboarding.flow.page2.subtitle"))
                    .font(.system(size: 20, weight: .semibold, design: .default))
                    .foregroundStyle(Color.accentPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 38)

            Spacer(minLength: 34)

            VoiceVsTypingCard()
                .padding(.horizontal, 6)

            Spacer(minLength: 28)

            VoiceFirstCalloutBubble()
                .frame(maxWidth: .infinity)

            Spacer(minLength: 34)

            Spacer(minLength: 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 4)
        .accessibilityIdentifier("onboarding.page.1")
    }
}

private struct VoiceVsTypingCard: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white.opacity(0.92))
                .shadow(color: Color.shadowColor.opacity(0.8), radius: 18, x: 0, y: 10)

            HStack(spacing: 0) {
                voicePanelBackground
                typingPanelBackground
            }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

            VStack(spacing: 18) {
                HStack(alignment: .center, spacing: 0) {
                    voiceIcon
                    typingIcon
                }

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    comparisonLabel("onboarding.flow.page2.comparison.voice")
                    comparisonLabel("onboarding.flow.page2.comparison.typing")
                }

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    comparisonMetric("4x", color: Color.accentPrimary)
                    comparisonMetric("1x", color: Color.textSub.opacity(0.72))
                }

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    comparisonCaption("onboarding.flow.page2.comparison.voice.caption")
                    comparisonCaption("onboarding.flow.page2.comparison.typing.caption")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)

            Text(L10n.text("onboarding.flow.page2.comparison.vs"))
                .font(.system(size: 14, weight: .bold, design: .default))
                .foregroundStyle(Color.textSub)
                .padding(10)
                .background(Circle().fill(Color.white.opacity(0.96)))
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.04), lineWidth: 1)
                )
        }
        .frame(height: 288)
    }

    private var voicePanelBackground: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.accentPrimary.opacity(0.10),
                        Color(red: 0.47, green: 0.39, blue: 1.0).opacity(0.14)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var typingPanelBackground: some View {
        Rectangle()
            .fill(Color.black.opacity(0.02))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var voiceIcon: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentPrimary.opacity(0.98),
                            Color(red: 0.42, green: 0.31, blue: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 88, height: 88)
                .shadow(color: Color.accentPrimary.opacity(0.28), radius: 18, x: 0, y: 10)

            Image(systemName: "waveform")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)

            HStack(spacing: 18) {
                ForEach([-1, 1], id: \.self) { direction in
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.accentPrimary.opacity(0.48))
                        .scaleEffect(x: CGFloat(direction), y: 1)
                        .offset(x: CGFloat(direction) * 52)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var typingIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.78))
                .frame(width: 104, height: 72)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )

            KeyboardGlyph()
                .frame(width: 64, height: 40)
        }
        .frame(maxWidth: .infinity)
    }

    private func comparisonLabel(_ key: String) -> some View {
        Text(L10n.text(key))
            .font(.system(size: 20, weight: .semibold, design: .default))
            .foregroundStyle(Color.textMain)
            .frame(maxWidth: .infinity)
    }

    private func comparisonMetric(_ text: String, color: Color) -> some View {
        Text(verbatim: text)
            .font(.system(size: 44, weight: .bold, design: .default))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
    }

    private func comparisonCaption(_ key: String) -> some View {
        Text(L10n.text(key))
            .font(.system(size: 18, weight: .medium, design: .default))
            .foregroundStyle(Color.textSub)
            .frame(maxWidth: .infinity)
    }
}

private struct VoiceFirstCalloutBubble: View {
    var body: some View {
        Text(L10n.text("onboarding.flow.page2.callout"))
            .font(.system(size: 17, weight: .medium, design: .default))
            .foregroundStyle(Color.textMain)
            .lineSpacing(4)
            .multilineTextAlignment(.center)
            .frame(width: 248, alignment: .center)
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.accentPrimary.opacity(0.08))
            )
            .overlay(alignment: .bottomLeading) {
                BubbleTail()
                    .fill(Color.accentPrimary.opacity(0.08))
                    .frame(width: 18, height: 14)
                    .offset(x: 14, y: 10)
            }
    }
}

private struct KeyboardGlyph: View {
    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Color.textSub.opacity(0.38))
                            .frame(width: 6, height: 6)
                    }
                }
            }
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.textSub.opacity(0.38))
                .frame(width: 40, height: 6)
                .padding(.top, 2)
        }
    }
}

private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.25))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.maxY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX, y: rect.maxY * 0.55)
        )
        path.closeSubpath()
        return path
    }
}

private struct OnboardingAIProcessingPage: View {
    let currentPage: Int
    let totalPages: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.text("onboarding.flow.page3.title"))
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundStyle(Color.textMain)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L10n.text("onboarding.flow.page3.subtitle"))
                    .font(.system(size: 20, weight: .semibold, design: .default))
                    .foregroundStyle(Color.accentPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 38)

            Spacer(minLength: 22)

            AIProcessingCard()

            Spacer(minLength: 50)

            Spacer(minLength: 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 4)
        .accessibilityIdentifier("onboarding.page.2")
    }
}

private struct OnboardingSkillsWorkflowPage: View {
    let currentPage: Int
    let totalPages: Int

    private var isCompactHeight: Bool {
        UIScreen.main.bounds.height <= 700
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.text("onboarding.flow.page4.title"))
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundStyle(Color.textMain)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L10n.text("onboarding.flow.page4.subtitle"))
                    .font(.system(size: 20, weight: .semibold, design: .default))
                    .foregroundStyle(Color.accentPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, isCompactHeight ? 14 : 38)

            Spacer(minLength: isCompactHeight ? 16 : 32)

            SkillsWorkflowGrid(isCompactHeight: isCompactHeight)

            Spacer(minLength: isCompactHeight ? 18 : 30)

            VStack(spacing: 12) {
                MoreSkillsBadgeStack()

                Text(L10n.text("onboarding.flow.page4.hint"))
                    .font(.system(size: 17, weight: .semibold, design: .default))
                    .foregroundStyle(Color.textSub)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 260, alignment: .center)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Spacer(minLength: isCompactHeight ? 18 : 34)

            Spacer(minLength: isCompactHeight ? 16 : 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 4)
        .accessibilityIdentifier("onboarding.page.3")
    }
}

private struct OnboardingCustomSkillsPage: View {
    let currentPage: Int
    let totalPages: Int

    private var isCompactHeight: Bool {
        UIScreen.main.bounds.height <= 700
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.text("onboarding.flow.page5.title"))
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundStyle(Color.textMain)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L10n.text("onboarding.flow.page5.subtitle"))
                    .font(.system(size: 20, weight: .semibold, design: .default))
                    .foregroundStyle(Color.accentPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, isCompactHeight ? 14 : 38)

            Spacer(minLength: isCompactHeight ? 14 : 26)

            CustomSkillsPreviewCard(isCompactHeight: isCompactHeight)
                .padding(.horizontal, 10)

            Spacer(minLength: isCompactHeight ? 16 : 24)

            CustomSkillsCalloutBubble()
                .frame(maxWidth: .infinity)

            Spacer(minLength: isCompactHeight ? 18 : 34)

            Spacer(minLength: isCompactHeight ? 16 : 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 4)
        .accessibilityIdentifier("onboarding.page.4")
    }
}

private struct CustomSkillsPreviewCard: View {
    let isCompactHeight: Bool

    private let items: [CustomSkillPreviewItem] = [
        .init(
            icon: .system(name: "music.note.tv"),
            iconTint: Color(red: 0.22, green: 0.56, blue: 0.99),
            iconBackground: Color(red: 0.22, green: 0.56, blue: 0.99).opacity(0.12),
            titleKey: "onboarding.flow.page5.skill.newsletter"
        ),
        .init(
            icon: .system(name: "play.rectangle.fill"),
            iconTint: Color(red: 0.22, green: 0.67, blue: 0.41),
            iconBackground: Color(red: 0.22, green: 0.67, blue: 0.41).opacity(0.12),
            titleKey: "onboarding.flow.page5.skill.sales_followup"
        ),
        .init(
            icon: .system(name: "quote.bubble.fill"),
            iconTint: Color(red: 0.97, green: 0.49, blue: 0.19),
            iconBackground: Color(red: 0.97, green: 0.49, blue: 0.19).opacity(0.12),
            titleKey: "onboarding.flow.page5.skill.case_brief"
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.text("recipes.section.my_skills"))
                .font(.system(size: 18, weight: .bold, design: .default))
                .foregroundStyle(Color.textMain)

            VStack(spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    CustomSkillRow(item: item)
                }
            }

            HStack(spacing: 12) {
                ZStack {
                    Color.clear
                        .frame(width: 28, height: 28)

                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                }

                Text(L10n.text("onboarding.flow.page5.create_action"))
                    .font(.system(size: 17, weight: .semibold, design: .default))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(Color.accentPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .padding(.top, 2)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, isCompactHeight ? 14 : 18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
                .shadow(color: Color.shadowColor.opacity(0.55), radius: 16, x: 0, y: 8)
        )
    }
}

private struct CustomSkillRow: View {
    let item: CustomSkillPreviewItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(item.iconBackground)
                    .frame(width: 28, height: 28)

                switch item.icon {
                case .system(let name):
                    Image(systemName: name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(item.iconTint)
                case .emoji(let value):
                    Text(verbatim: value)
                        .font(.system(size: 15))
                }
            }

            Text(L10n.text(item.titleKey))
                .font(.system(size: 17, weight: .medium, design: .default))
                .foregroundStyle(Color.textMain)
                .lineLimit(2)
                .layoutPriority(1)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
        )
    }
}

private struct CustomSkillsCalloutBubble: View {
    var body: some View {
        Text(L10n.text("onboarding.flow.page5.callout"))
            .font(.system(size: 17, weight: .medium, design: .default))
            .foregroundStyle(Color.textMain)
            .lineSpacing(4)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 272, alignment: .center)
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.accentPrimary.opacity(0.08))
            )
            .overlay(alignment: .bottomLeading) {
                BubbleTail()
                    .fill(Color.accentPrimary.opacity(0.08))
                    .frame(width: 18, height: 14)
                    .offset(x: 14, y: 10)
            }
    }
}

private struct CustomSkillPreviewItem {
    let icon: CustomSkillPreviewIcon
    let iconTint: Color
    let iconBackground: Color
    let titleKey: String
}

private enum CustomSkillPreviewIcon {
    case system(name: String)
    case emoji(String)
}

private struct OnboardingAskNotesPage: View {
    let currentPage: Int
    let totalPages: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.text("onboarding.flow.page6.title"))
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundStyle(Color.textMain)
                    .lineSpacing(2)
                    .frame(maxWidth: 276, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L10n.text("onboarding.flow.page6.subtitle"))
                    .font(.system(size: 20, weight: .semibold, design: .default))
                    .foregroundStyle(Color.accentPrimary)
                    .frame(maxWidth: 282, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 46)

            Spacer(minLength: 26)

            AskNotesQuestionBubble()
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 6)

            Spacer(minLength: 14)

            AskNotesAnswerCard()
                .padding(.trailing, 20)

            Spacer(minLength: 28)

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 4)
        .accessibilityIdentifier("onboarding.page.5")
    }
}

private struct AskNotesQuestionBubble: View {
    var body: some View {
        Text(L10n.text("onboarding.flow.page6.question"))
            .font(.system(size: 17, weight: .medium, design: .default))
            .foregroundStyle(.white)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 260, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.34, green: 0.59, blue: 0.98),
                                Color(red: 0.40, green: 0.58, blue: 0.94)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(alignment: .bottomTrailing) {
                BubbleTail()
                    .fill(Color(red: 0.40, green: 0.58, blue: 0.94))
                    .frame(width: 18, height: 14)
                    .scaleEffect(x: -1, y: 1)
                    .offset(x: -12, y: 9)
            }
    }
}

private struct AskNotesAnswerCard: View {
    private let bulletKeys = [
        "onboarding.flow.page6.answer.bullet1",
        "onboarding.flow.page6.answer.bullet2",
        "onboarding.flow.page6.answer.bullet3",
        "onboarding.flow.page6.answer.bullet4"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentPrimary)
                    .padding(.top, 2)

                Text(L10n.text("onboarding.flow.page6.answer.intro"))
                    .font(.system(size: 17, weight: .medium, design: .default))
                    .foregroundStyle(Color.textMain)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(bulletKeys, id: \.self) { key in
                    HStack(alignment: .top, spacing: 8) {
                        Text(verbatim: "•")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Color.textMain)

                        Text(L10n.text(key))
                            .font(.system(size: 17, weight: .regular, design: .default))
                            .foregroundStyle(Color.textMain)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, 18)
            .padding(.leading, 31)

            Divider()
                .overlay(Color.black.opacity(0.06))
                .padding(.top, 20)
                .padding(.horizontal, 14)

            Text(L10n.text("onboarding.flow.page6.answer.followup"))
                .font(.system(size: 17, weight: .medium, design: .default))
                .foregroundStyle(Color.accentPrimary)
                .lineSpacing(4)
                .padding(.top, 18)
                .padding(.leading, 14)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
                .shadow(color: Color.shadowColor.opacity(0.42), radius: 14, x: 0, y: 8)
        )
    }
}

private struct SkillsWorkflowGrid: View {
    let isCompactHeight: Bool

    private let columns = [
        GridItem(.flexible(minimum: 0), spacing: 10),
        GridItem(.flexible(minimum: 0), spacing: 10)
    ]

    private let items: [SkillsWorkflowItem] = [
        .init(
            icon: .emoji("🎣"),
            titleKey: "agent_recipe.hook_generator.name",
            detailKey: "onboarding.flow.page4.card.advocate.detail"
        ),
        .init(
            icon: .emoji("📣"),
            titleKey: "agent_recipe.caption_pack.name",
            detailKey: "onboarding.flow.page4.card.brainstorm.detail"
        ),
        .init(
            icon: .emoji("📈"),
            titleKey: "agent_recipe.why_viral.name",
            detailKey: "onboarding.flow.page4.card.translate.detail"
        ),
        .init(
            icon: .emoji("✍️"),
            titleKey: "agent_recipe.humanizer.name",
            detailKey: "onboarding.flow.page4.card.publish.detail"
        )
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                SkillsWorkflowCard(item: item, isCompactHeight: isCompactHeight)
            }
        }
    }
}

private struct SkillsWorkflowCard: View {
    let item: SkillsWorkflowItem
    let isCompactHeight: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: isCompactHeight ? 8 : 0) {
            switch item.icon {
            case .emoji(let value):
                Text(verbatim: value)
                    .font(.system(size: isCompactHeight ? 25 : 29))
            case .system(let name):
                Image(systemName: name)
                    .font(.system(size: isCompactHeight ? 24 : 28, weight: .semibold))
                    .foregroundStyle(Color(red: 0.26, green: 0.50, blue: 0.97))
            }

            Spacer(minLength: isCompactHeight ? 6 : 18)

            Text(L10n.text(item.titleKey))
                .font(.system(size: 17, weight: .semibold, design: .default))
                .foregroundStyle(Color.textMain)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: isCompactHeight ? 2 : 8)

            Text(L10n.text(item.detailKey))
                .font(.system(size: 15, weight: .regular, design: .default))
                .foregroundStyle(Color.textSub)
                .lineSpacing(3)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, isCompactHeight ? 12 : 16)
        .frame(maxWidth: .infinity, minHeight: isCompactHeight ? 154 : 176, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
                .shadow(color: Color.shadowColor.opacity(0.5), radius: 14, x: 0, y: 8)
        )
    }
}

private struct SkillsWorkflowItem {
    let icon: SkillsWorkflowIcon
    let titleKey: String
    let detailKey: String
}

private enum SkillsWorkflowIcon {
    case emoji(String)
    case system(name: String)
}

private struct MoreSkillsBadgeStack: View {
    private let extraSkillIcons = ["📝", "🧩", "✅", "🪄", "✉️"]

    var body: some View {
        HStack(spacing: -10) {
            ForEach(Array(extraSkillIcons.enumerated()), id: \.offset) { _, icon in
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.98))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )
                        .shadow(color: Color.shadowColor.opacity(0.35), radius: 8, x: 0, y: 4)

                    Text(verbatim: icon)
                        .font(.system(size: 21))
                }
            }
        }
        .padding(.leading, 10)
    }
}

private struct AIProcessingCard: View {
    private let items: [AIProcessingItem] = [
        .init(
            icon: .system(name: "checkmark.circle.fill"),
            iconTint: Color(red: 0.23, green: 0.78, blue: 0.42),
            iconBackground: Color(red: 0.23, green: 0.78, blue: 0.42).opacity(0.14),
            titleKey: "onboarding.flow.page3.bullet.todos",
            detailKey: "onboarding.flow.page3.detail.todos"
        ),
        .init(
            icon: .system(name: "sparkles"),
            iconTint: Color(red: 0.43, green: 0.31, blue: 0.99),
            iconBackground: Color(red: 0.43, green: 0.31, blue: 0.99).opacity(0.12),
            titleKey: "onboarding.flow.page3.bullet.filler",
            detailKey: "onboarding.flow.page3.detail.filler"
        ),
        .init(
            icon: .text("Aa"),
            iconTint: Color.accentPrimary,
            iconBackground: Color.accentPrimary.opacity(0.12),
            titleKey: "onboarding.flow.page3.bullet.grammar",
            detailKey: "onboarding.flow.page3.detail.grammar"
        ),
        .init(
            icon: .system(name: "list.bullet"),
            iconTint: Color(red: 1.0, green: 0.50, blue: 0.12),
            iconBackground: Color(red: 1.0, green: 0.50, blue: 0.12).opacity(0.12),
            titleKey: "onboarding.flow.page3.bullet.format",
            detailKey: "onboarding.flow.page3.detail.format"
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                AIProcessingRow(item: item)

                if index < items.count - 1 {
                    Rectangle()
                        .fill(Color.black.opacity(0.06))
                        .frame(height: 1)
                        .padding(.leading, 56)
                }
            }
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.94))
                .shadow(color: Color.shadowColor.opacity(0.75), radius: 20, x: 0, y: 10)
        )
    }
}

private struct AIProcessingRow: View {
    let item: AIProcessingItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(item.iconBackground)
                    .frame(width: 32, height: 32)

                switch item.icon {
                case .system(let name):
                    Image(systemName: name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(item.iconTint)
                case .text(let value):
                    Text(verbatim: value)
                        .font(.system(size: 15, weight: .bold, design: .default))
                        .foregroundStyle(item.iconTint)
                case .xBrand, .youtube:
                    EmptyView()
                }
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 7) {
                Text(L10n.text(item.titleKey))
                    .font(.system(size: 19, weight: .semibold, design: .default))
                    .foregroundStyle(Color.textMain)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L10n.text(item.detailKey))
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundStyle(Color.textSub)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 22)
    }
}

private struct AIProcessingItem {
    let icon: FloatingIcon
    let iconTint: Color
    let iconBackground: Color
    let titleKey: String
    let detailKey: String
}

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
        .accessibilityLabel(Text(L10n.text("auth.login.brand_title")))
    }
}

private struct FloatingIconCard: View {
    let icon: FloatingIcon
    let tint: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.96))
                .frame(width: 56, height: 56)
                .shadow(color: Color.shadowColor.opacity(0.9), radius: 16, x: 0, y: 8)

            switch icon {
            case .system(let name):
                Image(systemName: name)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tint)
            case .text(let value):
                Text(verbatim: value)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
            case .xBrand:
                Text(verbatim: "X")
                    .font(.sfProDisplay(size: 22, weight: .black))
                    .foregroundStyle(tint)
            case .youtube:
                YouTubeGlyph()
                    .frame(width: 24, height: 18)
            }
        }
        .accessibilityHidden(true)
    }
}

private enum FloatingIcon {
    case system(name: String)
    case text(String)
    case xBrand
    case youtube
}

private struct HeroRingIcon: Identifiable {
    let id: String
    let icon: FloatingIcon
    let tint: Color
    let offset: CGSize
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

private extension Font {
    static func sfProDisplay(size: CGFloat, weight: UIFont.Weight) -> Font {
        if let customFont = UIFont.systemFont(ofSize: size, weight: weight) as UIFont? {
            return .custom(customFont.fontName, size: size)
        }

        switch weight {
        case .bold, .heavy, .black:
            return .system(size: size, weight: .bold, design: .default)
        case .semibold, .medium:
            return .system(size: size, weight: .semibold, design: .default)
        default:
            return .system(size: size, weight: .regular, design: .default)
        }
    }
}

#Preview {
    OnboardingFlowView(onFinish: {})
}
