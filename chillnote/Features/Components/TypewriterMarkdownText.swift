import SwiftUI
import UIKit

struct TypewriterMarkdownText: View {
    let content: String
    var isStreaming: Bool = false
    let shouldAnimate: Bool
    var onAnimationComplete: (() -> Void)? = nil
    
    @State private var displayedContent: String = ""
    @State private var isAnimating = false
    
    // Buffering for smooth streaming
    @State private var targetContent: String = ""
    @State private var isTypingBuffer = false
    
    var body: some View {
        JustifiedMarkdownText(
            content: shouldUseDisplayedContent ? displayedContent : content,
            font: UIFont.preferredFont(forTextStyle: .callout),
            textColor: UIColor(Color.textMain)
        )
        .onAppear {
            targetContent = content
            if shouldAnimate {
                startTypewriterEffect()
            } else if isStreaming {
                displayedContent = ""
                triggerStreamingTypewriter()
            } else {
                displayedContent = content
            }
        }
        .onChange(of: content) { _, newContent in
            targetContent = newContent
            if isStreaming || displayedContent.count < newContent.count {
                triggerStreamingTypewriter()
            } else if !isAnimating && !isStreaming {
                displayedContent = newContent
            }
        }
    }
    
    private var shouldUseDisplayedContent: Bool {
        if shouldAnimate && isAnimating { return true }
        if isStreaming { return true }
        // Continue showing partial text if catching up (prevents jump at end)
        if displayedContent.count < content.count && !displayedContent.isEmpty { return true }
        return false
    }
    
    private func startTypewriterEffect() {
        guard !isAnimating else { return }
        isAnimating = true
        displayedContent = ""
        
        let chars = Array(content)
        let baseDelay = 0.01
        
        Task {
            for (_, char) in chars.enumerated() {
                try? await Task.sleep(nanoseconds: UInt64(baseDelay * 1_000_000_000))
                
                await MainActor.run {
                    displayedContent.append(char)
                }
            }
            await MainActor.run {
                isAnimating = false
                displayedContent = content
                onAnimationComplete?()
            }
        }
    }
    
    private func triggerStreamingTypewriter() {
        guard !isTypingBuffer else { return }
        isTypingBuffer = true
        
        Task {
            // Continue typing until we catch up to targetContent
            while displayedContent.count < targetContent.count {
                // Determine next character to append
                // Use Array conversion for safety if indices are tricky, but direct access is faster
                let currentCount = displayedContent.count
                let targetChars = Array(targetContent) // Creating array potentially expensive in loop, but safe
                
                if currentCount < targetChars.count {
                    let char = targetChars[currentCount]
                    await MainActor.run {
                        displayedContent.append(char)
                    }
                }
                
                // Dynamic speed adjustment based on lag
                let lag = targetContent.count - displayedContent.count
                // Faster if lagging behind, slower for smooth "thinking" feel
                let delay: UInt64 = lag > 50 ? 5_000_000 : (lag > 20 ? 15_000_000 : 30_000_000)
                try? await Task.sleep(nanoseconds: delay)
            }
            
            isTypingBuffer = false
            
            // Double check if more content arrived
            if displayedContent.count < targetContent.count {
                triggerStreamingTypewriter()
            }
        }
    }
}
