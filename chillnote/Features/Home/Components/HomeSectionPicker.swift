import SwiftUI

struct HomeSectionPicker: View {
    let selectedSection: NoteSection
    let sectionCounts: [NoteSection: Int]
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
        let count = sectionCounts[section] ?? 0

        return Button {
            guard !isSelected else { return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                onSelect(section)
            }
        } label: {
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 7) {
                        Text(verbatim: section.title)
                            .font(.system(size: 16, weight: isSelected ? .semibold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Text("\(count)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(isSelected ? .accentPrimary : .textMain.opacity(0.48))
                            .frame(minWidth: 22, minHeight: 22)
                            .padding(.horizontal, count > 9 ? 4 : 0)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(isSelected ? Color.accentPrimary.opacity(0.10) : Color.textMain.opacity(0.055))
                            )
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3, dampingFraction: 0.82), value: count)
                    }
                    .foregroundColor(isSelected ? .accentPrimary : .textMain.opacity(0.62))

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
        .accessibilityValue("\(count)")
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
