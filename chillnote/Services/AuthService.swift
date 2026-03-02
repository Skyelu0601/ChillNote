import Foundation
import SwiftUI
import AuthenticationServices
import GoogleSignIn
import Supabase
import CryptoKit

enum AuthProvider: String, Codable {
    case apple
    case google
    case email
}

private enum AuthServiceError: LocalizedError {
    case invalidNonceLength
    case nonceGenerationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidNonceLength:
            return L10n.text("error.auth.invalid_nonce_length")
        case .nonceGenerationFailed:
            return L10n.text("error.auth.nonce_generation_failed")
        }
    }
}

enum AuthState: Equatable {
    case checking
    case signedOut
    case signingIn
    case signedIn(userId: String)
}

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    // Initialize Supabase Client
    let supabase = SupabaseClient(
        supabaseURL: AppConfig.supabaseURL,
        supabaseKey: AppConfig.supabaseAnonKey,
        options: SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(
                emitLocalSessionAsInitialSession: true
            )
        )
    )

    @Published private(set) var state: AuthState = .checking
    @Published var errorMessage: String?
    @Published var isPro: Bool = false
    @Published var currentUser: User?
    
    // To prevent replay attacks with Apple Sign In
    var currentNonce: String?

    var isSignedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    /// If we have a local auth token, we can show home first while verifying session in background.
    var canOptimisticallyEnterHome: Bool {
        guard case .checking = state else { return false }
        return hasCachedSessionToken
    }
    
    var currentUserId: String? {
        if case .signedIn(let userId) = state {
            return userId
        }
        return nil
    }
    
    var loginProvider: String {
        guard let user = currentUser else { return "email" }
        return user.identities?.first?.provider ?? "email"
    }

    private var hasCachedSessionToken: Bool {
        guard let token = UserDefaults.standard.string(forKey: "syncAuthToken") else { return false }
        return !token.isEmpty
    }

    private init() {
        // Listen to Auth State Changes
        Task {
            for await _ in supabase.auth.authStateChanges {
                await checkSession()
            }
        }
        
        Task {
            await checkSession()
        }
    }

    func checkSession() async {
        do {
            let session = try await supabase.auth.session
            
            // Check if the session is expired
            if session.isExpired {
                self.state = .signedOut
                return
            }
            
            self.state = .signedIn(userId: session.user.id.uuidString)
            self.currentUser = session.user
            UserDefaults.standard.set(session.accessToken, forKey: "syncAuthToken")
            await StoreService.shared.refreshSubscriptionStatus()
        } catch {
            self.state = .signedOut
            UserDefaults.standard.removeObject(forKey: "syncAuthToken")
            StoreService.shared.currentTier = .free
        }
    }
    
    // MARK: - Apple Sign In
    
    // Call this from SignInWithAppleButton.onRequest
    func handleAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce: String
        do {
            nonce = try randomNonceString()
        } catch {
            currentNonce = nil
            errorMessage = AppErrorCode.authAppleInitFailed.message
            return
        }
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    func signInWithApple(_ credential: ASAuthorizationAppleIDCredential) async -> Bool {
        errorMessage = nil
        state = .signingIn
        
        guard let idTokenData = credential.identityToken,
              let idToken = String(data: idTokenData, encoding: .utf8),
              let nonce = currentNonce else {
            errorMessage = AppErrorCode.authInvalidAppleCredential.message
            state = .signedOut
            return false
        }
        
        do {
            try await supabase.auth.signInWithIdToken(credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            ))
            return true
        } catch {
            print("❌ Apple Sign In Error: \(error)")
            errorMessage = error.localizedDescription
            state = .signedOut
            return false
        }
    }
    
    // MARK: - Google Sign In
    func signInWithGoogle() async -> Bool {
        errorMessage = nil
        state = .signingIn
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = AppErrorCode.authRootViewControllerMissing.message
            state = .signedOut
            return false
        }
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = AppErrorCode.authGoogleTokenMissing.message
                state = .signedOut
                return false
            }
            
            try await supabase.auth.signInWithIdToken(credentials: .init(
                provider: .google,
                idToken: idToken
            ))
            return true
        } catch {
            print("❌ Google Sign In Error: \(error)")
            errorMessage = error.localizedDescription
            state = .signedOut
            return false
        }
    }
    
    func signOut() {
        Task {
            try? await supabase.auth.signOut()
            state = .signedOut
            currentUser = nil
            UserDefaults.standard.removeObject(forKey: "syncAuthToken")
            StoreService.shared.currentTier = .free
        }
    }
    
    func deleteAccount() async -> Bool {
        // Supabase Client SDK doesn't allow deleting self easily without admin, 
        // usually you call an Edge Function or Backend endpoint.
        // We will call our Backend endpoint which requires the JWT.
        
        guard let session = try? await supabase.auth.session else { return false }
        let token = session.accessToken
        
        guard let url = URL(string: AppConfig.backendBaseURL + "/auth/account") else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                signOut()
                return true
            }
        } catch {
            print("Delete account error: \(error)")
        }
        return false
    }
    
    // MARK: - Helpers
    
    private func randomNonceString(length: Int = 32) throws -> String {
        guard length > 0 else {
            throw AuthServiceError.invalidNonceLength
        }
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            throw AuthServiceError.nonceGenerationFailed(errorCode)
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }.reduce("") { partialResult, char in
            partialResult + String(char)
        }
        
        return nonce
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            return String(format: "%02x", $0)
        }.joined()
        return hashString
    }
    
    // MARK: - Email OTP Sign In

    private func normalizeEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func normalizeCode(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isAppReviewQuickCredential(email: String, code: String) -> Bool {
        guard AppConfig.isAppReviewQuickLoginEnabled else { return false }
        let inWhitelist = AppConfig.appReviewWhitelistEmails.contains(email)
        return inWhitelist && code == AppConfig.appReviewVerificationCode
    }

    private func isAppReviewWhitelistedEmail(_ email: String) -> Bool {
        guard AppConfig.isAppReviewQuickLoginEnabled else { return false }
        return AppConfig.appReviewWhitelistEmails.contains(email)
    }

    private func signInWithAppReviewCredential(email: String, code: String) async -> Bool {
        state = .signingIn
        do {
            try await supabase.auth.signIn(email: email, password: code)
            return true
        } catch {
            print("❌ App Review Quick Login Error: \(error)")
            errorMessage = error.localizedDescription
            state = .signedOut
            return false
        }
    }
    
    func signInWithEmailOTP(email: String) async -> Bool {
        errorMessage = nil
        let normalizedEmail = normalizeEmail(email)

        if isAppReviewWhitelistedEmail(normalizedEmail) {
            // For App Review accounts, skip sending real email OTP.
            return true
        }
        
        do {
            try await supabase.auth.signInWithOTP(email: normalizedEmail)
            return true
        } catch {
            print("❌ Email OTP Error: \(error)")
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    func verifyEmailOTP(email: String, code: String) async -> Bool {
        errorMessage = nil
        let normalizedEmail = normalizeEmail(email)
        let normalizedCode = normalizeCode(code)

        if isAppReviewQuickCredential(email: normalizedEmail, code: normalizedCode) {
            return await signInWithAppReviewCredential(email: normalizedEmail, code: normalizedCode)
        }
        
        do {
            try await supabase.auth.verifyOTP(
                email: normalizedEmail,
                token: normalizedCode,
                type: .email
            )
            // Session listener will flip state to .signedIn automatically
            return true
        } catch {
            print("❌ Verify OTP Error: \(error)")
            errorMessage = error.localizedDescription
            return false
        }
    }
    // MARK: - Token Helper
    
    func getSessionToken() async -> String? {
        do {
            let session = try await supabase.auth.session
            return session.accessToken
        } catch {
            let cached = UserDefaults.standard.string(forKey: "syncAuthToken")
            if let cached, !cached.isEmpty {
                return cached
            }
            return nil
        }
    }
}
