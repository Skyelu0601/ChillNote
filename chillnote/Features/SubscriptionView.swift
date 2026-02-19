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

    var selectedProduct: Product? {
        if isAnnual {
            return yearlyProduct ?? monthlyProduct
        }
        return monthlyProduct ?? yearlyProduct
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
                        Text(isAnnual ? "Start Annual Plan" : "Start Monthly Plan")
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
                Image("pro")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 108, height: 108)
                    .shadow(color: .yellow.opacity(0.2), radius: 10, x: 0, y: 5)
                
                VStack(spacing: 8) {
                    Text("ChillNote Pro")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundColor(.textMain)
                }
            }
            .padding(.top, 20)
            
            // Membership Card
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(storeService.activeSubscriptionProductId?.localizedCaseInsensitiveContains("year") == true ? "Annual Plan" : "Monthly Plan")
                            .font(.headline)
                            .foregroundColor(.textMain)
                        
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Active")
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
                        Text("Renews on")
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
                Text("Your Active Privileges")
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
                    Text("Manage Subscription")
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
                    Text("Restore Purchases")
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
            Image("coffee")
                .resizable()
                .scaledToFit()
                .frame(width: 106, height: 106)
                .offset(y: 8)
            
            VStack(spacing: 8) {
                Text("Upgrade to Pro")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundColor(.textMain)
                
                Text("Unlock the full power of ChillNote")
                    .font(.body)
                    .foregroundColor(.textSub)
            }
            
            if storeService.currentTier == .pro {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                    Text("Current Plan")
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
            BenefitRow(icon: "waveform", iconColor: .orange, title: "10-Minute Deep Dives", subtitle: "Capture long thoughts without interruption")
            BenefitRow(icon: "bubble.left.and.bubble.right.fill", iconColor: Color(red: 0.43, green: 0.44, blue: 0.78), title: "Unlimited Chat", subtitle: "Ask Chillo anything about your notes.")
            BenefitRow(icon: "wand.and.stars", iconColor: .blue, title: "Infinite Tidy & Polish", subtitle: "Instantly turn messy ramblings into structured notes.")
            BenefitRow(icon: "slider.horizontal.3", iconColor: .teal, title: "Custom Chill Recipes", subtitle: "Create personalized AI recipes with Pro")
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
                pricingToggleButton(title: "Monthly", isSelected: !isAnnual) {
                    withAnimation(.spring()) { isAnnual = false }
                }
                pricingToggleButton(title: "Yearly", isSelected: isAnnual, discountTag: "SAVE 40%") {
                    withAnimation(.spring()) { isAnnual = true }
                }
            }
            .padding(4)
            .background(Color.black.opacity(0.04))
            .cornerRadius(12)
            
            // Selected Product Card
            if let product = selectedProduct {
                ProductHeroCard(product: product, isAnnual: isAnnual)
                    .id(product.id)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else if storeService.isLoadingProducts {
                ProgressView("Loading prices...")
                    .padding()
            } else if let error = storeService.productsErrorMessage {
                VStack(spacing: 10) {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await storeService.refreshProducts() }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.accentPrimary)
                }
            } else {
                VStack(spacing: 10) {
                    Text("No subscription product is currently available.")
                        .font(.caption)
                        .foregroundColor(.textSub)
                    Button("Retry") {
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
                Text("Restore Purchases")
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.textSub)
                    .underline()
            }
            
            HStack(spacing: 16) {
                Link("Terms", destination: URL(string: "https://www.chillnoteai.com/terms.html")!)
                Link("Privacy", destination: URL(string: "https://www.chillnoteai.com/privacy.html")!)
            }
            .font(.caption)
            .foregroundColor(.textSub.opacity(0.6))
            
            Text("Payment will be charged to your Apple ID account at confirmation of purchase.")
                .font(.caption2)
                .foregroundColor(.textSub.opacity(0.4))
                .multilineTextAlignment(.center)
            
            Text("Subscription automatically renews unless canceled at least 24 hours before the end of the current period.")
                .font(.caption2)
                .foregroundColor(.textSub.opacity(0.4))
                .multilineTextAlignment(.center)
            
            Text("Manage or cancel your subscription in Settings > Apple ID > Subscriptions.")
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
    let isAnnual: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            Text(isAnnual ? "BEST VALUE" : "FLEXIBLE")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundColor(isAnnual ? .white : .textSub)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isAnnual ? Color.accentPrimary : Color.black.opacity(0.05))
                .clipShape(Capsule())
            
            VStack(spacing: 0) {
                Text(product.displayPrice)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.textMain)
                
                Text(isAnnual ? "per year" : "per month")
                    .font(.body)
                    .foregroundColor(.textSub)
            }
            
            if isAnnual {
                Text("Save ~40% vs Monthly")
                    .font(.callout)
                    .foregroundColor(.accentPrimary)
                    .fontWeight(.medium)
            }

            Text(product.description)
                .font(.caption)
                .foregroundColor(.textSub)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: isAnnual ? .accentPrimary.opacity(0.15) : .black.opacity(0.05), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(isAnnual ? Color.accentPrimary : Color.clear, lineWidth: 2)
        )
    }
}

#Preview {
    SubscriptionView()
}
