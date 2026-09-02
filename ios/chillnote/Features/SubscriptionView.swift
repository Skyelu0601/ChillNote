import SwiftUI
import StoreKit

enum SubscriptionViewContext: Equatable {
    case standard
    case onboardingTrial
}

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var storeService = StoreService.shared
    private let context: SubscriptionViewContext
    
    // Animation States
    @State private var showContent = false
    @State private var isAnnual: Bool = true // Default to Annual
    @State private var showOnboardingPaywallDetails = false

    init(context: SubscriptionViewContext = .standard) {
        self.context = context
    }
    
    private var yearlyProduct: SubscriptionProduct? {
        storeService.availableProducts.first(where: { $0.subscription?.subscriptionPeriod.unit == .year })
        ?? storeService.availableProducts.first(where: { $0.id.lowercased().contains("year") })
    }

    private var weeklyProduct: SubscriptionProduct? {
        storeService.availableProducts.first(where: { $0.subscription?.subscriptionPeriod.unit == .week })
        ?? storeService.availableProducts.first(where: { $0.id.lowercased().contains("week") })
    }

    private var yearlySavingsTag: String? {
        guard let weeklyProduct, let yearlyProduct else { return nil }
        guard weeklyProduct.price > 0 else { return nil }

        let yearlyWeeklyEquivalent = yearlyProduct.price / 52
        let savingsRatio = 1 - (yearlyWeeklyEquivalent / weeklyProduct.price)
        let savingsPercent = NSDecimalNumber(decimal: savingsRatio * 100).doubleValue.rounded()

        guard savingsPercent >= 1 else { return nil }
        return L10n.text("subscription.discount.save_percent", Int64(savingsPercent))
    }

    var selectedProduct: SubscriptionProduct? {
        if isAnnual {
            return yearlyProduct ?? weeklyProduct
        }
        return weeklyProduct ?? yearlyProduct
    }

    private var selectedProductDisplayInfo: SubscriptionDisplayInfo? {
        guard let selectedProduct else { return nil }
        return storeService.subscriptionDisplayInfo(for: selectedProduct)
    }

    private var isOnboardingPaywall: Bool {
        if case .onboardingTrial = context {
            return true
        }
        return false
    }

    private var isShowingOnboardingIntro: Bool {
        isOnboardingPaywall && !showOnboardingPaywallDetails
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isShowingOnboardingIntro {
                    BrandBackground().ignoresSafeArea()
                } else if isOnboardingPaywall {
                    Color.white.ignoresSafeArea()
                } else {
                    BrandBackground().ignoresSafeArea()
                }
                
                if storeService.currentTier == .pro {
                    // Member View
                    ScrollView {
                        memberView
                            .padding(.top, 20)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 100)
                    }
                    .scrollIndicators(.hidden)
                } else {
                    // Upgrade View
                    if context == .onboardingTrial {
                        if showOnboardingPaywallDetails {
                            onboardingTrialView
                        } else {
                            onboardingTrialIntroView
                        }
                    } else {
                        upgradeView
                    }
                }
                
                // Loading Overlay
                if storeService.isPurchasing {
                    loadingOverlay
                }
            }
            .toolbar {
                if isShowingOnboardingIntro {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.textMain.opacity(0.5))
                                .padding(8)
                                .background(Color.black.opacity(0.05))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(L10n.text("common.close"))
                    }
                } else if isOnboardingPaywall {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Color.textMain)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(L10n.text("common.close"))
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await storeService.restorePurchases() }
                        } label: {
                            Text(L10n.text("subscription.action.restore"))
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(Color.textMain)
                        }
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.textMain.opacity(0.5))
                                .padding(8)
                                .background(Color.black.opacity(0.05))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(L10n.text("common.close"))
                    }
                }
            }
            .toolbarBackground(isOnboardingPaywall && !isShowingOnboardingIntro ? Color.white : Color.clear, for: .navigationBar)
            .toolbarBackground(isOnboardingPaywall && !isShowingOnboardingIntro ? .visible : .automatic, for: .navigationBar)
            .onAppear {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                    showContent = true
                }
            }
            .task {
                await storeService.refreshProducts()
                // Refresh subscription status to get latest expiration date
                await storeService.refreshSubscriptionStatus()
            }
        }
    }

    // MARK: - Views

    private var onboardingTrialIntroView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 34) {
                Text(onboardingTrialIntroTitle)
                    .font(.brandDisplay)
                    .foregroundColor(.textMain)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)

                Spacer(minLength: 10)

                OnboardingTrialLogo(size: 148)

                Spacer(minLength: 18)

                OnboardingTrialNoPaymentView(textKey: "subscription.onboarding.no_payment_due_now")

                Spacer(minLength: 22)
            }
            .padding(.horizontal, 28)
            .padding(.top, 50)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 16) {
                Button {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                        showOnboardingPaywallDetails = true
                    }
                } label: {
                    HStack(spacing: BrandTokens.Space.s1) {
                        Text(L10n.text("subscription.onboarding.cta.next"))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .brandPrimaryCTAStyle()
                }

                onboardingTrialIntroFooter
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
            .background(
                LinearGradient(
                    colors: [.white.opacity(0.0), .white, .white],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
            )
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 18)
    }

    private var onboardingTrialIntroFooter: some View {
        HStack(spacing: 18) {
            Link(L10n.text("subscription.terms_of_use"), destination: URL(string: "https://www.chillnoteai.com/terms")!)

            Button {
                Task { await storeService.restorePurchases() }
            } label: {
                Text(L10n.text("subscription.restore_purchases"))
            }

            Link(L10n.text("subscription.privacy_policy"), destination: URL(string: "https://www.chillnoteai.com/privacy")!)
        }
        .font(.brandLabel)
        .foregroundColor(.textSub.opacity(0.72))
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .padding(.top, 8)
    }

    private var onboardingTrialIntroTitle: AttributedString {
        var title = AttributedString(L10n.text("subscription.onboarding.title"))
        title.foregroundColor = Color.textMain

        if let brandRange = title.range(of: "ChillScript") {
            title[brandRange].foregroundColor = Color.accentPrimary
        }

        return title
    }

    private var onboardingTrialView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(L10n.text("subscription.onboarding.paywall.title"))
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(Color.textMain)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(-2)
                    .fixedSize(horizontal: false, vertical: true)

                OnboardingTrialFeatureList()

                onboardingPlanPicker

                onboardingTrialCTA

                VStack(spacing: 14) {
                    Text(onboardingTrustText)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.textMain.opacity(0.82))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    onboardingTrialFooter
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 20)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 18)
        }
        .background(Color.white)
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var onboardingPlanPicker: some View {
        if yearlyProduct != nil || weeklyProduct != nil {
            VStack(spacing: 10) {
                if let yearlyProduct {
                    let displayInfo = storeService.subscriptionDisplayInfo(for: yearlyProduct)
                    OnboardingPlanCard(
                        title: onboardingAnnualTitle(displayInfo),
                        billingText: L10n.text(
                            "subscription.price_per_year",
                            compactPrice(for: yearlyProduct)
                        ),
                        comparisonPrice: displayInfo.equivalentWeeklyText ?? compactPrice(for: yearlyProduct),
                        comparisonPeriod: L10n.text("subscription.billing_period.weekly"),
                        isSelected: selectedProduct?.id == yearlyProduct.id
                    ) {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            isAnnual = true
                        }
                    }
                }

                if let weeklyProduct {
                    OnboardingPlanCard(
                        title: L10n.text("subscription.interval.weekly"),
                        billingText: nil,
                        comparisonPrice: weeklyProduct.displayPrice,
                        comparisonPeriod: L10n.text("subscription.billing_period.weekly"),
                        isSelected: selectedProduct?.id == weeklyProduct.id
                    ) {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            isAnnual = false
                        }
                    }
                }
            }
        } else if storeService.isLoadingProducts {
            ProgressView(L10n.text("subscription.loading_prices"))
                .font(.brandBodySmall)
                .padding(.vertical, 28)
        } else {
            VStack(spacing: 10) {
                Text(storeService.productsErrorMessage ?? L10n.text("subscription.unavailable"))
                    .font(.brandBodySmall)
                    .foregroundColor(storeService.productsErrorMessage == nil ? .textSub : .red)
                    .multilineTextAlignment(.center)
                Button(L10n.text("common.retry")) {
                    Task { await storeService.refreshProducts() }
                }
                .font(.brandLabel)
                .foregroundColor(.accentPrimaryText)
            }
            .padding(.vertical, 20)
        }
    }

    private func compactPrice(for product: SubscriptionProduct) -> String {
        product.price.formatted(
            product.priceFormatStyle.precision(.fractionLength(0...2))
        )
    }

    private func onboardingAnnualTitle(_ displayInfo: SubscriptionDisplayInfo) -> String {
        if let dayCount = displayInfo.trialDayCount {
            return L10n.text("subscription.onboarding.plan.annual_trial_days", Int64(dayCount))
        }
        return L10n.text("subscription.interval.yearly")
    }

    private var onboardingTrustText: String {
        if selectedProductDisplayInfo?.hasFreeTrial == true {
            return L10n.text("subscription.onboarding.trust.no_payment_cancel_anytime")
        }
        return L10n.text("subscription.onboarding.trust.cancel_anytime")
    }

    private var onboardingTrialCTA: some View {
        Button {
            if let product = selectedProduct {
                Task { await storeService.purchase(product) }
            }
        } label: {
            Text(onboardingCTAtext)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.accentPrimary)
                )
        }
        .disabled(selectedProduct == nil || storeService.isPurchasing)
    }

    private var onboardingCTAtext: String {
        if let dayCount = selectedProductDisplayInfo?.trialDayCount {
            return L10n.text("subscription.onboarding.cta.try_free_days", Int64(dayCount))
        }
        return selectedProductDisplayInfo?.isAnnual == true
            ? L10n.text("subscription.cta.continue_annual")
            : L10n.text("subscription.cta.continue_weekly")
    }

    private var onboardingTrialFooter: some View {
        HStack(spacing: 30) {
            Link(L10n.text("subscription.terms_of_use"), destination: URL(string: "https://www.chillnoteai.com/terms")!)

            Link(L10n.text("subscription.privacy_policy"), destination: URL(string: "https://www.chillnoteai.com/privacy")!)
        }
        .font(.system(size: 13, weight: .regular))
        .foregroundStyle(Color.textMain.opacity(0.86))
        .underline()
        .frame(maxWidth: .infinity)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }

    
    private var upgradeView: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 32) {
                    // 2. Hero Section
                    heroSection
                        .padding(.top, 20)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                    
                    // 3. Features Benefits
                    benefitsList
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 30)
                    
                    // 4. Pricing Section
                    pricingSection
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 40)
                    
                    // 5. Footer
                    footerSection
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 50)
                        .padding(.bottom, 100) // Space for floating button
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
            
            // Sticky CTA Button
            VStack {
                Spacer()
                if let product = selectedProduct {
                    Button {
                        Task { await storeService.purchase(product) }
                    } label: {
                        Text(selectedProductDisplayInfo?.ctaText ?? (isAnnual ? L10n.text("subscription.cta.start_annual") : L10n.text("subscription.cta.start_weekly")))
                            .brandPrimaryCTAStyle()
                    }
                    .padding(.horizontal, BrandTokens.Space.s4)
                    .padding(.bottom, BrandTokens.Space.s4)
                    .disabled(storeService.isPurchasing)
                    .opacity(showContent ? 1 : 0)
                }
            }
        }
    }
    
    private var memberView: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 16) {
                BrandWordmark()
            }
            .padding(.top, 20)
            
            // Membership Card
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(activePlanTitle)
                            .font(.headline)
                            .foregroundColor(.textMain)
                        
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text(L10n.text("subscription.status.active"))
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundColor(.accentPrimary)
                }
                
                Divider()
                
                if let expirationDate = storeService.subscriptionExpirationDate {
                    HStack {
                        Text(L10n.text("subscription.renews_on"))
                            .font(.subheadline)
                            .foregroundColor(.textSub)
                        Spacer()
                        Text(expirationDate.formatted(date: .long, time: .omitted))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.textMain)
                    }
                }
            }
            .padding(BrandTokens.Space.s4)
            .background(
                RoundedRectangle(cornerRadius: BrandTokens.Radius.card, style: .continuous)
                    .fill(Color.cardBackground)
                    .brandShadow(BrandTokens.Shadow.card)
            )
            
            // Active Benefits
            VStack(alignment: .leading, spacing: 20) {
                Text(L10n.text("subscription.active_privileges"))
                    .font(.headline)
                    .foregroundColor(.textMain)
                    .padding(.leading, 4)
                
                benefitsList
            }
            
            // Actions
            VStack(spacing: 16) {
                Button {
                    guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
                    openURL(url)
                } label: {
                    Text(L10n.text("subscription.manage"))
                        .font(.brandButton)
                        .foregroundColor(.accentPrimaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: BrandTokens.Size.primaryButtonHeight)
                        .background(
                            RoundedRectangle(cornerRadius: BrandTokens.Radius.button, style: .continuous)
                                .fill(Color.accentPrimary.opacity(0.1))
                        )
                }
                
                Button {
                    Task { await storeService.restorePurchases() }
                } label: {
                    Text(L10n.text("subscription.restore_purchases"))
                        .font(.footnote.weight(.medium))
                        .foregroundColor(.textSub)
                        .underline()
                }
            }
            .padding(.top, 10)
        }
    }
    
    private var heroSection: some View {
        VStack(spacing: 20) {
            BrandWordmark()
        }
    }

    private var activePlanTitle: String {
        let productId = storeService.activeSubscriptionProductId ?? ""
        if productId.localizedCaseInsensitiveContains("year") {
            return L10n.text("subscription.plan.annual")
        }
        if productId.localizedCaseInsensitiveContains("month") {
            return L10n.text("subscription.plan.monthly")
        }
        return L10n.text("subscription.plan.weekly")
    }
    
    private var benefitsList: some View {
        VStack(spacing: 16) {
            BenefitRow(icon: "slider.horizontal.3", iconColor: .teal, title: L10n.text("subscription.benefit.custom_skills.title"), subtitle: L10n.text("subscription.benefit.custom_skills.subtitle"))
            BenefitRow(icon: "plus.app.fill", iconColor: .green, title: L10n.text("subscription.benefit.flexible_capture.title"), subtitle: L10n.text("subscription.benefit.flexible_capture.subtitle"))
            BenefitRow(icon: "bubble.left.and.bubble.right.fill", iconColor: Color(red: 0.43, green: 0.44, blue: 0.78), title: L10n.text("subscription.benefit.unlimited_chat.title"), subtitle: L10n.text("subscription.benefit.unlimited_chat.subtitle"))
            BenefitRow(icon: "lightbulb.max.fill", iconColor: .orange, title: L10n.text("subscription.benefit.deep_dives.title"), subtitle: L10n.text("subscription.benefit.deep_dives.subtitle"))
        }
        .padding(BrandTokens.Space.s4)
        .background(
            RoundedRectangle(cornerRadius: BrandTokens.Radius.card, style: .continuous)
                .fill(Color.cardBackground)
                .brandShadow(BrandTokens.Shadow.card)
        )
    }

    private var pricingSection: some View {
        VStack(spacing: 24) {
            // Toggle
            HStack(spacing: 0) {
                pricingToggleButton(title: L10n.text("subscription.interval.weekly"), isSelected: !isAnnual) {
                    withAnimation(.spring()) { isAnnual = false }
                }
                pricingToggleButton(title: L10n.text("subscription.interval.yearly"), isSelected: isAnnual, discountTag: yearlySavingsTag) {
                    withAnimation(.spring()) { isAnnual = true }
                }
            }
            .padding(4)
            .background(Color.black.opacity(0.04))
            .cornerRadius(12)
            
            // Selected Product Card
            if let product = selectedProduct {
                ProductHeroCard(
                    product: product,
                    displayInfo: storeService.subscriptionDisplayInfo(for: product)
                )
                    .id(product.id)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else if storeService.isLoadingProducts {
                ProgressView(L10n.text("subscription.loading_prices"))
                    .padding()
            } else if let error = storeService.productsErrorMessage {
                VStack(spacing: 10) {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                    Button(L10n.text("common.retry")) {
                        Task { await storeService.refreshProducts() }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.accentPrimaryText)
                }
            } else {
                VStack(spacing: 10) {
                    Text(L10n.text("subscription.unavailable"))
                        .font(.caption)
                        .foregroundColor(.textSub)
                    Button(L10n.text("common.retry")) {
                        Task { await storeService.refreshProducts() }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.accentPrimaryText)
                }
            }
        }
    }
    
    private func pricingToggleButton(title: String, isSelected: Bool, discountTag: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                
                if let tag = discountTag {
                    Text(tag)
                        .font(.custom("Menlo-Bold", size: 9))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.accentPrimary)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.white : Color.clear)
            .foregroundColor(isSelected ? .textMain : .textSub)
            .cornerRadius(10)
            .shadow(color: isSelected ? .black.opacity(0.1) : .clear, radius: 4, x: 0, y: 2)
        }
    }
    
    private var footerSection: some View {
        VStack(spacing: 16) {
            Button {
                Task { await storeService.restorePurchases() }
            } label: {
                Text(L10n.text("subscription.restore_purchases"))
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.textSub)
                    .underline()
            }
            
            HStack(spacing: 16) {
                Link(L10n.text("subscription.terms_of_use"), destination: URL(string: "https://www.chillnoteai.com/terms")!)
                Link(L10n.text("subscription.privacy_policy"), destination: URL(string: "https://www.chillnoteai.com/privacy")!)
            }
            .font(.caption)
            .foregroundColor(.textSub.opacity(0.6))
            
            Text(L10n.text("subscription.footer.payment_disclaimer"))
                .font(.caption2)
                .foregroundColor(.textSub.opacity(0.4))
                .multilineTextAlignment(.center)
            
            Text(L10n.text("subscription.footer.renewal_disclaimer"))
                .font(.caption2)
                .foregroundColor(.textSub.opacity(0.4))
                .multilineTextAlignment(.center)
            
            Text(L10n.text("subscription.footer.manage_disclaimer"))
                .font(.caption2)
                .foregroundColor(.textSub.opacity(0.4))
                .multilineTextAlignment(.center)
        }
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
        }
    }
}

