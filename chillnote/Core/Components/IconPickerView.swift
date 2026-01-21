import SwiftUI

/// Icon picker for selecting SF Symbols
struct IconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIcon: String
    
    // Curated list of commonly used SF Symbols for AI actions
    private let icons = [
        // Communication
        "envelope.fill", "envelope.badge.fill", "mail.fill",
        "bubble.left.and.bubble.right.fill", "text.bubble.fill",
        
        // Documents
        "doc.text.fill", "doc.plaintext.fill", "note.text",
        "list.bullet.rectangle", "list.bullet.clipboard.fill",
        
        // Tasks & Productivity
        "checklist", "checkmark.circle.fill", "checkmark.square.fill",
        "calendar", "clock.fill", "timer",
        
        // Editing & Writing
        "pencil", "pencil.circle.fill", "square.and.pencil",
        "text.badge.checkmark", "text.badge.star",
        
        // Ideas & Creativity
        "lightbulb.fill", "brain.head.profile", "sparkles",
        "star.fill", "wand.and.stars",
        
        // Organization
        "folder.fill", "archivebox.fill", "tray.fill",
        "tag.fill", "bookmark.fill",
        
        // Social & Sharing
        "person.2.fill", "megaphone.fill", "speaker.wave.2.fill",
        "square.and.arrow.up.fill", "link",
        
        // Analysis
        "chart.bar.fill", "chart.pie.fill", "magnifyingglass",
        "eye.fill", "scope",
        
        // Misc
        "gearshape.fill", "bolt.fill", "flame.fill",
        "heart.fill", "flag.fill", "bell.fill"
    ]
    
    private let columns = [
        GridItem(.adaptive(minimum: 60))
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(icons, id: \.self) { icon in
                        Button(action: {
                            selectedIcon = icon
                            dismiss()
                        }) {
                            VStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedIcon == icon ? Color.accentPrimary.opacity(0.2) : Color.bgSecondary)
                                        .frame(width: 60, height: 60)
                                    
                                    Image(systemName: icon)
                                        .font(.system(size: 24))
                                        .foregroundColor(selectedIcon == icon ? .accentPrimary : .textMain)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedIcon == icon ? Color.accentPrimary : Color.clear, lineWidth: 2)
                                )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(24)
            }
            .background(Color.bgPrimary)
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    IconPickerView(selectedIcon: .constant("sparkles"))
}
