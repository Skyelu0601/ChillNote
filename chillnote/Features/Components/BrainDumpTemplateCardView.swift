import SwiftUI

struct BrainDumpTemplateCardView: View {
    let template: BrainDumpTemplate
    var isSelected: Bool = false
    
    private var nameText: String {
        L10n.text(template.nameKey).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var promptText: String {
        L10n.text(template.promptKey).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var showsPrompt: Bool {
        !promptText.isEmpty && promptText != nameText
    }

    var body: some View {
        cardContent
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .frame(width: 252, alignment: .center)
        .frame(height: isSelected ? selectedCardHeight : collapsedCardHeight, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(isSelected ? 0.94 : 0.84))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(template.accentColor.opacity(isSelected ? 0.34 : 0.16), lineWidth: isSelected ? 1.5 : 1)
        )
        .shadow(color: Color.black.opacity(isSelected ? 0.1 : 0.06), radius: isSelected ? 16 : 12, x: 0, y: 6)
        .scaleEffect(isSelected ? 1.0 : 0.95)
        .opacity(isSelected ? 1.0 : 0.92)
        .animation(.spring(response: 0.42, dampingFraction: 0.84), value: isSelected)
        .accessibilityElement(children: .combine)
    }

    private var collapsedCardHeight: CGFloat { 112 }

    private var selectedCardHeight: CGFloat {
        showsPrompt ? 228 : 124
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                iconBadge(size: 38, iconFont: 16)

                Text(nameText)
                    .font(.bodySmall.weight(.semibold))
                    .foregroundColor(.textMain)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }

            if isSelected && showsPrompt {
                Text(promptText)
                    .font(.bodySmall)
                    .foregroundColor(.textMain.opacity(0.88))
                    .lineSpacing(5)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func iconBadge(size: CGFloat, iconFont: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(template.accentColor.opacity(0.14))
                .frame(width: size, height: size)

            Image(systemName: template.iconName)
                .font(.system(size: iconFont, weight: .semibold))
                .foregroundColor(template.accentColor)
        }
    }
}
