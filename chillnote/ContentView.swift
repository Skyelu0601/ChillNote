import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var aiConsentManager: AIConsentManager
    @StateObject private var storeService = StoreService.shared
    @StateObject private var voiceNotePaywallService = VoiceNotePaywallService.shared
    @State private var consentSheetHeight: CGFloat = 360
    @State private var showPostFirstVoiceSavePaywall = false
    @State private var showPostOnboardingPaywall = false
    @State private var hasCompletedOnboarding = false

    var body: some View {
        rootView
            .onAppear {
                syncOnboardingState(for: authService.currentUserId)
            }
            .onChange(of: authService.currentUserId) { _, userId in
                guard let userId else {
                    hasCompletedOnboarding = false
                    showPostOnboardingPaywall = false
                    return
                }

                let hasCompleted = OnboardingStateStore.hasCompleted(for: userId)
                hasCompletedOnboarding = hasCompleted

                guard hasCompleted,
                      !OnboardingStateStore.hasShownIntroPaywall(for: userId) else {
                    return
                }

                Task {
                    await resolvePostOnboardingDestination(for: userId)
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
            .fullScreenCover(isPresented: $showPostOnboardingPaywall, onDismiss: markIntroPaywallSeen) {
                SubscriptionView(context: .onboardingTrial)
            }
    }

    @ViewBuilder
    private var rootView: some View {
        Group {
            if AppLaunchOptions.isOnboardingScreenshotMode {
                OnboardingFlowView(
                    initialPage: AppLaunchOptions.onboardingScreenshotPage,
                    onFinish: {}
                )
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
            } else {
            switch authService.state {
            case .checking:
                if authService.canOptimisticallyEnterHome, hasCompletedOnboarding {
                    HomeView()
                } else {
                    ProgressView(L10n.text("auth.session.checking"))
                }
            case .signedIn(let userId):
                if hasCompletedOnboarding {
                    HomeView()
                } else {
                    OnboardingFlowView {
                        finishOnboarding(for: userId)
                    }
                }
            case .signedOut:
                LoginView()
            case .signingIn:
                LoginView()
            }
            }
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

    private func finishOnboarding(for userId: String) {
        if OnboardingStateStore.hasShownIntroPaywall(for: userId) {
            completeOnboarding(for: userId)
            return
        }

        Task {
            await resolveIntroPaywallBeforeHome(for: userId)
        }
    }

    private func markIntroPaywallSeen() {
        guard let userId = authService.currentUserId else { return }
        OnboardingStateStore.setHasShownIntroPaywall(true, for: userId)
        completeOnboarding(for: userId)
    }

    private func syncOnboardingState(for userId: String?) {
        hasCompletedOnboarding = OnboardingStateStore.hasCompleted(for: userId)
    }

    private func completeOnboarding(for userId: String) {
        OnboardingStateStore.setHasCompleted(true, for: userId)
        hasCompletedOnboarding = true
    }

    private func resolveIntroPaywallBeforeHome(for userId: String) async {
        await storeService.refreshSubscriptionStatus()

        guard authService.currentUserId == userId else { return }
        guard !OnboardingStateStore.hasShownIntroPaywall(for: userId) else {
            completeOnboarding(for: userId)
            return
        }

        if storeService.currentTier == .pro {
            OnboardingStateStore.setHasShownIntroPaywall(true, for: userId)
            completeOnboarding(for: userId)
            showPostOnboardingPaywall = false
            return
        }

        showPostOnboardingPaywall = true
    }

    private func resolvePostOnboardingDestination(for userId: String) async {
        await storeService.refreshSubscriptionStatus()

        guard authService.currentUserId == userId else { return }
        guard OnboardingStateStore.hasCompleted(for: userId) else { return }
        guard !OnboardingStateStore.hasShownIntroPaywall(for: userId) else { return }

        if storeService.currentTier == .pro {
            OnboardingStateStore.setHasShownIntroPaywall(true, for: userId)
            showPostOnboardingPaywall = false
            return
        }

        showPostOnboardingPaywall = true
    }
}

#Preview {
    ContentView()
        .modelContainer(DataService.shared.container!)
        .environmentObject(AuthService.shared)
        .environmentObject(AIConsentManager.shared)
}
