import Foundation
import StoreKit

enum SubscriptionTier: String, CaseIterable {
    case free
    case pro
}

enum DailyQuotaFeature: String {
    case voice
    case tidy
    case agentRecipe = "agent_recipe"
    case chat
}

@MainActor
class StoreService: ObservableObject {
    static let shared = StoreService()
    
    @Published var currentTier: SubscriptionTier = .free
    @Published var availableProducts: [Product] = []
    @Published var isPurchasing = false
    @Published var errorMessage: String?
    
    // Feature Limits
    var recordingTimeLimit: TimeInterval {
        currentTier == .pro ? 600 : 60 // 10 mins vs 1 min
    }

    var dailyVoiceLimit: Int {
        currentTier == .pro ? Int.max : 5
    }

    var dailyTidyLimit: Int {
        currentTier == .pro ? Int.max : 5
    }

    var dailyAgentRecipeLimit: Int {
        currentTier == .pro ? Int.max : 3
    }

    var dailyAIChatLimit: Int {
        currentTier == .pro ? Int.max : 10
    }

    // MARK: - Usage Tracking
    private let voiceUsageKey = "daily_voice_ai_usage"
    private let tidyUsageKey = "daily_tidy_ai_usage"
    private let agentRecipeUsageKey = "daily_agent_recipe_ai_usage"
    private let chatUsageKey = "daily_chat_ai_usage"
    
    var remainingFreeVoiceCount: Int {
        if currentTier == .pro { return 999 }
        return max(0, dailyVoiceLimit - currentDailyVoiceUsage)
    }

    private var currentDailyVoiceUsage: Int {
        let defaults = UserDefaults.standard
        let key = usageKeyForToday(baseKey: voiceUsageKey)
        return defaults.integer(forKey: key)
    }

    private var currentDailyTidyUsage: Int {
        let defaults = UserDefaults.standard
        let key = usageKeyForToday(baseKey: tidyUsageKey)
        return defaults.integer(forKey: key)
    }

    private var currentDailyAgentRecipeUsage: Int {
        let defaults = UserDefaults.standard
        let key = usageKeyForToday(baseKey: agentRecipeUsageKey)
        return defaults.integer(forKey: key)
    }

    private var currentDailyAIChatUsage: Int {
        let defaults = UserDefaults.standard
        let key = usageKeyForToday(baseKey: chatUsageKey)
        return defaults.integer(forKey: key)
    }
    
