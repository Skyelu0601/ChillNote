import SwiftUI

struct ShareView: View {
    @ObservedObject var viewModel: ShareViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.24)
                .ignoresSafeArea()

            ShareBottomSheetContent(viewModel: viewModel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .ignoresSafeArea()
        .task {
            await viewModel.start()
        }
    }
}

private struct ShareBottomSheetContent: View {
    @ObservedObject var viewModel: ShareViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Capsule(style: .continuous)
                .fill(Color(.systemGray4))
                .frame(width: 58, height: 6)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)

            ShareHeaderView(
                sourceName: viewModel.sourceName,
                platformID: viewModel.sourcePlatformID
            )

            ShareStatusView(
                statusText: viewModel.statusText,
                stage: viewModel.stage,
                progress: viewModel.visualProgress,
                platformID: viewModel.sourcePlatformID,
                isCompleted: viewModel.isCompleted,
                errorMessage: viewModel.errorMessage
            )
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 34)
        .frame(maxWidth: .infinity, minHeight: 560, alignment: .topLeading)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 34,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 34,
                style: .continuous
            )
            .fill(Color(.systemBackground))
        )
        .background(alignment: .bottom) {
            Color(.systemBackground)
                .frame(height: 96)
                .ignoresSafeArea(edges: .bottom)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

private struct ShareHeaderView: View {
    let sourceName: String
    let platformID: String

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(ShareL10n.text("share_extension.title"))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            Spacer(minLength: 10)

            SourcePill(sourceName: sourceName, platformID: platformID)
        }
    }
}

private struct SourcePill: View {
    let sourceName: String
    let platformID: String

    private var tint: Color {
        ShareSourceStyle.tint(for: platformID)
    }

    var body: some View {
        Text(ShareL10n.text("share_extension.source_format", sourceName))
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(tint.opacity(0.28), lineWidth: 1)
            )
    }
}

private struct ShareStatusView: View {
    let statusText: String
    let stage: ShareImportStage
    let progress: Double
    let platformID: String
    let isCompleted: Bool
    let errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            if isCompleted {
                VStack(spacing: 14) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60, weight: .semibold))
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, value: isCompleted)
                        .accessibilityHidden(true)

                    Text(statusText)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 170, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    TranscriptTypingAnimation(
                        stage: stage,
                        tint: ShareSourceStyle.tint(for: platformID)
                    )

                    Text(statusText)
                        .font(.system(size: 21, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    AnimatedShareProgressBar(
                        progress: progress,
                        tint: ShareSourceStyle.tint(for: platformID)
                    )

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 288, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct TranscriptTypingAnimation: View {
    let stage: ShareImportStage
    let tint: Color

    @State private var shimmerPhase = false
    @State private var typingPhase = false
    @State private var savedPulse = false

    private let lineWidths: [CGFloat] = [0.78, 0.56, 0.88, 0.64]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)

            VStack(spacing: 14) {
                animationHeader

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(lineWidths.enumerated()), id: \.offset) { index, width in
                        TranscriptLine(
                            stage: stage,
                            widthRatio: width,
                            index: index,
                            tint: tint,
                            shimmerPhase: shimmerPhase,
                            typingPhase: typingPhase
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 132)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onAppear(perform: startAnimations)
        .onChange(of: stage) { _, _ in
            startAnimations()
        }
        .accessibilityHidden(true)
    }

    private var animationHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 30, height: 30)

                Image(systemName: headerIconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .scaleEffect(stage == .saving && savedPulse ? 1.08 : 1.0)
                    .animation(.spring(response: 0.34, dampingFraction: 0.7), value: savedPulse)
            }

            Capsule(style: .continuous)
                .fill(tint.opacity(stage == .extractingTranscript ? 0.22 : 0.12))
                .frame(width: stage == .saving ? 58 : 96, height: 8)
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: stage)

            Spacer(minLength: 0)

            if stage == .saving {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.top, 18)
        .padding(.horizontal, 18)
    }

    private var headerIconName: String {
        switch stage {
        case .readingContent:
            return "play.rectangle.fill"
        case .extractingTranscript:
            return "text.line.first.and.arrowtriangle.forward"
        case .saving, .completed:
            return "note.text"
        }
    }

    private func startAnimations() {
        shimmerPhase = false
        typingPhase = false
        savedPulse = false

        withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
            shimmerPhase = true
        }

        withAnimation(.easeInOut(duration: stage == .extractingTranscript ? 1.35 : 0.7).repeatForever(autoreverses: true)) {
            typingPhase = true
        }

        if stage == .saving {
            withAnimation(.easeInOut(duration: 0.42).repeatForever(autoreverses: true)) {
                savedPulse = true
            }
        }
    }
}

