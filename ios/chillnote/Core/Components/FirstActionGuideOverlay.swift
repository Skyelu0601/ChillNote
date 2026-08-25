import SwiftUI
import UIKit

enum FirstActionGuideTarget: Hashable {
    case importedNote(UUID)
    case createTab
    case aiSkills
    case recordTab
    case teleprompter
}

struct FirstActionGuideSpotlightConfiguration {
    let target: FirstActionGuideTarget
    let message: String
    let step: Int
    let totalSteps: Int = 7
}

private struct FirstActionGuideTargetPreferenceKey: PreferenceKey {
    static var defaultValue: [FirstActionGuideTarget: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [FirstActionGuideTarget: Anchor<CGRect>],
        nextValue: () -> [FirstActionGuideTarget: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

extension View {
    func firstActionGuideTarget(_ target: FirstActionGuideTarget?) -> some View {
        anchorPreference(key: FirstActionGuideTargetPreferenceKey.self, value: .bounds) { anchor in
            guard let target else { return [:] }
            return [target: anchor]
        }
    }

    func firstActionGuideSpotlight(
        configuration: FirstActionGuideSpotlightConfiguration?,
        onSkip: @escaping () -> Void
    ) -> some View {
        overlayPreferenceValue(FirstActionGuideTargetPreferenceKey.self) { anchors in
            GeometryReader { proxy in
                if let configuration,
                   let anchor = anchors[configuration.target] {
                    FirstActionGuideSpotlight(
                        targetRect: proxy[anchor],
                        message: configuration.message,
                        step: configuration.step,
                        totalSteps: configuration.totalSteps,
                        containerSize: proxy.size,
                        onSkip: onSkip
                    )
                }
            }
        }
    }
}

struct FirstActionSharePromptView: View {
    let onStart: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: BrandTokens.Space.s2) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text("onboarding.first_action.step_progress", Int64(1), Int64(7)))
                        .font(.chillCaption.weight(.bold))
                        .foregroundStyle(Color.accentPrimary)

                    Text(L10n.text("onboarding.first_action.share.title"))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.textMain)
                }

                Spacer(minLength: 0)

                Button(action: onSkip) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.textSub)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.text("common.skip"))
            }

            shareInstructions

            Button(action: onStart) {
                HStack(spacing: 7) {
                    Text(L10n.text("onboarding.first_action.share.action"))
                        .font(.bodySmall.weight(.bold))

                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.tactile)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: BrandTokens.Radius.card, style: .continuous)
                .fill(Color.cardBackground)
        )
        .overlay {
            RoundedRectangle(cornerRadius: BrandTokens.Radius.card, style: .continuous)
                .stroke(Color.borderSubtle, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
        .accessibilityElement(children: .contain)
    }

    private var shareInstructions: some View {
        VStack(alignment: .leading, spacing: 0) {
            instructionRow(
                icon: "square.and.arrow.up",
                iconColor: .accentPrimary,
                iconBackground: .selectionHighlight,
                text: L10n.text("onboarding.first_action.share.instruction_share")
            )

            Rectangle()
                .fill(Color.separator)
                .frame(width: 1, height: 10)
                .padding(.leading, 22)

            instructionRow(
                icon: "archivebox",
                iconColor: .textMain,
                iconBackground: .bgPrimary,
                text: L10n.text("onboarding.first_action.share.instruction_choose")
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.text("onboarding.first_action.share.message"))
    }

    private func instructionRow(
        icon: String,
        iconColor: Color,
        iconBackground: Color,
        text: String
    ) -> some View {
        HStack(spacing: BrandTokens.Space.s3) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 44, height: 44)
                .background(iconBackground)
                .clipShape(Circle())
                .accessibilityHidden(true)

            Text(text)
                .font(.bodySmall.weight(.medium))
                .foregroundStyle(Color.textMain)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct FirstActionTranscriptReviewPromptView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: BrandTokens.Space.s2) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text("onboarding.first_action.step_progress", Int64(3), Int64(7)))
                        .font(.chillCaption.weight(.bold))
                        .foregroundStyle(Color.accentPrimary)

                    Text(L10n.text("onboarding.first_action.transcript_review.title"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.textMain)
                }

                Spacer(minLength: 0)

                Button(action: onSkip) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.textSub)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.text("common.skip"))
            }

            Button(action: onContinue) {
                HStack(spacing: 7) {
                    Text(L10n.text("onboarding.first_action.transcript_review.action"))
                        .font(.bodySmall.weight(.bold))

                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.tactile)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: BrandTokens.Radius.card, style: .continuous)
                .fill(Color.cardBackground)
        )
        .overlay {
            RoundedRectangle(cornerRadius: BrandTokens.Radius.card, style: .continuous)
                .stroke(Color.borderSubtle, lineWidth: 1)
        }
        .brandShadow(BrandTokens.Shadow.card)
        .accessibilityElement(children: .contain)
    }
}

