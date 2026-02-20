import SwiftUI

struct TagBannerView: View {
    let tags: [Tag]
    let suggestedTags: [String]
    let onConfirm: (String) -> Void
    let onRemove: (Tag) -> Void
    let onAddClick: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FlowLayout(spacing: 8) {
                ForEach(tags.filter { $0.deletedAt == nil }) { tag in
                    TagPill(
                        title: tag.name,
                        color: tag.color,
                        textColor: tag.labelColor,
                        isSuggested: false
                    ) {
                        onRemove(tag)
                    }
                }

                ForEach(suggestedTags, id: \.self) { tagName in
                    TagPill(title: tagName, color: .gray, textColor: .textSub, isSuggested: true) {
                        onConfirm(tagName)
                    }
                }

                Button(action: onAddClick) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("Tag")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().stroke(Color.textSub.opacity(0.3), lineWidth: 1))
                    .foregroundColor(.textSub)
                }
            }
        }
    }
}

struct TagPill: View {
    let title: String
    let color: Color
    let textColor: Color
    let isSuggested: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isSuggested {
                    Text("#")
                        .foregroundColor(color.opacity(0.4))
                }
                Text(title)
            }
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSuggested ? color.opacity(0.12) : color.opacity(TagColorService.tagBackgroundOpacity))
            )
            .foregroundColor(isSuggested ? .textSub : textColor)
            .overlay(
                Capsule()
                    .stroke(isSuggested ? color.opacity(0.2) : Color.clear, lineWidth: 1)
            )
        }
    }
}
