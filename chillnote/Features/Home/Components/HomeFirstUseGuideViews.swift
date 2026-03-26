import SwiftUI

struct HomeFirstUseTaskCard: View {
    let step: HomeFirstUseGuideStep
    let onSkip: () -> Void

    // 为底部提示增加微动效
    @State private var isBouncing = false

    var body: some View {
        VStack(alignment: .leading, spacing: step == .recordFirstNote ? 14 : 20) {
            // 头部区域
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.text("home.first_use.card.title"))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.textMain)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.textSub)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 10) {
                    Button(action: onSkip) {
                        Text(L10n.text("home.first_use.card.skip"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.textSub)
                    }
                    .buttonStyle(.plain)

                    Text(progressLabel)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.accentPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentPrimary.opacity(0.08))
                        .clipShape(Capsule())
                }
            }

            // 步骤列表 (更克制的视觉设计)
            VStack(alignment: .leading, spacing: 14) {
                guideRow(title: L10n.text("home.first_use.step.record"), isActive: step == .recordFirstNote, isDone: step != .recordFirstNote)
                guideRow(title: L10n.text("home.first_use.step.select"), isActive: step == .openSelection || step == .addSkill, isDone: step == .runSkill || step == .completed)
                guideRow(title: L10n.text("home.first_use.step.choose_skill"), isActive: step == .runSkill, isDone: step == .completed)
            }
            .padding(.vertical, step == .recordFirstNote ? 0 : 4)

            // 动态提示区
            if step == .recordFirstNote {
                HStack(spacing: 12) {
                    Image(systemName: "microphone.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.accentPrimary)
                        .scaleEffect(isBouncing ? 1.05 : 0.95)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isBouncing)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.text("home.first_use.card.tap_mic"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.textMain)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .onAppear {
                    isBouncing = true
                }
            }
        }
        .padding(20)
        // 采用毛玻璃背景增加高级感
        .background(Color.white.opacity(0.8))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                // 模拟玻璃边缘反光
                .stroke(Color.white, lineWidth: 1)
        )
        // 更柔和弥散的阴影
        .shadow(color: Color.black.opacity(0.04), radius: 20, y: 10)
    }

    private var subtitle: String {
        switch step {
        case .recordFirstNote:
            return L10n.text("home.first_use.subtitle.record")
        case .openSelection, .addSkill:
            return L10n.text("home.first_use.subtitle.select")
        case .runSkill:
            return L10n.text("home.first_use.subtitle.choose_skill")
        case .completed:
            return L10n.text("home.first_use.subtitle.completed")
        }
    }

    private var progressLabel: String {
        switch step {
        case .recordFirstNote:
            return "1/3"
        case .openSelection, .addSkill:
            return "2/3"
        case .runSkill:
            return "3/3"
        case .completed:
            return L10n.text("common.done")
        }
    }

    private func guideRow(title: String, isActive: Bool, isDone: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                // 状态圆点：去掉数字减少视觉噪音，用纯粹的几何形状表达状态
                Circle()
                    .fill(isDone ? Color.accentPrimary : (isActive ? Color.accentPrimary.opacity(0.12) : Color.gray.opacity(0.1)))
                    .frame(width: 24, height: 24)

                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                } else if isActive {
                    Circle()
                        .fill(Color.accentPrimary)
                        .frame(width: 8, height: 8)
                }
            }

            Text(title)
                .font(.system(size: 14, weight: isActive ? .medium : .regular))
                .foregroundColor(isActive || isDone ? .textMain : .textSub)

            Spacer()
        }
    }
}

struct HomeSelectionGuideBubble: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.accentPrimary)
                .padding(.top, 2)

            Text(message)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.textMain)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.white.opacity(0.85))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white, lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 16, y: 8)
    }
}

struct HomeGuideCompletionOverlay: View {
    let onTryAnotherSkill: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.15)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.text("home.first_use.completion.title"))
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.textMain)

                    Text(L10n.text("home.first_use.completion.subtitle"))
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.textSub)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 12) {
                    Button(action: onTryAnotherSkill) {
                        Text(L10n.text("home.first_use.completion.try_another_skill"))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accentPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: onDismiss) {
                        Text(L10n.text("common.done"))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.textMain)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.bgSecondary.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
            .background(Color.white.opacity(0.9))
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 24, y: 12)
            .padding(.horizontal, 24)
        }
    }
}
