import SwiftUI

struct CategoryPill: View {
    let category: Category?  // nil means "All"
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category?.icon ?? "square.grid.2x2")
                    .font(.system(size: 14, weight: .semibold))
                
                Text(category?.name ?? "All")
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .medium))
                        .opacity(0.7)
                }
            }
            .foregroundColor(isSelected ? .white : (category?.color ?? .textMain))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? (category?.color ?? Color.accentPrimary) : Color.white)
                    .shadow(color: Color.black.opacity(isSelected ? 0.15 : 0.08), radius: isSelected ? 8 : 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : (category?.color.opacity(0.3) ?? Color.gray.opacity(0.2)), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.0 : 0.98)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

#Preview {
    VStack(spacing: 16) {
        CategoryPill(category: nil, count: 42, isSelected: true, action: {})
        
        CategoryPill(
            category: Category(name: "工作", icon: "briefcase.fill", colorHex: "#FF6B6B", order: 0),
            count: 12,
            isSelected: false,
            action: {}
        )
        
        CategoryPill(
            category: Category(name: "生活", icon: "house.fill", colorHex: "#4ECDC4", order: 1),
            count: 8,
            isSelected: true,
            action: {}
        )
    }
    .padding()
    .background(Color.bgPrimary)
}
