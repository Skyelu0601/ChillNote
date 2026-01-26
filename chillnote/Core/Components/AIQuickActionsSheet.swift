import SwiftUI

/// Bottom sheet displaying quick AI actions for transforming note content
struct AIQuickActionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onActionSelected: (AIQuickAction) -> Void
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 24))
                            .foregroundColor(.accentPrimary)
                        Text("Chillo's Magic")
                            .font(.displayMedium)
                            .foregroundColor(.textMain)
                        Spacer()
                    }
                    
                    Text("Let Chillo polish this up.")
                        .font(.bodyMedium)
                        .foregroundColor(.textSub)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
                
                Divider()
                    .background(Color.textSub.opacity(0.2))
                
                // Actions Grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(AIQuickAction.defaultActions) { action in
                            ActionButton(action: action) {
                                onActionSelected(action)
                                dismiss()
                            }
                        }
                    }
                    .padding(24)
                }
                .background(Color.bgPrimary)
            }
            .background(Color.white)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.textSub)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Action Button
private struct ActionButton: View {
    let action: AIQuickAction
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.mellowYellow.opacity(0.3), Color.mellowOrange.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: action.icon)
                        .font(.system(size: 24))
                        .foregroundColor(.accentPrimary)
                }
                
                // Title
                Text(action.title)
                    .font(.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundColor(.textMain)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(isPressed ? 0.05 : 0.1), radius: isPressed ? 4 : 8, x: 0, y: isPressed ? 2 : 4)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
    }
}

#Preview {
    AIQuickActionsSheet { action in
        print("Selected: \(action.title)")
    }
}
