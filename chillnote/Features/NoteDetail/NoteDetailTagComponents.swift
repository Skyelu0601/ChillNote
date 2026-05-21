import SwiftUI

struct TagBannerView: View {
    let tags: [Tag]
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
                    ) {
                        onRemove(tag)
                    }
                }

                Button(action: onAddClick) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text(L10n.text("note_detail.tag.add"))
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(color.opacity(TagColorService.tagBackgroundOpacity))
            )
            .foregroundColor(textColor)
        }
    }
}
