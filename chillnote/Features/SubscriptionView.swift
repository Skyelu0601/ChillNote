import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var storeService = StoreService.shared
    
    // Animation States
    @State private var showContent = false
    @State private var isAnnual: Bool = true // Default to Annual
    
    private var yearlyProduct: Product? {
        storeService.availableProducts.first(where: { $0.subscription?.subscriptionPeriod.unit == .year })
        ?? storeService.availableProducts.first(where: { $0.id.lowercased().contains("year") })
    }

    private var monthlyProduct: Product? {
        storeService.availableProducts.first(where: { $0.subscription?.subscriptionPeriod.unit == .month })
        ?? storeService.availableProducts.first(where: { $0.id.lowercased().contains("month") })
    }

    private var yearlySavingsTag: String? {
        guard let monthlyProduct, let yearlyProduct else { return nil }
        guard monthlyProduct.price > 0 else { return nil }

        let yearlyMonthlyEquivalent = yearlyProduct.price / 12
        let savingsRatio = 1 - (yearlyMonthlyEquivalent / monthlyProduct.price)
        let savingsPercent = NSDecimalNumber(decimal: savingsRatio * 100).doubleValue.rounded()

        guard savingsPercent >= 1 else { return nil }
        return L10n.text("subscription.discount.save_percent", Int64(savingsPercent))
    }

    var selectedProduct: Product? {
        if isAnnual {
            return yearlyProduct ?? monthlyProduct
        }
        return monthlyProduct ?? yearlyProduct
    }

    private var selectedProductDisplayInfo: SubscriptionDisplayInfo? {
        guard let selectedProduct else { return nil }
        return storeService.subscriptionDisplayInfo(for: selectedProduct)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 1. Clean Premium Background
                cleanBackground
                    .ignoresSafeArea()
                
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
                    upgradeView
                }
                
                // Loading Overlay
                if storeService.isPurchasing {
                    loadingOverlay
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
                }
            }
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
                        Text(selectedProductDisplayInfo?.ctaText ?? (isAnnual ? L10n.text("subscription.cta.start_annual") : L10n.text("subscription.cta.start_monthly")))
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.accentPrimary)
                            .cornerRadius(16)
                            .shadow(color: .accentPrimary.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
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
                ProBrandHeader()

                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                    Text(L10n.text("subscription.current_plan"))
                }
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.05))
                .clipShape(Capsule())
            }
            .padding(.top, 20)
            
            // Membership Card
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(storeService.activeSubscriptionProductId?.localizedCaseInsensitiveContains("year") == true ? L10n.text("subscription.plan.annual") : L10n.text("subscription.plan.monthly"))
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
            .padding(20)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.05), radius: 15, x: 0, y: 5)
            
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
                        .font(.headline)
                        .foregroundColor(.accentPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentPrimary.opacity(0.1))
                        .cornerRadius(16)
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
    
    private var cleanBackground: some View {
        ZStack {
            // A very subtle, high-end gradient
            LinearGradient(
                colors: [
                    Color.bgPrimary,
                    Color.white
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Subtle texture simulation
            GeometryReader { proxy in
                Path { path in
                    let width = proxy.size.width
                    let height = proxy.size.height
                    path.move(to: CGPoint(x: 0, y: height * 0.2))
                    path.addCurve(
                        to: CGPoint(x: width, y: height * 0.4),
                        control1: CGPoint(x: width * 0.5, y: height * 0.1),
                        control2: CGPoint(x: width * 0.8, y: height * 0.5)
                    )
                }
                .stroke(Color.accentPrimary.opacity(0.03), lineWidth: 80)
                .blur(radius: 20)
            }
        }
    }
    
    private var heroSection: some View {
        VStack(spacing: 20) {
            ProBrandHeader()
            
            if storeService.currentTier == .pro {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                    Text(L10n.text("subscription.current_plan"))
                }
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.05))
                .clipShape(Capsule())
            }
        }
    }
    
    private var benefitsList: some View {
        VStack(spacing: 16) {
            BenefitRow(icon: "waveform", iconColor: .orange, title: L10n.text("subscription.benefit.deep_dives.title"), subtitle: L10n.text("subscription.benefit.deep_dives.subtitle"))
            BenefitRow(icon: "plus.app.fill", iconColor: .green, title: L10n.text("subscription.benefit.flexible_capture.title"), subtitle: L10n.text("subscription.benefit.flexible_capture.subtitle"))
            BenefitRow(icon: "bubble.left.and.bubble.right.fill", iconColor: Color(red: 0.43, green: 0.44, blue: 0.78), title: L10n.text("subscription.benefit.unlimited_chat.title"), subtitle: L10n.text("subscription.benefit.unlimited_chat.subtitle"))
            BenefitRow(icon: "wand.and.stars", iconColor: .blue, title: L10n.text("subscription.benefit.tidy_polish.title"), subtitle: L10n.text("subscription.benefit.tidy_polish.subtitle"))
            BenefitRow(icon: "slider.horizontal.3", iconColor: .teal, title: L10n.text("subscription.benefit.custom_skills.title"), subtitle: L10n.text("subscription.benefit.custom_skills.subtitle"))
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.04), radius: 15, x: 0, y: 5)
    }
    
    private var pricingSection: some View {
        VStack(spacing: 24) {
            // Toggle
            HStack(spacing: 0) {
                pricingToggleButton(title: L10n.text("subscription.interval.monthly"), isSelected: !isAnnual) {
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
                    .foregroundColor(.accentPrimary)
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
                    .foregroundColor(.accentPrimary)
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
                Link(L10n.text("subscription.terms_of_use"), destination: URL(string: "https://www.chillnoteai.com/terms.html")!)
                Link(L10n.text("subscription.privacy_policy"), destination: URL(string: "https://www.chillnoteai.com/privacy.html")!)
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
    let product: Product
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
                    .foregroundColor(.accentPrimary)
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
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: displayInfo.isAnnual ? .accentPrimary.opacity(0.15) : .black.opacity(0.05), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(displayInfo.isAnnual ? Color.accentPrimary : Color.clear, lineWidth: 2)
        )
    }
}

private struct ProBrandHeader: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            LaunchStyleWordmark()

            Text("Pro")
                .font(.system(size: 31, weight: .semibold, design: .rounded))
                .foregroundColor(Color(red: 0.184, green: 0.525, blue: 1.0))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(L10n.text("subscription.brand.pro_title")))
    }
}

private struct LaunchStyleWordmark: View {
    var body: some View {
        Text(L10n.text("auth.login.brand_title"))
            .font(.system(size: 31, weight: .semibold, design: .serif))
            .foregroundColor(.black)
    }
}

#Preview {
    SubscriptionView()
}
