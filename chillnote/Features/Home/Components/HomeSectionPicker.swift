import SwiftUI

struct HomeSectionPicker: View {
    let selectedSection: NoteSection
    let onSelect: (NoteSection) -> Void

    @Namespace private var indicatorNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(NoteSection.allCases) { section in
                sectionButton(for: section)
            }
        }
        .frame(height: 52)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.separator.opacity(0.72))
                .frame(height: 1)
        }
    }

    private func sectionButton(for section: NoteSection) -> some View {
        let isSelected = selectedSection == section

        return Button {
            guard !isSelected else { return }
            AppInteractionFeedback.selectionChanged()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                onSelect(section)
            }
        } label: {
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    Text(verbatim: section.title)
                        .font(.system(size: 16, weight: isSelected ? .semibold : .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .foregroundColor(isSelected ? .textMain : .textMain.opacity(0.62))

                    ZStack {
                        if isSelected {
                            Capsule(style: .continuous)
                                .fill(Color.accentPrimary)
                                .matchedGeometryEffect(id: "section-indicator", in: indicatorNamespace)
                        }
                    }
                    .frame(width: indicatorWidth(for: section))
                    .frame(height: 3)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(section.title)
    }

    private func indicatorWidth(for section: NoteSection) -> CGFloat {
        switch section {
        case .inbox:
            return 64
        case .drafts:
            return 68
        case .published:
            return 96
        }
    }
}
