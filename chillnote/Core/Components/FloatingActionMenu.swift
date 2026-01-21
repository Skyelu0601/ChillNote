import SwiftUI

struct ActionMenuItem: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let action: () -> Void
    let label: String // Used for accessibility and long-press tooltip
}

struct FloatingActionMenu: View {
    let mainIcon: String
    let mainColor: Color
    let items: [ActionMenuItem]
    
    @State private var isOpen = false
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Overlay to close menu when clicking outside
            if isOpen {
                Color.black.opacity(0.01) // Invisible but interactable
                    .ignoresSafeArea()
                    .onTapGesture {
                        closeMenu()
                    }
            }
            
            VStack(spacing: 16) {
                // Expanded Items (The Totem)
                if isOpen {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        Button(action: {
                            closeMenu()
                            // Small delay to allow menu closing animation to start
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                item.action()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 44, height: 44)
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                
                                Image(systemName: item.icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(item.color)
                            }
                        }
                        .transition(.scale(scale: 0.5).combined(with: .opacity).combined(with: .move(edge: .bottom)))
                        // Staggered animation effect
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.6)
                            .delay(Double(items.count - 1 - index) * 0.05),
                            value: isOpen
                        )
                    }
                }
                
                // Main Toggle Button
                Button(action: toggleMenu) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 56, height: 56)
                            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                        
                        Image(systemName: isOpen ? "xmark" : mainIcon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(mainColor)
                            .rotationEffect(.degrees(isOpen ? 90 : 0))
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isOpen)
                    }
                }
            }
        }
    }
    
    private func toggleMenu() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isOpen.toggle()
        }
    }
    
    private func closeMenu() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isOpen = false
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        
        FloatingActionMenu(
            mainIcon: "sparkles",
            mainColor: .orange,
            items: [
                ActionMenuItem(icon: "envelope.fill", color: .blue, action: {}, label: "Email"),
                ActionMenuItem(icon: "doc.text.fill", color: .purple, action: {}, label: "Summary"),
                ActionMenuItem(icon: "checklist", color: .green, action: {}, label: "Todo")
            ]
        )
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}