private struct FirstActionGuideSpotlight: View {
    let targetRect: CGRect
    let message: String
    let step: Int
    let totalSteps: Int
    let containerSize: CGSize
    let onSkip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    private var expandedTargetRect: CGRect {
        let expansion: CGFloat = step == 2 ? 8 : 5
        return targetRect.insetBy(dx: -expansion, dy: -expansion)
    }

    private var bubblePosition: CGPoint {
        let bubbleHalfHeight: CGFloat = 47
        let bubbleHalfWidth = bubbleWidth / 2
        let spacing: CGFloat = 18
        let belowY = expandedTargetRect.maxY + spacing + bubbleHalfHeight
        let aboveY = expandedTargetRect.minY - spacing - bubbleHalfHeight
        let preferredY = belowY <= containerSize.height - 32 ? belowY : aboveY
        let clampedX = min(
            max(expandedTargetRect.midX, bubbleHalfWidth + 16),
            containerSize.width - bubbleHalfWidth - 16
        )
        return CGPoint(x: clampedX, y: max(70, preferredY))
    }

    private var bubbleWidth: CGFloat {
        let availableWidth = containerSize.width - 32
        let preferredWidth: CGFloat

        switch step {
        case 3:
            preferredWidth = 286
        case 4:
            preferredWidth = 310
        default:
            preferredWidth = 340
        }

        return min(preferredWidth, availableWidth)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            dimmingLayer
                .allowsHitTesting(false)

            RoundedRectangle(cornerRadius: spotlightCornerRadius, style: .continuous)
                .stroke(Color.accentPrimary, lineWidth: 3)
                .frame(width: expandedTargetRect.width, height: expandedTargetRect.height)
                .scaleEffect(isPulsing ? 1.025 : 1)
                .shadow(color: Color.accentPrimary.opacity(0.45), radius: 12)
                .position(x: expandedTargetRect.midX, y: expandedTargetRect.midY)
                .allowsHitTesting(false)

            guideBubble
                .position(bubblePosition)
                .allowsHitTesting(false)

            Button(L10n.text("common.skip"), action: onSkip)
                .font(.bodySmall.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(Color.black.opacity(0.5))
                .clipShape(Capsule())
                .padding(.trailing, 16)
                .padding(.bottom, 24)
        }
        .onAppear {
            UIAccessibility.post(notification: .announcement, argument: message)
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.75).repeatCount(2, autoreverses: true)) {
                isPulsing = true
            }
        }
    }

    private var spotlightCornerRadius: CGFloat {
        switch step {
        case 2:
            return BrandTokens.Radius.card
        default:
            return BrandTokens.Radius.pill
        }
    }

    private var dimmingLayer: some View {
        Color.black.opacity(0.42)
            .mask {
                Rectangle()
                    .overlay {
                        RoundedRectangle(cornerRadius: spotlightCornerRadius, style: .continuous)
                            .frame(width: expandedTargetRect.width, height: expandedTargetRect.height)
                            .position(x: expandedTargetRect.midX, y: expandedTargetRect.midY)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
            }
    }

    private var guideBubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.text("onboarding.first_action.step_progress", Int64(step), Int64(totalSteps)))
                .font(.chillCaption.weight(.bold))
                .foregroundStyle(Color.accentPrimary)

            Text(message)
                .font(.bodySmall.weight(.semibold))
                .foregroundStyle(Color.textMain)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, BrandTokens.Space.s3)
        .padding(.vertical, BrandTokens.Space.s2)
        .frame(width: bubbleWidth, alignment: .leading)
        .frame(minHeight: 64, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: BrandTokens.Radius.button, style: .continuous)
                .fill(Color.cardBackground)
        )
        .brandShadow(BrandTokens.Shadow.card)
    }
}

#if DEBUG
struct FirstActionGuideSpotlightDesignPreview: View {
    var body: some View {
        VStack(spacing: 0) {
            NoteDetailWorkspacePicker(
                selection: .script,
                isCreateEnabled: true,
                guideRequiredPage: .create,
                guideTarget: .createTab,
                onSelect: { _ in }
            )

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary.ignoresSafeArea())
        .firstActionGuideSpotlight(
            configuration: FirstActionGuideSpotlightConfiguration(
                target: .createTab,
                message: L10n.text("onboarding.first_action.create_tab"),
                step: 4
            ),
            onSkip: {}
        )
    }
}
#endif