// MARK: - Subcomponents

struct BenefitRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textMain)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.textSub)
            }
            Spacer()
        }
    }
}

struct ProductHeroCard: View {
    let product: SubscriptionProduct
    let displayInfo: SubscriptionDisplayInfo
    
    var body: some View {
        VStack(spacing: 12) {
            Text(displayInfo.badgeText)
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundColor(displayInfo.hasFreeTrial || displayInfo.isAnnual ? .white : .textSub)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(displayInfo.hasFreeTrial || displayInfo.isAnnual ? Color.accentPrimary : Color.black.opacity(0.05))
                .clipShape(Capsule())
            
            VStack(spacing: 0) {
                Text(product.displayPrice)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.textMain)
                
                Text(displayInfo.billingPeriodText)
                    .font(.body)
                    .foregroundColor(.textSub)
            }
            
            if let equivalentMonthlyLine = displayInfo.equivalentMonthlyText {
                Text(equivalentMonthlyLine)
                    .font(.callout)
                    .foregroundColor(.accentPrimaryText)
                    .fontWeight(.medium)
            }

            if let renewalText = displayInfo.renewalText {
                Text(renewalText)
                    .font(.callout)
                    .foregroundColor(.textMain)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BrandTokens.Space.s4)
        .background(
            RoundedRectangle(cornerRadius: BrandTokens.Radius.card, style: .continuous)
                .fill(Color.cardBackground)
                .shadow(color: displayInfo.isAnnual ? .accentPrimary.opacity(0.15) : .black.opacity(0.05), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BrandTokens.Radius.card, style: .continuous)
                .stroke(displayInfo.isAnnual ? Color.accentPrimary : Color.clear, lineWidth: 2)
        )
    }
}

