import SwiftUI

struct HomeSectionPicker: View {
    let selectedSection: NoteSection
    let onSelect: (NoteSection) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(NoteSection.allCases) { section in
                sectionButton(
                    title: section.title,
                    systemImage: section.systemImage,
                    isSelected: selectedSection == section
                ) {
                    guard selectedSection != section else { return }
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        onSelect(section)
                    }
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.textMain.opacity(0.05))
        )
    }

    private func sectionButton(
        title: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                Text(verbatim: title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium, design: .serif))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundColor(isSelected ? .white : .textMain.opacity(0.68))
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentPrimary : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
