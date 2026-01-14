import SwiftUI
import AuthenticationServices
import UIKit

struct LoginView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var isPresentingError = false
    @AppStorage("hasGuestAccess") private var hasGuestAccess = false
    
    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // MARK: - Header / Logo Area
                VStack(spacing: 16) {
                    Image("ChillLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: .accentPrimary.opacity(0.3), radius: 20, x: 0, y: 10)
                    
                    Text("Welcome Back")
                        .font(.displayLarge)
                        .foregroundColor(.textMain)
                    
                    Text("Sign in to keep your notes secure and ready for sync.")
                        .font(.bodyLarge)
                        .foregroundColor(.textSub)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 20)
                
                // MARK: - Action Buttons
                VStack(spacing: 16) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                                authService.errorMessage = "Apple Sign-In failed. Please try again."
                                isPresentingError = true
                                return
                            }
                            Task {
                                let success = await authService.signInWithApple(credential)
                                if success {
                                    hasGuestAccess = false
                                } else {
                                    isPresentingError = true
                                }
                            }
                        case .failure(let error):
                            authService.errorMessage = error.localizedDescription
                            isPresentingError = true
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .cornerRadius(14)
                    .padding(.horizontal, 32)
                    
                    Button("Continue as Guest") {
                        hasGuestAccess = true
                    }
                    .font(.bodyMedium)
                    .fontWeight(.bold)
                    .foregroundColor(.textMain)
                    .padding(.top, 6)
                }
                
                Spacer()
                
                // MARK: - Footer
                HStack {
                    Text("New here?")
                        .font(.bodySmall)
                        .foregroundColor(.textSub)
                    Text("Use Apple to create one.")
                        .font(.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundColor(.textMain)
                }
                .padding(.bottom, 20)
            }
        }
        .alert("Sign-in Error", isPresented: $isPresentingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authService.errorMessage ?? "Something went wrong.")
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthService.shared)
}
