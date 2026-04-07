import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var aiConsentManager: AIConsentManager
    @StateObject private var storeService = StoreService.shared
    @State private var consentSheetHeight: CGFloat = 360
    @State private var showPostLoginPaywall = false

    var body: some View {
        Group {
            switch authService.state {
            case .checking:
                if authService.canOptimisticallyEnterHome {
                    HomeView()
                } else {
                    ProgressView(L10n.text("auth.session.checking"))
                }
            case .signedIn:
                HomeView()
            case .signedOut:
                LoginView()
            case .signingIn:
                LoginView()
            }
        }
        .onChange(of: authService.shouldShowPostLoginPaywall) { _, shouldShow in
            guard shouldShow, storeService.currentTier != .pro else { return }
            showPostLoginPaywall = true
            authService.consumePostLoginPaywallRequest()
        }
        .sheet(item: consentPromptBinding) { prompt in
            AIConsentSheet(
                consentManager: aiConsentManager,
                prompt: prompt,
                measuredHeight: $consentSheetHeight
            )
            .presentationDetents([.height(consentSheetDetentHeight)])
        }
        .sheet(isPresented: $showPostLoginPaywall) {
            SubscriptionView()
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