    private func usageKeyForToday(baseKey: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: Date())
        return "\(baseKey)_\(dateStr)"
    }
    
    func canUseVoiceAI() -> Bool {
        if currentTier == .pro { return true }
        return currentDailyVoiceUsage < dailyVoiceLimit
    }

    func canUseTidyAI() -> Bool {
        if currentTier == .pro { return true }
        return currentDailyTidyUsage < dailyTidyLimit
    }

    func canUseAgentRecipeAI() -> Bool {
        if currentTier == .pro { return true }
        return currentDailyAgentRecipeUsage < dailyAgentRecipeLimit
    }

    func canUseAIChat() -> Bool {
        if currentTier == .pro { return true }
        return currentDailyAIChatUsage < dailyAIChatLimit
    }

    func incrementTidyAIUsage() {
        if currentTier == .pro { return }
        let defaults = UserDefaults.standard
        let key = usageKeyForToday(baseKey: tidyUsageKey)
        let current = defaults.integer(forKey: key)
        defaults.set(current + 1, forKey: key)
    }

    func incrementAgentRecipeAIUsage() {
        if currentTier == .pro { return }
        let defaults = UserDefaults.standard
        let key = usageKeyForToday(baseKey: agentRecipeUsageKey)
        let current = defaults.integer(forKey: key)
        defaults.set(current + 1, forKey: key)
    }

    func incrementAIChatUsage() {
        if currentTier == .pro { return }
        let defaults = UserDefaults.standard
        let key = usageKeyForToday(baseKey: chatUsageKey)
        let current = defaults.integer(forKey: key)
        defaults.set(current + 1, forKey: key)
    }

    func incrementVoiceAIUsage() {
        if currentTier == .pro { return }
        let defaults = UserDefaults.standard
        let key = usageKeyForToday(baseKey: voiceUsageKey)
        let current = defaults.integer(forKey: key)
        defaults.set(current + 1, forKey: key)
    }

    @discardableResult
    func consumeTidyAIUsage() -> Bool {
        guard canUseTidyAI() else { return false }
        incrementTidyAIUsage()
        return true
    }

    @discardableResult
    func consumeAgentRecipeAIUsage() -> Bool {
        guard canUseAgentRecipeAI() else { return false }
        incrementAgentRecipeAIUsage()
        return true
    }

    @discardableResult
    func consumeAIChatUsage() -> Bool {
        guard canUseAIChat() else { return false }
        incrementAIChatUsage()
        return true
    }

    @discardableResult
    func consumeVoiceAIUsage() -> Bool {
        guard canUseVoiceAI() else { return false }
        incrementVoiceAIUsage()
        return true
    }

    private func performDailyQuotaRequest(
        feature: DailyQuotaFeature,
        action: String
    ) async -> Bool {
        guard AuthService.shared.isSignedIn else { return true }
        guard let token = await AuthService.shared.getSessionToken(), !token.isEmpty else { return true }

        let url = URL(string: "\(AppConfig.backendBaseURL)/quota/daily")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "feature": feature.rawValue,
            "action": action
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return true }

            if http.statusCode == 429 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["error"] as? String {
                    self.errorMessage = message
                }
                return false
            }

            return (200...299).contains(http.statusCode)
        } catch {
            // Network failure fallback: don't hard-block user locally.
            return true
        }
    }

    func checkDailyQuotaOnServer(feature: DailyQuotaFeature) async -> Bool {
        await performDailyQuotaRequest(feature: feature, action: "check")
    }

    func consumeDailyQuotaOnServer(feature: DailyQuotaFeature) async -> Bool {
        await performDailyQuotaRequest(feature: feature, action: "consume")
    }
    
    // Product Identifiers
    private let productIds = ["com.chillnote.pro.monthly", "com.chillnote.pro.yearly"]
    
    private var transactionListener: Task<Void, Error>?
    
    init() {
        // Start listening for transaction updates
        transactionListener = listenForTransactions()
        
        Task {
            await updateSubscriptionStatus()
            await fetchProducts()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - Transaction Listener
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    
                    // Deliver content to the user
                    await self.updateSubscriptionStatus()
                    
                    // Always finish a transaction
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Purchasing
    
    func purchase(_ product: Product) async {
        isPurchasing = true
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updateSubscriptionStatus()
                await transaction.finish()
                
            case .userCancelled:
                break
                
            case .pending:
                break
                
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
        
        isPurchasing = false
    }
    
    func restorePurchases() async {
        isPurchasing = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
        
        isPurchasing = false
    }
    
    // MARK: - Data Fetching
    
    // MARK: - App Account Token
    // Optional: Use this to link the purchase to the user account in Apple's system (obfuscated)
    private var appAccountToken: UUID? {
        guard let userId = AuthService.shared.currentUserId else { return nil }
        return UUID(uuidString: userId) // Simplified, ideally hash checking
    }
    
    // MARK: - Data Fetching
    
    private func fetchProducts() async {
        do {
            let products = try await Product.products(for: productIds)
            availableProducts = products.sorted(by: { $0.price < $1.price })
        } catch {
            print("Failed to fetch products: \(error)")
        }
    }
    
    private func updateSubscriptionStatus() async {
        // 1. First Check Local StoreKit Entitlements (Client Side)
        var highestTier: SubscriptionTier = .free
        var activeTransaction: Transaction? = nil
        
        // Check for active subscriptions from Apple
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if productIds.contains(transaction.productID) {
                    if let expirationDate = transaction.expirationDate, expirationDate > Date() {
                        highestTier = .pro
                        activeTransaction = transaction
                    }
                }
            } catch {
                print("Failed to verify entitlement: \(error)")
            }
        }
        
        // 2. If logged in, Verify with Backend (Server Side Authority)
        if let transaction = activeTransaction, AuthService.shared.isSignedIn {
             do {
                 try await verifySubscriptionWithBackend(transaction)
             } catch {
                 print("Backend verification warning: \(error)")
                 // Fallback: we still allow pro locally if backend fails (e.g. offline), 
                 // but in strict mode you might block it. 
                 // For now, we trust StoreKit locally to not break UX.
             }
         }
         
        // 3. Check Backend Profile Status (e.g. for cross-platform or if IAP is expired locally but active on server?)
        // Ideally, we fetch the user profile from Supabase and trust that source of truth.
        // For this implementation, we will sync the local IAP state TO the server.
        
        self.currentTier = highestTier
    }
    
    private func verifySubscriptionWithBackend(_ transaction: Transaction) async throws {
        guard AuthService.shared.isSignedIn else { return }
        guard let token = await AuthService.shared.getSessionToken() else { return }
        guard let receiptData = try await fetchAppReceiptData() else {
            throw URLError(.dataNotAllowed)
        }
        
        let url = URL(string: "\(AppConfig.backendBaseURL)/subscription/verify")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "transactionId": String(transaction.id), // UInt64 to String
            "originalTransactionId": String(transaction.originalID),
            "productId": transaction.productID,
            "expiresDate": transaction.expirationDate?.ISO8601Format() ?? "",
            "receiptData": receiptData
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
             throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode != 200 {
            // Handle specific errors like 409 (Bound to another user)
            if httpResponse.statusCode == 409 {
                 self.errorMessage = "This subscription is already linked to another ChillNote account."
            }
            throw URLError(.badServerResponse)
        }
        
        // Success
        print("✅ Subscription verified with backend")
    }

    private func fetchAppReceiptData() async throws -> String? {
        let appTransactionResult = try await AppTransaction.shared
        _ = try checkVerified(appTransactionResult)
        var transactions: [String] = []

        for await result in Transaction.all {
            if case .verified = result {
                transactions.append(result.jwsRepresentation)
            }
        }

        let payload: [String: Any] = [
            "appTransaction": appTransactionResult.jwsRepresentation,
            "transactions": transactions
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        return data.base64EncodedString()
    }
    
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

enum StoreError: Error {
    case failedVerification
}
