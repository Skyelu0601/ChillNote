import SwiftUI

struct HomeQuickActionsView: View {
    let showsUnreadIndicator: Bool
    let onPostIdeasTap: () -> Void

    var body: some View {
        quickActionButton(
            icon: "lightbulb",
            title: L10n.text("weekly_topics.home.button"),
            tint: .accentPrimary,
            accessibilityHint: showsUnreadIndicator
                ? L10n.text("weekly_topics.home.unread_hint")
                : L10n.text("weekly_topics.home.hint"),
            action: onPostIdeasTap
        )
    }

    private func quickActionButton(
        icon: String,
        title: String,
        tint: Color,
        accessibilityHint: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textMain)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.bgSecondary)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.borderSubtle, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.shadowColor.opacity(0.55), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.tactile)
        .accessibilityLabel(title)
        .accessibilityHint(accessibilityHint)
    }
}
