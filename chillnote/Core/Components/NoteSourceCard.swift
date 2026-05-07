import SwiftUI

struct NoteSourceCard: View {
    let source: NoteSourceMetadata
    var compact: Bool = false

    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            guard let url = URL(string: source.url) else { return }
            openURL(url)
        } label: {
            HStack(spacing: 10) {
                sourceBadge

                VStack(alignment: .leading, spacing: compact ? 1 : 2) {
                    Text(source.platformName)
                        .font(.chillCaption.weight(.semibold))
                        .foregroundColor(.textSub)
                        .lineLimit(1)

                    Text(source.title)
                        .font(compact ? .bodySmall : .bodyMedium)
                        .foregroundColor(.textMain)
                        .lineLimit(compact ? 1 : 2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: compact ? 12 : 13, weight: .semibold))
                    .foregroundColor(.textSub)
            }
            .padding(.horizontal, compact ? 10 : 12)
            .padding(.vertical, compact ? 9 : 11)
            .background(Color.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.text("note_source.accessibility.open", source.platformName, source.title))
    }

    private var sourceBadge: some View {
        ZStack {
            Circle()
                .fill(badgeColor)
                .frame(width: compact ? 30 : 34, height: compact ? 30 : 34)

            if let initials = badgeInitials {
                Text(initials)
                    .font(.system(size: compact ? 9 : 10, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 3)
            } else {
                Image(systemName: badgeSystemImage)
                    .font(.system(size: compact ? 14 : 15, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .accessibilityHidden(true)
    }

    private var badgeInitials: String? {
        switch source.platformID {
        case "xiaohongshu":
            return "小红书"
        case "youtube":
            return "YT"
        case "tiktok":
            return "TT"
        case "instagram":
            return "IG"
        case "threads":
            return "TH"
        case "reddit":
            return "RD"
        case "pinterest":
            return "PI"
        case "linkedin":
            return "IN"
        case "facebook":
            return "FB"
        case "vimeo":
            return "VI"
        case "twitch":
            return "TW"
        case "product_hunt":
            return "PH"
        case "hacker_news":
            return "HN"
        case "bilibili":
            return "B"
        default:
            return nil
        }
    }

    private var badgeSystemImage: String {
        switch source.platformID {
        case "x":
            return "xmark"
        case "spotify", "apple_podcasts":
            return "waveform"
        default:
            return "link"
        }
    }

    private var badgeColor: Color {
        switch source.platformID {
        case "xiaohongshu":
            return Color(red: 0.96, green: 0.18, blue: 0.25)
        case "youtube":
            return Color(red: 1.0, green: 0.0, blue: 0.0)
        case "tiktok":
            return Color(red: 0.05, green: 0.06, blue: 0.08)
        case "instagram":
            return Color(red: 0.82, green: 0.25, blue: 0.55)
        case "threads":
            return Color(red: 0.08, green: 0.08, blue: 0.08)
        case "x":
            return Color(red: 0.08, green: 0.09, blue: 0.10)
        case "reddit":
            return Color(red: 1.0, green: 0.27, blue: 0.0)
        case "pinterest":
            return Color(red: 0.9, green: 0.0, blue: 0.12)
        case "linkedin":
            return Color(red: 0.0, green: 0.47, blue: 0.71)
        case "facebook":
            return Color(red: 0.09, green: 0.47, blue: 0.95)
        case "vimeo":
            return Color(red: 0.1, green: 0.69, blue: 0.93)
        case "twitch":
            return Color(red: 0.39, green: 0.25, blue: 0.65)
        case "product_hunt":
            return Color(red: 0.85, green: 0.27, blue: 0.15)
        case "hacker_news":
            return Color(red: 1.0, green: 0.4, blue: 0.0)
        case "bilibili":
            return Color(red: 0.0, green: 0.63, blue: 0.86)
        case "spotify":
            return Color(red: 0.12, green: 0.73, blue: 0.33)
        default:
            return .accentPrimary
        }
    }
}