private struct OnboardingPlanCard: View {
    let title: String
    let billingText: String?
    let comparisonPrice: String
    let comparisonPeriod: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentPrimary : Color.white)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? Color.accentPrimary : Color.borderSubtle, lineWidth: 1.5)
                        )

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.accentPrimaryText : Color.textMain)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    if let billingText {
                        Text(billingText)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Color.textMain)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(comparisonPrice)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color.textMain)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    Text(comparisonPeriod)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.textMain.opacity(0.82))
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 86)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.accentPrimary.opacity(0.035) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.accentPrimary : Color.borderSubtle, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct OnboardingTrialLogo: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.accentPrimary.opacity(0.07), lineWidth: 1)
                .frame(width: size * 1.28, height: size * 1.28)

            Circle()
                .stroke(Color.accentPrimary.opacity(0.10), lineWidth: 1)
                .frame(width: size * 1.02, height: size * 1.02)

            Circle()
                .fill(Color.accentPrimary.opacity(0.12))
                .frame(width: size * 0.74, height: size * 0.74)
                .blur(radius: size * 0.10)

            NoteDetailLightningBallIcon(size: size)
                .shadow(color: Color.accentPrimary.opacity(0.18), radius: 18, x: 0, y: 10)
        }
        .frame(width: size * 1.32, height: size * 1.32)
        .accessibilityHidden(true)
    }
}

