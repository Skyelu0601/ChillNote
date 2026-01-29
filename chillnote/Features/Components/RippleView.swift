import SwiftUI

struct RippleView: View {
    let isActive: Bool
    let color: Color
    
    @State private var ripples: [Ripple] = []
    private let timer = Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()
    
    struct Ripple: Identifiable {
        let id = UUID()
    }
    
    var body: some View {
        ZStack {
            ForEach(ripples) { ripple in
                CircleView(color: color)
            }
        }
        .onReceive(timer) { _ in
            if isActive {
                withAnimation {
                    if ripples.count > 3 {
                        ripples.removeFirst()
                    }
                    ripples.append(Ripple())
                }
            } else {
                ripples.removeAll()
            }
        }
    }
}

private struct CircleView: View {
    let color: Color
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.5
    
    var body: some View {
        Circle()
            .stroke(color, lineWidth: 2)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 2.5)) {
                    scale = 2.0
                    opacity = 0
                }
            }
    }
}
