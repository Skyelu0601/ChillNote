import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var aiConsentManager: AIConsentManager
    @StateObject private var voiceNotePaywallService = VoiceNotePaywallService.shared
    @State private var consentSheetHeight: CGFloat = 360
    @State private var showPostFirstVoiceSavePaywall = false

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
        .onChange(of: voiceNotePaywallService.shouldShowPaywall) { _, shouldShow in
            guard shouldShow else { return }
            showPostFirstVoiceSavePaywall = true
            voiceNotePaywallService.consumePaywallRequest()
        }
        .sheet(item: consentPromptBinding) { prompt in
            AIConsentSheet(
                consentManager: aiConsentManager,
                prompt: prompt,
                measuredHeight: $consentSheetHeight
            )
            .presentationDetents([.height(consentSheetDetentHeight)])
        }
        .sheet(isPresented: $showPostFirstVoiceSavePaywall) {
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