private struct OnboardingTrialNoPaymentView: View {
    let textKey: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 23, weight: .bold))
                .foregroundColor(.green)

            Text(L10n.text(textKey))
                .font(.brandTitle2)
                .foregroundColor(.textMain)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct OnboardingTrialFeatureList: View {
    private let features = [
        (key: "subscription.onboarding.feature.save_ideas", icon: "play.rectangle"),
        (key: "subscription.onboarding.feature.transcribe_extract", icon: "waveform"),
        (key: "subscription.onboarding.feature.generate_content", icon: "sparkles"),
        (key: "subscription.onboarding.feature.rewrite_translate", icon: "character.bubble"),
        (key: "subscription.onboarding.feature.repurpose_social", icon: "rectangle.3.group"),
        (key: "subscription.onboarding.feature.organize", icon: "folder"),
        (key: "subscription.onboarding.feature.teleprompter", icon: "text.rectangle.page")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            ForEach(Array(features.enumerated()), id: \.offset) { _, feature in
                HStack(spacing: 16) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(Color.textMain)
                        .frame(width: 28, height: 32)

                    Text(L10n.text(feature.key))
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color.textMain)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)

                    Spacer(minLength: 0)
                }
                .frame(minHeight: 32)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    SubscriptionView()
}

#Preview("Onboarding Trial") {
    SubscriptionView(context: .onboardingTrial)
}
