import SwiftUI

struct WaveformView: View {
    let isActive: Bool
    
    @State private var phase = false
    private let baseHeights: [CGFloat] = [
        12, 18, 24, 14, 22, 28, 16, 26, 20, 30,
        14, 22, 18, 26, 12, 24, 16, 28, 20, 26
    ]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<baseHeights.count, id: \.self) { index in
                let height = barHeight(for: index)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentPrimary)
                    .frame(width: 4, height: height)
                    .animation(animation(for: index), value: phase)
            }
        }
        .onAppear {
            if isActive {
                startAnimating()
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                startAnimating()
            } else {
                phase = false
            }
        }
        .frame(height: 60)
        .opacity(isActive ? 1.0 : 0.4)
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let base = baseHeights[index]
        if !isActive {
            return base * 0.6
        }
        let multiplier: CGFloat = (index % 2 == 0) ? (phase ? 1.6 : 1.0) : (phase ? 1.2 : 0.9)
        return base * multiplier
    }
    
    private func animation(for index: Int) -> Animation? {
        guard isActive else { return nil }
        return Animation.easeInOut(duration: 0.6)
            .repeatForever(autoreverses: true)
            .delay(Double(index) * 0.04)
    }
    
    private func startAnimating() {
        phase = false
        withAnimation {
            phase = true
        }
    }
}

#Preview {
    WaveformView(isActive: true)
}
