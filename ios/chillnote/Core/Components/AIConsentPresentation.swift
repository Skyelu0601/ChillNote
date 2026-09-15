import SwiftUI

struct AIConsentPresentation: ViewModifier {
    @ObservedObject var manager: AIConsentManager
    @State private var measuredHeight: CGFloat = 360

    func body(content: Content) -> some View {
        content.sheet(item: promptBinding) { prompt in
            AIConsentSheet(consentManager: manager, prompt: prompt, measuredHeight: $measuredHeight)
                .presentationDetents([.height(min(max(measuredHeight, 300), 560))])
        }
    }

    private var promptBinding: Binding<AIConsentManager.Prompt?> {
        let promptID = manager.activePrompt?.id
        return Binding(
            get: { manager.activePrompt },
            set: { value in
                if value == nil, let promptID {
                    manager.declineAIDataConsent(promptID: promptID)
                }
            }
        )
    }
}
