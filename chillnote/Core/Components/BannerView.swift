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
    
    var iconName: String {
        switch self {
        case .error:
            return "exclamationmark.triangle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .error:
            return .red
        case .success:
            return .green
        case .info:
            return .black
        }
    }
}

struct BannerView: View {
    let data: BannerData
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: data.style.iconName)
                .foregroundColor(.white)
            Text(data.message)
                .font(.bodySmall)
                .foregroundColor(.white)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(data.style.color.opacity(0.9))
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(data.message)
    }
}

struct BannerModifier: ViewModifier {
    @Binding var data: BannerData?
    let autoDismissSeconds: TimeInterval
    
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            if let data = data {
                BannerView(data: data)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissSeconds) {
                            withAnimation(.easeInOut) {
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
    VStack(spacing: 20) {
        BannerView(data: BannerData(message: "Microphone access is required.", style: .error))
        BannerView(data: BannerData(message: "Saved to Inbox.", style: .success))
        BannerView(data: BannerData(message: "Processing your note...", style: .info))
    }
    .padding()
}
