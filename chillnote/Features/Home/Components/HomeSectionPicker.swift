import SwiftUI

struct HomeSectionPicker: View {
    let selectedSection: NoteSection
    let sectionCounts: [NoteSection: Int]
    let onSelect: (NoteSection) -> Void

    @Namespace private var pillNamespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(NoteSection.allCases) { section in
                sectionButton(for: section)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.textMain.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.textMain.opacity(0.04), lineWidth: 0.5)
        )
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
            HStack(spacing: 6) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))

                Text(verbatim: section.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium, design: .serif))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .textMain.opacity(0.4))
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: count)
                }
            }
            .foregroundColor(isSelected ? .white : .textMain.opacity(0.68))
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.accentPrimary)
                            .matchedGeometryEffect(id: "section-pill", in: pillNamespace)
                            .shadow(color: Color.accentPrimary.opacity(0.22), radius: 6, x: 0, y: 2)
                    }
                }
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(section.title)
        .accessibilityValue(count > 0 ? "\(count)" : "")
    }
}
