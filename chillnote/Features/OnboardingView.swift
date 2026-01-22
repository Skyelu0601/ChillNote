import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @Binding var isCompleted: Bool
    @State private var currentPage = 0
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Capture at the\nSpeed of Thought",
            image: "notion_style_capture"
        ),
        OnboardingPage(
            title: "Chaos in,\nClarity out",
            image: "notion_style_clarity"
        ),
        OnboardingPage(
            title: "Build Assets,\nNot Just Notes",
            image: "notion_style_assets"
        )
    ]
    
    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Bar
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("Skip") {
                            withAnimation {
                                currentPage = pages.count - 1
                            }
                        }
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.textSub)
                        .padding()
                    }
                }
                
                Spacer()
                
                // Content Layer
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        VStack(spacing: 40) {
                            // Illustration
                            Image(pages[index].image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 300)
                                .padding(.horizontal, 40)
                            
                            // Headline
                            Text(pages[index].title)
                                .font(.system(size: 32, weight: .bold, design: .serif))
                                .foregroundColor(.textMain)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(maxHeight: 500)
                
                Spacer()
                
                // Indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.accentPrimary : Color.accentPrimary.opacity(0.2))
                            .frame(width: 8, height: 8)
                            .animation(.spring(), value: currentPage)
                    }
                }
                .padding(.bottom, 40)
                
                // Action Button
                Button(action: {
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        requestPermissions {
                            withAnimation {
                                isCompleted = true
                            }
                        }
                    }
                }) {
                    Text(currentPage == pages.count - 1 ? "Get Started" : "Continue")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.textMain)
                        )
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
        }
    }
    
    private func requestPermissions(completion: @escaping () -> Void) {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { _ in
                DispatchQueue.main.async {
                    completion()
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { _ in
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }
}

struct OnboardingPage {
    let title: String
    let image: String
}

#Preview {
    OnboardingView(isCompleted: .constant(false))
}
