import SwiftUI
import SwiftData

struct CategorySelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let onConfirm: ([Category]) -> Void
    
    @Query(sort: \Category.order) private var allCategories: [Category]
    @State private var selectedCategories: Set<UUID> = []
    @State private var showingCreateTag = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)
            
            // Title + Add button
            HStack {
                Text("Add Tags to This Note")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.textMain)
                Spacer()
                Button(action: { showingCreateTag = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                        Text("New Tag")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.accentPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.accentPrimary.opacity(0.12))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Create a new tag")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Tags
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tags")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textSub)
                        
                        FlowLayout(spacing: 12) {
                            ForEach(allCategories, id: \.id) { category in
                                CategoryChip(
                                    category: category,
                                    isSelected: selectedCategories.contains(category.id),
                                    action: { toggleCategory(category) }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 100)
                }
            }
            
            Spacer()
            
            // Bottom buttons
            HStack(spacing: 12) {
                Button(action: skipSelection) {
                    Text("Skip")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.textSub)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .cornerRadius(12)
                }
                
                Button(action: confirmSelection) {
                    HStack(spacing: 6) {
                        Text("Confirm")
                        if !selectedCategories.isEmpty {
                            Text("(\(selectedCategories.count))")
                                .opacity(0.8)
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [Color.accentPrimary, Color.accentPrimary.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: Color.accentPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .background(
                Color.bgPrimary
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -5)
            )
        }
        .background(Color.bgPrimary)
        .sheet(isPresented: $showingCreateTag) {
            CreateTagSheet(
                existingNames: Set(allCategories.map { $0.name.lowercased() }),
                nextOrder: (allCategories.map(\.order).max() ?? -1) + 1,
                onCreated: { created in
                    selectedCategories.insert(created.id)
                }
            )
        }
    }

    private func toggleCategory(_ category: Category) {
        if selectedCategories.contains(category.id) {
            selectedCategories.remove(category.id)
        } else {
            selectedCategories.insert(category.id)
        }
    }
    
    private func confirmSelection() {
        let selected = allCategories.filter { selectedCategories.contains($0.id) }
        onConfirm(selected)
        dismiss()
    }

    private func skipSelection() {
        onConfirm([])
        dismiss()
    }
}

// Category chip for selection
struct CategoryChip: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                }
                
                Image(systemName: category.icon)
                    .font(.system(size: 14, weight: .semibold))
                
                Text(category.name)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? .white : category.color)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? category.color : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(category.color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.0 : 0.98)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// Flow layout for wrapping chips
struct FlowLayout: Layout {
    let spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

#Preview {
    CategorySelectorSheet(
        onConfirm: { _ in }
    )
    .modelContainer(DataService.shared.container!)
}

private struct CreateTagSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let existingNames: Set<String>
    let nextOrder: Int
    let onCreated: (Category) -> Void

    @State private var name: String = ""
    @State private var selectedIcon: String = "tag.fill"
    @State private var selectedColorHex: String = "#FFC043"
    @State private var errorMessage: String?

    private let icons: [String] = [
        "tag.fill",
        "bookmark.fill",
        "star.fill",
        "heart.fill",
        "briefcase.fill",
        "house.fill",
        "book.fill",
        "lightbulb.fill",
        "checkmark.circle.fill",
        "leaf.fill",
        "cart.fill",
        "airplane",
        "gamecontroller.fill"
    ]

    private let colors: [String] = [
        "#FF6B6B",
        "#4ECDC4",
        "#95E1D3",
        "#FFE66D",
        "#A8E6CF",
        "#C7CEEA",
        "#FFC043",
        "#FFB347",
        "#6C5CE7",
        "#0984E3",
        "#00B894",
        "#D63031"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Fitness, Finance, Travel", text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }

                Section("Icon") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(icons, id: \.self) { icon in
                                Button(action: { selectedIcon = icon }) {
                                    Image(systemName: icon)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(selectedIcon == icon ? .white : .textMain)
                                        .frame(width: 40, height: 40)
                                        .background(selectedIcon == icon ? Color.accentPrimary : Color.bgSecondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Color") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(colors, id: \.self) { hex in
                                Button(action: { selectedColorHex = hex }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: hex))
                                            .frame(width: 34, height: 34)
                                        if selectedColorHex == hex {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("New Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createTag() }
                }
            }
        }
    }

    private func createTag() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Please enter a name."
            return
        }

        let normalized = trimmed.lowercased()
        guard !existingNames.contains(normalized) else {
            errorMessage = "A tag with this name already exists."
            return
        }

        let category = Category(name: trimmed, icon: selectedIcon, colorHex: selectedColorHex, order: nextOrder)
        modelContext.insert(category)
        try? modelContext.save()
        onCreated(category)
        dismiss()
    }
}
