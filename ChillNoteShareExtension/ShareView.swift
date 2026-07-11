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
            ChillNoteWordmark(size: 26)

            Spacer(minLength: 10)

            SourcePill(sourceName: sourceName, platformID: platformID)
        }
    }
}

private struct ChillNoteWordmark: View {
    let size: CGFloat

    private let chillColor = Color(red: 0.184, green: 0.525, blue: 1.0)
    private let noteColor  = Color(red: 0.365, green: 0.569, blue: 0.961)

    var body: some View {
        HStack(spacing: 0) {
            Text("Chill")
                .font(.custom("AvenirNext-DemiBold", size: size))
                .foregroundStyle(chillColor)

            Text("Note")
                .font(.custom("AvenirNext-HeavyItalic", size: size * 46 / 44))
                .foregroundStyle(noteColor)
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
            if let errorMessage {
                ShareErrorView(message: errorMessage)
                    .frame(maxWidth: .infinity, minHeight: 170, alignment: .center)
            } else if isCompleted {
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

    @State private var pulsePhase = false
    @State private var savedPulse = false
    // Option C: 用 @State 存 iconName，在 withAnimation 里更新才能触发 symbolEffect
    @State private var iconName: String = "play.rectangle.fill"

    private let lineWidths: [CGFloat] = [0.78, 0.56, 0.88, 0.64]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)

            VStack(spacing: 14) {
                animationHeader

                // Option A: extractingTranscript 阶段用 TimelineView 驱动连续时间，
                // 其余阶段传 shimmerPhase = -1 表示不显示 shimmer
                Group {
                    if stage == .extractingTranscript {
                        TimelineView(.animation) { context in
                            let cycleDuration = Double(lineWidths.count) * 0.55
                            let elapsed = context.date.timeIntervalSinceReferenceDate
                            let phase = elapsed.truncatingRemainder(dividingBy: cycleDuration) / cycleDuration
                            linesView(shimmerPhase: phase)
                        }
                    } else {
                        linesView(shimmerPhase: -1)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 132)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onAppear {
            iconName = Self.resolveIconName(for: stage)
            startAnimations()
        }
        .onChange(of: stage) { _, newStage in
            // Option C: 在 withAnimation 里更新 iconName，contentTransition 才会生效
            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                iconName = Self.resolveIconName(for: newStage)
            }
            startAnimations()
        }
        .accessibilityHidden(true)
    }

    private func linesView(shimmerPhase: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(lineWidths.enumerated()), id: \.offset) { index, width in
                TranscriptLine(
                    stage: stage,
                    widthRatio: width,
                    index: index,
                    lineCount: lineWidths.count,
                    tint: tint,
                    pulsePhase: pulsePhase,
                    shimmerPhase: shimmerPhase
                )
            }
        }
    }

    private var animationHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 30, height: 30)

                // Option C: contentTransition + symbolEffect，图标切换时平滑替换
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .contentTransition(.symbolEffect(.replace))
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

    private static func resolveIconName(for stage: ShareImportStage) -> String {
        switch stage {
        case .readingContent:       return "play.rectangle.fill"
        case .extractingTranscript: return "text.line.first.and.arrowtriangle.forward"
        case .saving, .completed:   return "note.text"
        }
    }

    private func startAnimations() {
        pulsePhase = false
        savedPulse = false

        withAnimation(.easeInOut(duration: stage == .extractingTranscript ? 1.4 : 0.9).repeatForever(autoreverses: true)) {
            pulsePhase = true
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
    let lineCount: Int
    let tint: Color
    let pulsePhase: Bool
    /// TimelineView 传入的连续相位 [0,1)，-1 表示不显示 shimmer
    let shimmerPhase: Double

    private var lineOpacity: Double {
        switch stage {
        case .readingContent:
            return pulsePhase ? 0.58 : 0.38
        case .extractingTranscript:
            // shimmer 已经承担视觉动感，opacity 只保留轻微错落感，不再大幅闪烁
            let stagger = Double(index) * 0.06
            return 0.72 - stagger
        case .saving, .completed:
            return 0.62
        }
    }

    private var dotOpacity: Double {
        switch stage {
        case .readingContent:
            return 0.28
        case .extractingTranscript:
            let base = pulsePhase ? 0.95 : 0.36
            let stagger = Double(index) * 0.12
            return min(max(base - stagger, 0.28), 0.95)
        case .saving, .completed:
            return 0.52
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let lineWidth = geometry.size.width * widthRatio

            HStack(spacing: 8) {
                Circle()
                    .fill(tint.opacity(dotOpacity))
                    .frame(width: 6, height: 6)
                    .animation(
                        .easeInOut(duration: 1.2)
                        .delay(Double(index) * 0.1),
                        value: dotOpacity
                    )

                Capsule(style: .continuous)
                    .fill(lineFill)
                    .frame(width: lineWidth, height: 8)
                    .overlay(alignment: .leading) {
                        // Option A: 真正移动的 shimmer
                        shimmerView(lineWidth: lineWidth)
                    }
                    // clipShape 让 shimmer 被裁剪在胶囊范围内
                    .clipShape(Capsule(style: .continuous))
                    .opacity(lineOpacity)
                    .animation(
                        .easeInOut(duration: 1.2)
                        .delay(Double(index) * 0.1),
                        value: lineOpacity
                    )

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 8)
        .scaleEffect(stage == .saving ? 0.96 : 1, anchor: .leading)
        .opacity(stage == .saving ? 0.82 : 1)
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: stage)
    }

    /// 根据 shimmerPhase 计算当前行的扫描光位置
    /// alignment: .leading 坐标系：leading = 0，trailing = lineWidth
    @ViewBuilder
    private func shimmerView(lineWidth: CGFloat) -> some View {
        let lineShare = 1.0 / Double(lineCount)
        let lineStart = Double(index) * lineShare
        // localProgress: 0 = 光刚进入左侧，1 = 光刚离开右侧
        let localProgress = shimmerPhase >= 0 ? (shimmerPhase - lineStart) / lineShare : -1.0
        let shimmerWidth = lineWidth * 0.52
        // leading 对齐：offset=0 时光在最左；扫完时 offset=lineWidth（被 clip 裁掉）
        let xOffset = (lineWidth + shimmerWidth) * CGFloat(localProgress) - shimmerWidth

        if localProgress >= 0 && localProgress <= 1.0 {
            LinearGradient(
                colors: [
                    .clear,
                    tint.opacity(0.45),
                    tint.opacity(0.72),
                    tint.opacity(0.45),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: shimmerWidth, height: 8)
            .offset(x: xOffset)
        }
    }

    private var lineFill: Color {
        switch stage {
        case .readingContent:
            return Color(.systemGray4).opacity(0.72)
        case .extractingTranscript:
            return tint.opacity(0.24)
        case .saving, .completed:
            return Color(.systemGray4).opacity(0.46)
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

private struct ShareErrorView: View {
    let message: String

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 72, height: 72)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.red)
                    .symbolRenderingMode(.hierarchical)
            }
            .scaleEffect(appeared ? 1 : 0.6)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 8) {
                Text(ShareL10n.text("share_extension.failed"))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 6)
        }
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.72).delay(0.05)) {
                appeared = true
            }
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
