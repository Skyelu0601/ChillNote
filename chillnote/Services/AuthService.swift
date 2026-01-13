import Foundation
import SwiftUI
import AuthenticationServices

enum AuthProvider: String, Codable {
    case apple
}

enum AuthState: Equatable {
    case signedOut
    case signingIn
    case signedIn(userId: String, provider: AuthProvider)
}

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published private(set) var state: AuthState = .signedOut
    @Published var errorMessage: String?

    private let keychainService = "com.chillnote.auth"
    private let providerKey = "provider"
    private let userIdKey = "userId"
    private let accessTokenKey = "accessToken"
    private let refreshTokenKey = "refreshToken"

    var isSignedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    private init() {
        restoreSessionIfPossible()
    }

    func restoreSessionIfPossible() {
        let providerRaw = KeychainStore.readString(service: keychainService, account: providerKey)
        let userId = KeychainStore.readString(service: keychainService, account: userIdKey)
        let accessToken = KeychainStore.readString(service: keychainService, account: accessTokenKey)

        guard
            let providerRaw,
            let provider = AuthProvider(rawValue: providerRaw),
            let userId,
            !userId.isEmpty
        else {
            state = .signedOut
            return
        }

        state = .signedIn(userId: userId, provider: provider)
        if let accessToken, !accessToken.isEmpty {
            UserDefaults.standard.set(accessToken, forKey: "syncAuthToken")
        }

        if provider == .apple {
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userId) { [weak self] credentialState, _ in
                Task { @MainActor in
                    guard let self else { return }
                    switch credentialState {
                    case .authorized:
                        break
                    default:
                        self.signOut()
                    }
                }
            }
        }
    }

    func completeSignIn(provider: AuthProvider, userId: String) {
        errorMessage = nil
        state = .signedIn(userId: userId, provider: provider)
        _ = KeychainStore.writeString(provider.rawValue, service: keychainService, account: providerKey)
        _ = KeychainStore.writeString(userId, service: keychainService, account: userIdKey)
    }
    
    func signInWithApple(_ credential: ASAuthorizationAppleIDCredential) async -> Bool {
        errorMessage = nil
        state = .signingIn
        
        guard let identityToken = credential.identityToken,
              let identityTokenString = String(data: identityToken, encoding: .utf8),
              let authorizationCode = credential.authorizationCode,
              let authorizationCodeString = String(data: authorizationCode, encoding: .utf8)
        else {
            errorMessage = "Apple Sign-In failed. Please try again."
            state = .signedOut
            return false
        }
        
        guard let url = URL(string: AppConfig.backendBaseURL + "/auth/apple") else {
            errorMessage = "Auth server URL is invalid."
            state = .signedOut
            return false
        }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let payload = AppleSignInRequest(
                userId: credential.user,
                identityToken: identityTokenString,
                authorizationCode: authorizationCodeString
            )
            request.httpBody = try JSONEncoder().encode(payload)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Auth server is unavailable."
                state = .signedOut
                return false
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                errorMessage = "Sign in failed. Please try again."
                state = .signedOut
                return false
            }
            
            let tokenResponse = try JSONDecoder().decode(AppleSignInResponse.self, from: data)
            completeSignIn(provider: .apple, userId: tokenResponse.userId)
            storeTokens(accessToken: tokenResponse.accessToken, refreshToken: tokenResponse.refreshToken)
            UserDefaults.standard.set(tokenResponse.accessToken, forKey: "syncAuthToken")
            return true
        } catch {
            errorMessage = "Sign in failed. Please try again."
            state = .signedOut
            return false
        }
    }
    
    func refreshAccessToken() async -> Bool {
        guard let refreshToken = KeychainStore.readString(service: keychainService, account: refreshTokenKey),
              !refreshToken.isEmpty
        else {
            return false
        }
        guard let url = URL(string: AppConfig.backendBaseURL + "/auth/refresh") else {
            return false
        }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(RefreshTokenRequest(refreshToken: refreshToken))
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                return false
            }
            
            let tokenResponse = try JSONDecoder().decode(AppleSignInResponse.self, from: data)
            storeTokens(accessToken: tokenResponse.accessToken, refreshToken: tokenResponse.refreshToken)
            UserDefaults.standard.set(tokenResponse.accessToken, forKey: "syncAuthToken")
            return true
        } catch {
            return false
        }
    }

    func signOut() {
        errorMessage = nil
        state = .signedOut
        _ = KeychainStore.delete(service: keychainService, account: providerKey)
        _ = KeychainStore.delete(service: keychainService, account: userIdKey)
        _ = KeychainStore.delete(service: keychainService, account: accessTokenKey)
        _ = KeychainStore.delete(service: keychainService, account: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: "syncAuthToken")
    }
    
    private func storeTokens(accessToken: String, refreshToken: String) {
        _ = KeychainStore.writeString(accessToken, service: keychainService, account: accessTokenKey)
        _ = KeychainStore.writeString(refreshToken, service: keychainService, account: refreshTokenKey)
    }
}

private struct AppleSignInRequest: Encodable {
    let userId: String
    let identityToken: String
    let authorizationCode: String
}

private struct AppleSignInResponse: Decodable {
    let userId: String
    let accessToken: String
    let refreshToken: String
}

private struct RefreshTokenRequest: Encodable {
    let refreshToken: String
}
