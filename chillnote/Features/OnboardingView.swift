import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @Binding var isCompleted: Bool
    @State private var currentPage = 0
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Just Say It.",
            description: "Don't type. Just talk.\nChillNote captures your thoughts instantly.",
            icon: "mic.fill"
        ),
        OnboardingPage(
            title: "Let AI Do the Work.",
            description: "We tidy up your ramblings, tag them,\nand sort them into stacks automatically.",
            icon: "sparkles"
        ),
        OnboardingPage(
            title: "Your Second Brain.",
            description: "Review your week, find connections,\nand see your thoughts clearly.",
            icon: "brain.head.profile"
        )
    ]
    
    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()
            
            VStack {
                // Skip Button
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("Skip") {
                            withAnimation {
                                currentPage = pages.count - 1
                            }
                        }
                        .font(.bodySmall)
                        .foregroundColor(.textSub)
                        .padding()
                    } else {
                        // Placeholder to keep spacing
                        Text(" ").padding()
                    }
                }
                
                Spacer()
                
                // Page Content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        VStack(spacing: 24) {
                            
                            // Icon Circle
                            ZStack {
                                Circle()
                                    .fill(Color.paleCream.opacity(0.3))
                                    .frame(width: 200, height: 200)
                                
                                Circle()
                                    .fill(Color.paleCream.opacity(0.5))
                                    .frame(width: 150, height: 150)
                                
                                Image(systemName: pages[index].icon)
                                    .font(.system(size: 70))
                                    .foregroundColor(.accentPrimary)
                            }
                            .padding(.bottom, 20)
                            
                            Text(pages[index].title)
                                .font(.displayLarge)
                                .foregroundColor(.textMain)
                                .multilineTextAlignment(.center)
                            
                            Text(pages[index].description)
                                .font(.bodyLarge)
                                .foregroundColor(.textSub)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: 500) // Constrain height to keep buttons steady
                
                Spacer()
                
                // Indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.accentPrimary : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(currentPage == index ? 1.2 : 1.0)
                            .animation(.spring(), value: currentPage)
                    }
                }
                .padding(.bottom, 32)
                
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
                    Text(currentPage == pages.count - 1 ? "Enable Permissions & Start" : "Next")
                        .font(.bodyMedium)
                        .fontWeight(.bold)
                        .foregroundColor(.textMain)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentPrimary)
                        .cornerRadius(30)
                        .shadow(color: Color.accentPrimary.opacity(0.4), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .transition(.opacity)
    }

    private func requestPermissions(completion: @escaping () -> Void) {
        // Only request microphone permission (no Speech Recognition needed for Qwen ASR)
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
    let description: String
    let icon: String
}

#Preview {
    OnboardingView(isCompleted: .constant(false))
}
