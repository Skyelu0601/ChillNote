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
    @State private var hasViewedIntroOnDevice = OnboardingStateStore.hasViewedIntroOnDevice()
    /// Reactive mirror of `OnboardingStateStore.hasShownIntroPaywall` for the
    /// current user. Plain UserDefaults reads don't trigger SwiftUI updates,
    /// so we keep an `@State` copy and flip it alongside the store write.
    @State private var introPaywallShownForCurrentUser = false

    var body: some View {
        rootView
            .onAppear {
                syncOnboardingState(for: authService.currentUserId)
                if let userId = authService.currentUserId,
                   !OnboardingStateStore.hasShownIntroPaywall(for: userId) {
                    Task { await resolvePostOnboardingDestination(for: userId) }
                }
            }
            .onChange(of: authService.currentUserId) { _, userId in
                guard let userId else {
                    hasCompletedOnboarding = false
                    showPostOnboardingPaywall = false
                    introPaywallShownForCurrentUser = false
                    return
                }

                // Onboarding now runs before login, so any signed-in user has implicitly
                // completed it. Seal the per-user flag once on first sign-in.
                if !OnboardingStateStore.hasCompleted(for: userId) {
                    OnboardingStateStore.setHasCompleted(true, for: userId)
                }
                hasCompletedOnboarding = true
                introPaywallShownForCurrentUser = OnboardingStateStore.hasShownIntroPaywall(for: userId)

                guard !introPaywallShownForCurrentUser else { return }

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
                    signedInView
                } else {
                    ProgressView(L10n.text("auth.session.checking"))
                }
            case .signedIn:
                signedInView
            case .signedOut:
                if hasViewedIntroOnDevice {
                    LoginView()
                } else {
                    OnboardingFlowView {
                        OnboardingStateStore.setHasViewedIntroOnDevice(true)
                        hasViewedIntroOnDevice = true
                    }
                }
            case .signingIn:
                LoginView()
            }
            }
        }
    }

    /// On first sign-in we want the user to see the trial paywall before Home —
    /// not Home flashing underneath while the paywall slides in. Until the intro
    /// paywall has been resolved (shown or skipped because user is already Pro),
    /// render a quiet brand-colored placeholder. The fullScreenCover for the
    /// paywall layers on top.
    @ViewBuilder
    private var signedInView: some View {
        if authService.currentUserId != nil, !introPaywallShownForCurrentUser {
            introPaywallGateView
        } else {
            HomeView()
        }
    }

    private var introPaywallGateView: some View {
        ZStack {
            BrandBackground()
            ProgressView()
                .tint(Color.accentPrimary)
                .scaleEffect(1.2)
        }
        .ignoresSafeArea()
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
        introPaywallShownForCurrentUser = true
        completeOnboarding(for: userId)
    }

    private func syncOnboardingState(for userId: String?) {
        hasCompletedOnboarding = OnboardingStateStore.hasCompleted(for: userId)
        introPaywallShownForCurrentUser = userId.map { OnboardingStateStore.hasShownIntroPaywall(for: $0) } ?? false
    }

    private func completeOnboarding(for userId: String) {
        OnboardingStateStore.setHasCompleted(true, for: userId)
        hasCompletedOnboarding = true
    }

    private func resolveIntroPaywallBeforeHome(for userId: String) async {
        await refreshSubscriptionStatusWithTimeout()

        guard authService.currentUserId == userId else { return }
        guard !OnboardingStateStore.hasShownIntroPaywall(for: userId) else {
            introPaywallShownForCurrentUser = true
            completeOnboarding(for: userId)
            return
        }

        if storeService.currentTier == .pro {
            OnboardingStateStore.setHasShownIntroPaywall(true, for: userId)
            introPaywallShownForCurrentUser = true
            completeOnboarding(for: userId)
            showPostOnboardingPaywall = false
            return
        }

        showPostOnboardingPaywall = true
    }

    private func resolvePostOnboardingDestination(for userId: String) async {
        await refreshSubscriptionStatusWithTimeout()

        guard authService.currentUserId == userId else { return }
        guard OnboardingStateStore.hasCompleted(for: userId) else { return }
        guard !OnboardingStateStore.hasShownIntroPaywall(for: userId) else {
            introPaywallShownForCurrentUser = true
            return
        }

        if storeService.currentTier == .pro {
            OnboardingStateStore.setHasShownIntroPaywall(true, for: userId)
            introPaywallShownForCurrentUser = true
            showPostOnboardingPaywall = false
            return
        }

        showPostOnboardingPaywall = true
    }

    /// Refresh subscription status but never block the UI for more than 3s.
    /// If the network is down or the backend is unreachable, we fall through
    /// and present the paywall (or release the gate) rather than leaving the
    /// user stuck on a loading screen.
    private func refreshSubscriptionStatusWithTimeout(seconds: Double = 3.0) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await storeService.refreshSubscriptionStatus() }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            }
            await group.next()
            group.cancelAll()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(DataService.shared.container!)
        .environmentObject(AuthService.shared)
        .environmentObject(AIConsentManager.shared)
}
