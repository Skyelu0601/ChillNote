import SwiftUI

struct BannerData: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let style: BannerStyle
}

enum BannerStyle {
    case error
    case success
    case info
    case warning
    
    var iconName: String {
        switch self {
        case .error:
            return "exclamationmark.triangle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        }
    }
    
    var primaryColor: Color {
        switch self {
        case .error:
            return .red
        case .success:
            return .accentPrimary // Assuming this exists, otherwise .green
        case .info:
            return .blue
        case .warning:
            return .orange
        }
    }
}

struct BannerView: View {
    let data: BannerData
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: data.style.iconName)
                .font(.system(size: 16))
                .foregroundColor(data.style.primaryColor)
                .symbolEffect(.pulse, isActive: data.style == .error || data.style == .warning)
            
            Text(data.message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
        .overlay(
            Capsule()
                .strokeBorder(data.style.primaryColor.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(data.message)
    }
}

struct BannerModifier: ViewModifier {
    @Binding var data: BannerData?
    let autoDismissSeconds: TimeInterval
    
    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
            
            if let data = data {
                BannerView(data: data)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100) // Ensure it's on top
                    .onAppear {
                        // Haptic feedback
                        if data.style == .error {
                            UINotificationFeedbackGenerator().notificationOccurred(.error)
                        } else if data.style == .success {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissSeconds) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                self.data = nil
                            }
                        }
                    }
            }
        }
    }
}

extension View {
    func banner(data: Binding<BannerData?>, autoDismissSeconds: TimeInterval = 2.5) -> some View {
        modifier(BannerModifier(data: data, autoDismissSeconds: autoDismissSeconds))
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        
        VStack(spacing: 20) {
            BannerView(data: BannerData(message: "Network Error", style: .error))
            BannerView(data: BannerData(message: "Saved successfully", style: .success))
            BannerView(data: BannerData(message: "Processing...", style: .info))
        }
    }
}
