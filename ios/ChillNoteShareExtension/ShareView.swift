import SwiftUI
import UIKit

struct ShareView: View {
    @ObservedObject var viewModel: ShareViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var dragOffset: CGFloat = 0
    @State private var isDismissing = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Color.black.opacity(isDismissing ? 0 : 0.24)
                    .ignoresSafeArea()

                ShareBottomSheetContent(viewModel: viewModel)
                    .offset(y: isDismissing ? geometry.size.height : dragOffset)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 12)
                            .updating($dragOffset) { value, offset, _ in
                                guard value.translation.height > abs(value.translation.width) else { return }
                                offset = max(0, value.translation.height)
                            }
                            .onEnded { value in
                                guard value.translation.height > abs(value.translation.width),
                                      value.translation.height > 80 || value.predictedEndTranslation.height > 180 else { return }
                                dismiss()
                            }
                    )
            }
        }
        .background(Color.clear)
        .ignoresSafeArea()
        .accessibilityAction(.escape, viewModel.dismiss)
        .task {
            await viewModel.start()
        }
        .task(id: viewModel.isCompleted) {
            guard await viewModel.waitForAutomaticDismissal(voiceOverRunning: UIAccessibility.isVoiceOverRunning),
                  !UIAccessibility.isVoiceOverRunning else { return }
            dismiss()
        }
    }

    private func dismiss() {
        guard !isDismissing else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
            isDismissing = true
        }
        Task { @MainActor in
            if !reduceMotion {
                try? await Task.sleep(for: .milliseconds(240))
            }
            viewModel.dismiss()
        }
    }
}

private struct ShareBottomSheetContent: View {
    @ObservedObject var viewModel: ShareViewModel
    @ScaledMetric(relativeTo: .body) private var panelHeight = 540.0

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
        }
        .frame(maxWidth: .infinity)
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
    }

    private var content: some View {
        VStack(spacing: 0) {
            Capsule(style: .continuous)
                .fill(Color(.systemGray4))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 30)
                .accessibilityHidden(true)

            ShareHeaderView(sourceName: viewModel.sourceName)
                .padding(.bottom, 36)

            ShareStatusView(viewModel: viewModel)

            Spacer(minLength: 32)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 40)
        .frame(minHeight: panelHeight, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ShareHeaderView: View {
    let sourceName: String
    private let brandBlue = Color(red: 0.184, green: 0.525, blue: 1)

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                wordmark
                Spacer(minLength: 10)
                sourcePill
            }
            VStack(alignment: .leading, spacing: 12) {
                wordmark
                sourcePill
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var wordmark: some View {
        Text(verbatim: "ChillScript")
            .font(.system(.title2, design: .rounded, weight: .bold))
            .tracking(-0.7)
            .foregroundStyle(brandBlue)
            .fixedSize()
    }

    private var sourcePill: some View {
        HStack(spacing: 7) {
            Image(systemName: "link")
                .accessibilityHidden(true)
            Text(ShareL10n.text("share_extension.source_format", sourceName))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(brandBlue)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(brandBlue.opacity(0.1), in: Capsule())
    }
}

private struct ShareStatusView: View {
    @ObservedObject var viewModel: ShareViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title2) private var statusHeight = 240.0
    private let brandBlue = Color(red: 0.184, green: 0.525, blue: 1)

    var body: some View {
        ZStack {
            workingContent
                .opacity(isWorking ? 1 : 0)
                .accessibilityHidden(!isWorking)

            resultContent
                .opacity(isWorking ? 0 : 1)
                .accessibilityHidden(isWorking)
        }
        .frame(maxWidth: .infinity, minHeight: statusHeight)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isWorking)
    }

    private var isWorking: Bool {
        !viewModel.isCompleted && viewModel.errorMessage == nil
    }

    private var workingContent: some View {
        VStack(spacing: 28) {
            ShareLoadingRing(isActive: isWorking)
                .frame(width: 76, height: 76)
                .accessibilityHidden(true)

            Text(viewModel.statusText)
                .font(.system(.title3, weight: .medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var resultContent: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(resultColor.opacity(0.08))
                    .frame(width: 76, height: 76)
                Image(systemName: viewModel.errorMessage == nil ? "checkmark" : "exclamationmark")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(resultColor)
            }
            .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text(resultTitle)
                    .font(.system(.title2, weight: .semibold))
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var resultTitle: String {
        if viewModel.errorMessage != nil {
            return ShareL10n.text(viewModel.isCreditsRequired ? "share_extension.credits_required_title" : "share_extension.failed")
        }
        return ShareL10n.text("share_extension.saved")
    }

    private var resultColor: Color {
        if viewModel.errorMessage == nil {
            return Color(red: 0.14, green: 0.54, blue: 0.29)
        }
        return viewModel.isCreditsRequired ? .orange : .red
    }
}

private struct ShareLoadingRing: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let brandBlue = Color(red: 0.184, green: 0.525, blue: 1)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !isActive || reduceMotion)) { context in
            let angle = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 1.1) / 1.1 * 360

            Circle()
                .trim(from: 0, to: 0.72)
                .stroke(brandBlue, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 52, height: 52)
                .rotationEffect(.degrees(angle))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
