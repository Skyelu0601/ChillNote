import SwiftUI

struct HomeSectionPicker: View {
    let selectedSection: NoteSection
    let onSelect: (NoteSection) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(NoteSection.allCases) { section in
                Button {
                    guard selectedSection != section else { return }
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        onSelect(section)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: section.systemImage)
                            .font(.system(size: 13, weight: .semibold))
                        Text(verbatim: section.title)
                            .font(.system(size: 14, weight: selectedSection == section ? .semibold : .medium, design: .serif))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                    .foregroundColor(selectedSection == section ? .white : .textMain.opacity(0.68))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedSection == section ? Color.accentPrimary : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(section.title)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.textMain.opacity(0.05))
        )
    }
}