private struct TranscriptLine: View {
    let stage: ShareImportStage
    let widthRatio: CGFloat
    let index: Int
    let tint: Color
    let shimmerPhase: Bool
    let typingPhase: Bool

    private var activeRatio: CGFloat {
        switch stage {
        case .readingContent:
            return 0
        case .extractingTranscript:
            let base = typingPhase ? 0.96 : 0.34
            let stagger = CGFloat(index) * 0.12
            return min(max(CGFloat(base) - stagger, 0.18), 1)
        case .saving, .completed:
            return 1
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let lineWidth = geometry.size.width * widthRatio
            let fillWidth = max(lineWidth * activeRatio, stage == .readingContent ? 0 : 12)

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color(.systemGray4).opacity(stage == .saving ? 0.42 : 0.72))
                    .frame(width: lineWidth, height: 8)

                if stage == .readingContent {
                    MovingLineHighlight(shimmerPhase: shimmerPhase)
                        .frame(width: lineWidth, height: 8)
                        .clipShape(Capsule(style: .continuous))
                        .opacity(0.82)
                } else {
                    Capsule(style: .continuous)
                        .fill(tint.opacity(stage == .saving ? 0.42 : 0.76))
                        .frame(width: fillWidth, height: 8)
                        .animation(
                            .easeInOut(duration: stage == .extractingTranscript ? 0.95 : 0.28)
                            .delay(Double(index) * 0.08),
                            value: activeRatio
                        )

                    if stage == .extractingTranscript {
                        Capsule(style: .continuous)
                            .fill(tint)
                            .frame(width: 6, height: 12)
                            .offset(x: min(fillWidth, lineWidth) + 3)
                            .opacity(typingPhase ? 0.95 : 0.25)
                            .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: typingPhase)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 8)
        .scaleEffect(stage == .saving ? 0.96 : 1, anchor: .leading)
        .opacity(stage == .saving ? 0.82 : 1)
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: stage)
    }
}

private struct MovingLineHighlight: View {
    let shimmerPhase: Bool

    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [
                    .white.opacity(0),
                    .white.opacity(0.55),
                    .white.opacity(0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: max(geometry.size.width * 0.42, 34))
            .offset(x: shimmerPhase ? geometry.size.width : -geometry.size.width * 0.55)
        }
    }
}

private struct AnimatedShareProgressBar: View {
    let progress: Double
    let tint: Color

    @State private var stripePhase = false

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width * clampedProgress, 14)

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(.quaternary)

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.78),
                                tint,
                                tint.opacity(0.82)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width)
                    .overlay {
                        MovingHighlight(stripePhase: stripePhase)
                            .clipShape(Capsule(style: .continuous))
                    }
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: clampedProgress)
            }
        }
        .frame(height: 14)
        .onAppear {
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                stripePhase = true
            }
        }
    }
}

private struct MovingHighlight: View {
    let stripePhase: Bool

    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [
                    .white.opacity(0),
                    .white.opacity(0.42),
                    .white.opacity(0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geometry.size.width * 0.55)
            .offset(x: stripePhase ? geometry.size.width : -geometry.size.width * 0.6)
        }
    }
}

private enum ShareSourceStyle {
    static func tint(for platformID: String) -> Color {
        switch platformID {
        case "tiktok":
            return Color(red: 0.0, green: 0.72, blue: 0.78)
        case "youtube":
            return Color(red: 1.0, green: 0.05, blue: 0.05)
        case "instagram":
            return Color(red: 0.82, green: 0.18, blue: 0.62)
        default:
            return Color(red: 0.22, green: 0.42, blue: 0.94)
        }
    }
}
