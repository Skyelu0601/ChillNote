import Foundation
import SwiftUI
import AuthenticationServices
import GoogleSignIn
import OSLog
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
    static let cachedSessionTokenKey = "syncAuthToken"
    static let lastAuthenticatedUserIdKey = "auth.lastAuthenticatedUserId"
    private static let logger = Logger(subsystem: "com.chillnote.app", category: "auth")

    // Initialize Supabase Client
    let supabase = SupabaseClient(
        supabaseURL: AppConfig.supabaseURL,
        supabaseKey: AppConfig.supabaseAnonKey,
        options: SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(
                storage: MigratingAuthLocalStorage(
                    primary: SharedAuthSessionStorage.sharedKeychain,
                    fallback: KeychainLocalStorage()
                ),
                autoRefreshToken: true,
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
        return hasCachedSessionToken && lastAuthenticatedUserId != nil
    }

    /// Whether to render signed-in UI surfaces (account section, sign-out button, etc.).
    /// Returns true both when the session is confirmed (.signedIn) and when we are still
    /// checking but have a cached token, so the Settings page doesn't flash "Sign in"
    /// for users who are already logged in.
    var shouldShowSignedInUI: Bool {
        isSignedIn || canOptimisticallyEnterHome
    }
    
    var currentUserId: String? {
        if case .signedIn(let userId) = state {
            return userId
        }
        if case .checking = state {
            return lastAuthenticatedUserId
        }
        return nil
    }

    var confirmedUserId: String? {
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
        guard let token = UserDefaults.standard.string(forKey: Self.cachedSessionTokenKey)
            ?? SharedImportQueue.sharedDefaults()?.string(forKey: Self.cachedSessionTokenKey) else {
            return false
        }
        return !token.isEmpty
    }

    private var lastAuthenticatedUserId: String? {
        guard let userId = UserDefaults.standard.string(forKey: Self.lastAuthenticatedUserIdKey)
            ?? SharedImportQueue.sharedDefaults()?.string(forKey: Self.lastAuthenticatedUserIdKey) else {
            return nil
        }
        return userId.isEmpty ? nil : userId
    }

    private var sessionCheckGeneration = 0

    private init() {
        // Listen to Auth State Changes
        Task {
            for await (_, session) in supabase.auth.authStateChanges {
                await handleAuthStateChange(session)
            }
        }
        
        Task {
            await checkSession()
        }
    }

    func checkSession() async {
        sessionCheckGeneration += 1
        let generation = sessionCheckGeneration

        do {
            let session = try await supabase.auth.session
            guard generation == sessionCheckGeneration else { return }
            
            applyAuthenticatedSession(session)
            await StoreService.shared.refreshSubscriptionStatus()
        } catch {
            guard generation == sessionCheckGeneration else { return }
            handleSessionLookupFailure(error)
        }
    }

    func waitForSessionResolution(timeout: TimeInterval = 2.0) async {
        let deadline = Date().addingTimeInterval(timeout)
        while case .checking = state {
            guard Date() < deadline else { return }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    private func handleAuthStateChange(_ session: Session?) async {
        guard let session else {
            state = .signedOut
            clearCachedSession()
            return
        }

        if session.isExpired {
            await checkSession()
            return
        }

        applyAuthenticatedSession(session)
        await StoreService.shared.refreshSubscriptionStatus()
    }

    private func applyAuthenticatedSession(_ session: Session) {
        persistSession(session)
        state = .signedIn(userId: session.user.id.uuidString)
        currentUser = session.user
    }

    private func handleSessionLookupFailure(_ error: Error) {
        if isMissingSessionError(error) || !hasCachedSessionToken {
            state = .signedOut
            clearCachedSession()
        }
    }

    private func isMissingSessionError(_ error: Error) -> Bool {
        let text = "\(error) \(error.localizedDescription)".lowercased()
        return text.contains("sessionnotfound")
            || text.contains("session not found")
            || text.contains("auth session missing")
            || text.contains("missing session")
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
            await checkSession()
            return isSignedIn
        } catch {
            Self.logger.error("Apple sign in failed: \(error.localizedDescription, privacy: .public)")
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
            await checkSession()
            return isSignedIn
        } catch {
            Self.logger.error("Google sign in failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            state = .signedOut
            return false
        }
    }
    
    func signOut() {
        Task {
            do {
                try await supabase.auth.signOut()
            } catch {
                Self.logger.error("Supabase sign out failed: \(error.localizedDescription, privacy: .public)")
            }
            state = .signedOut
            currentUser = nil
            clearCachedSession()
        }
    }
    
    func deleteAccount() async -> Bool {
        // Supabase Client SDK doesn't allow deleting self easily without admin, 
        // usually you call an Edge Function or Backend endpoint.
        // We will call our Backend endpoint which requires the JWT.
        
        let session: Session
        do {
            session = try await supabase.auth.session
        } catch {
            Self.logger.error("Failed to load session before account deletion: \(error.localizedDescription, privacy: .public)")
            return false
        }
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
            Self.logger.error("Delete account failed: \(error.localizedDescription, privacy: .public)")
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

    private func userFacingEmailOTPErrorMessage(for error: Error) -> String {
        let message = error.localizedDescription.lowercased()

        if message.contains("token")
            || message.contains("otp")
            || message.contains("code")
            || message.contains("expired")
            || message.contains("invalid") {
            return L10n.text("auth.login.error.invalid_verification_code")
        }

        return L10n.text("auth.login.error.verification_failed")
    }

    private func shouldRetryAuthNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return false }

        switch nsError.code {
        case NSURLErrorNetworkConnectionLost,
             NSURLErrorTimedOut,
             NSURLErrorCannotConnectToHost,
             NSURLErrorCannotFindHost,
             NSURLErrorNotConnectedToInternet:
            return true
        default:
            return false
        }
    }

    private func retryAuthRequest(
        maxAttempts: Int = 3,
        operation: () async throws -> Void
    ) async throws {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                try await operation()
                return
            } catch {
                lastError = error
                guard attempt < maxAttempts, shouldRetryAuthNetworkError(error) else {
                    throw error
                }

                let delay = UInt64(attempt) * 700_000_000
                try? await Task.sleep(nanoseconds: delay)
            }
        }

        if let lastError {
            throw lastError
        }
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
            await checkSession()
            return isSignedIn
        } catch {
            Self.logger.error("App Review quick login failed: \(error.localizedDescription, privacy: .public)")
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
            try await retryAuthRequest {
                try await supabase.auth.signInWithOTP(email: normalizedEmail)
            }
            return true
        } catch {
            Self.logger.error("Email OTP request failed: \(error.localizedDescription, privacy: .public)")
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
            try await retryAuthRequest {
                try await supabase.auth.verifyOTP(
                    email: normalizedEmail,
                    token: normalizedCode,
                    type: .email
                )
            }
            await checkSession()
            return isSignedIn
        } catch {
            Self.logger.error("Email OTP verification failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = userFacingEmailOTPErrorMessage(for: error)
            return false
        }
    }
    // MARK: - Token Helper
    
    func getSessionToken() async -> String? {
        do {
            let session = try await supabase.auth.session
            persistSession(session)
            if !isSignedIn {
                state = .signedIn(userId: session.user.id.uuidString)
                currentUser = session.user
            }
            return session.accessToken
        } catch {
            handleSessionLookupFailure(error)
            return nil
        }
    }

    private func persistSession(_ session: Session) {
        UserDefaults.standard.set(session.accessToken, forKey: Self.cachedSessionTokenKey)
        UserDefaults.standard.set(session.user.id.uuidString, forKey: Self.lastAuthenticatedUserIdKey)
        SharedImportQueue.sharedDefaults()?.set(session.accessToken, forKey: Self.cachedSessionTokenKey)
        SharedImportQueue.sharedDefaults()?.set(session.user.id.uuidString, forKey: Self.lastAuthenticatedUserIdKey)
    }

    private func clearCachedSession() {
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: Self.cachedSessionTokenKey)
        UserDefaults.standard.removeObject(forKey: Self.lastAuthenticatedUserIdKey)
        SharedImportQueue.sharedDefaults()?.removeObject(forKey: Self.cachedSessionTokenKey)
        SharedImportQueue.sharedDefaults()?.removeObject(forKey: Self.lastAuthenticatedUserIdKey)
        StoreService.shared.resetForSignedOut()
    }
}
