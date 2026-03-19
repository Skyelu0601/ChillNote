import SwiftUI

struct WelcomeUpgradeView: View {
    let onContinue: () -> Void

    @State private var showSubscription = false
    @StateObject private var storeService = StoreService.shared

    private let content = PaywallContext.postOnboardingWelcome.content

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.bgPrimary, Color.mellowYellow.opacity(0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        VStack(spacing: 18) {
                            Image("coffee")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 112, height: 112)
                                .shadow(color: .accentPrimary.opacity(0.15), radius: 10, x: 0, y: 4)

                            VStack(spacing: 10) {
                                Text(content.title)
                                    .font(.system(size: 30, weight: .bold, design: .rounded))
                                    .foregroundColor(.textMain)
                                    .multilineTextAlignment(.center)

                                Text(content.message)
                                    .font(.body)
                                    .foregroundColor(.textSub)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.top, 28)

                        VStack(alignment: .leading, spacing: 16) {
                            Text(L10n.text("welcome_upgrade.plan_summary_title"))
                                .font(.headline)
                                .foregroundColor(.textMain)

                            planRow(
                                title: L10n.text("welcome_upgrade.free_title"),
                                subtitle: L10n.text(
                                    "welcome_upgrade.free_summary",
                                    Int(StoreService.freeRecordingTimeLimit / 60),
                                    Int64(StoreService.freeDailyVoiceLimit),
                                    Int64(StoreService.freeDailyTidyLimit),
                                    Int64(StoreService.freeDailyAgentRecipeLimit),
                                    Int64(StoreService.freeDailyAIChatLimit)
                                ),
                                badge: L10n.text("welcome_upgrade.free_badge"),
                                badgeColor: .textSub
                            )

                            planRow(
                                title: L10n.text("welcome_upgrade.pro_title"),
                                subtitle: L10n.text("welcome_upgrade.pro_summary"),
                                badge: L10n.text("welcome_upgrade.pro_badge"),
                                badgeColor: .accentPrimary
                            )
                        }
                        .padding(22)
                        .background(Color.white)
                        .cornerRadius(24)
                        .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 6)

                        VStack(alignment: .leading, spacing: 16) {
                            Text(L10n.text("welcome_upgrade.why_upgrade_title"))
                                .font(.headline)
                                .foregroundColor(.textMain)

                            ForEach(content.benefits, id: \.self) { benefit in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentPrimary)
                                        .padding(.top, 2)
                                    Text(benefit)
                                        .font(.body)
                                        .foregroundColor(.textMain)
                                }
                            }
                        }
                        .padding(22)
                        .background(Color.white.opacity(0.92))
                        .cornerRadius(24)
                        .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 6)

                        VStack(spacing: 12) {
                            Button {
                                showSubscription = true
                            } label: {
                                Text(content.primaryButtonTitle)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.accentPrimary)
                                    .cornerRadius(18)
                                    .shadow(color: .accentPrimary.opacity(0.28), radius: 10, x: 0, y: 5)
                            }

                            Button {
                                onContinue()
                            } label: {
                                Text(content.secondaryButtonTitle)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.textSub)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                        }
                        .padding(.bottom, 28)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSubscription) {
                SubscriptionView()
            }
            .task {
                await storeService.refreshProducts()
                await storeService.refreshSubscriptionStatus()
            }
        }
    }

    private func planRow(title: String, subtitle: String, badge: String, badgeColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.textMain)
                Text(badge)
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(badgeColor)
                    .clipShape(Capsule())
            }

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.textSub)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
