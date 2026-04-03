import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var aiConsentManager: AIConsentManager
    @State private var consentSheetHeight: CGFloat = 360

    var body: some View {
        Group {
            switch authService.state {
            case .checking:
                if authService.canOptimisticallyEnterHome {
                    HomeView()
                } else {
                    ProgressView("Checking session...")
                }
            case .signedIn:
                HomeView()
            case .signedOut:
                LoginView()
            case .signingIn:
                LoginView()
            }
        }
        .sheet(item: consentPromptBinding) { prompt in
            AIConsentSheet(
                consentManager: aiConsentManager,
                prompt: prompt,
                measuredHeight: $consentSheetHeight
            )
            .presentationDetents([.height(consentSheetDetentHeight)])
        }
    }

    private var consentSheetDetentHeight: CGFloat {
        min(max(consentSheetHeight, 300), 560)
    }

    private var consentPromptBinding: Binding<AIConsentManager.Prompt?> {
        Binding(
            get: { aiConsentManager.activePrompt },
            set: { newValue in
                if newValue == nil {
                    aiConsentManager.declineAIDataConsent()
                }
            }
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(DataService.shared.container!)
        .environmentObject(AuthService.shared)
        .environmentObject(AIConsentManager.shared)
}
