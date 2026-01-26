import SwiftUI
import UIKit

struct TypewriterMarkdownText: View {
    let content: String
    let isNew: Bool
    
    @State private var displayedContent: String = ""
    @State private var isAnimating = false
    
    var body: some View {
        JustifiedMarkdownText(
            content: isNew ? displayedContent : content,
            font: UIFont.preferredFont(forTextStyle: .callout),
            textColor: UIColor(Color.textMain)
        )
            .onAppear {
                if isNew && !isAnimating {
                    startTypewriterEffect()
                } else {
                    displayedContent = content
                }
            }
            // Ensure if content changes drastically or view re-renders, we respect final state
            .onChange(of: content) { _, newValue in
                if !isAnimating {
                     displayedContent = newValue
                }
            }
    }
    
    private func startTypewriterEffect() {
        isAnimating = true
        displayedContent = ""
        
        let chars = Array(content)
        // Faster for longer text, slower for short text, but capped
        let baseDelay = 0.01
        
        Task {
            for (_, char) in chars.enumerated() {
                // Check cancellation or view disappearance? 
                // In SwiftUI Task handles cancellation automatically if view detaches.
                try? await Task.sleep(nanoseconds: UInt64(baseDelay * 1_000_000_000))
                
                await MainActor.run {
                    displayedContent.append(char)
                }
                
                // Speed up if user scrolls or long text? 
                // For now constant speed is "chill".
                // Optional: Randomize delay for human feel
            }
            await MainActor.run {
                isAnimating = false
                displayedContent = content // Ensure full consistency at end
            }
        }
    }
}
