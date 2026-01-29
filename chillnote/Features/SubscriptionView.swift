import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeService = StoreService.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image("chillo_touming") // Using chillo image as placeholder
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .padding(.top, 24)
                        
                        Text("Unlock ChillNote Pro")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.textMain)
                        
                        Text("Experience the freedom of thought with enhanced AI capabilities.")
                            .font(.body)
                            .foregroundColor(.textSub)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Features Comparison
                    VStack(spacing: 16) {
                        featureRow(icon: "mic.fill", title: "Recording Limit", free: "1 min", pro: "10 mins")
                        featureRow(icon: "bubble.left.and.bubble.right.fill", title: "AI Chat", free: "5/day", pro: "Unlimited")
                    }
                    .padding(20)
                    .background(Color.bgSecondary)
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    // Subscription Options
                    if storeService.availableProducts.isEmpty {
                        // Loading State or Error
                        if let error = storeService.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding()
                        } else {
                            ProgressView()
                                .padding()
                        }
                    } else {
                        VStack(spacing: 12) {
                            ForEach(storeService.availableProducts) { product in
                                Button(action: {
                                    Task {
                                        await storeService.purchase(product)
                                    }
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(product.displayName)
                                                .font(.headline)
                                                .foregroundColor(.textMain)
                                            Text(product.description)
                                                .font(.caption)
                                                .foregroundColor(.textSub)
                                        }
                                        
                                        Spacer()
                                        
                                        Text(product.displayPrice)
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.accentPrimary)
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(16)
                                    .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.accentPrimary.opacity(0.2), lineWidth: 1)
                                    )
                                }
                                .disabled(storeService.isPurchasing)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Restore Purchase
                    Button("Restore Purchases") {
                        Task {
                            await storeService.restorePurchases()
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.textSub)
                    .padding(.top, 8)
                    
                    // Footer
                    Text("Subscriptions auto-renew unless canceled at least 24 hours before the end of the current period. Manage via Apple ID settings.")
                        .font(.caption2)
                        .foregroundColor(.textSub.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(24)
                }
            }
            .background(Color.bgPrimary.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if storeService.isPurchasing {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        ProgressView()
                            .tint(.white)
                    }
                }
            }
        }
    }
    
    private func featureRow(icon: String, title: String, free: String, pro: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.accentPrimary)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.textMain)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(pro)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.accentPrimary)
                
                Text(free)
                    .font(.caption2)
                    .foregroundColor(.textSub)
                    .strikethrough(true, color: .textSub.opacity(0.5))
            }
        }
    }
}

#Preview {
    SubscriptionView()
}
