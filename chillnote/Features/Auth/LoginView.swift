import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    @State private var showEmailLogin = false
    @State private var email = ""
    @State private var otpCode = ""
    @State private var sentCode = false
    @State private var isSendingCode = false
    @State private var isVerifyingCode = false
    
    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // MARK: - Brand Header
                VStack(spacing: 16) {
                    Image("chillohead_touming")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                    
                    Text("ChillNote")
                        .font(.system(size: 32, weight: .bold, design: .serif))
                        .foregroundColor(.textMain)
                    
                    Text("Say it. Save it.")
                        .multilineTextAlignment(.center)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.textSub)
                }
                .padding(.bottom, 20)
                
                if showEmailLogin {
                    // MARK: - Email Login Form
                    emailLoginForm
                } else {
                    // MARK: - Social Login Buttons
                    VStack(spacing: 16) {
                        // Apple Sign In
                        SignInWithAppleButton(
                            onRequest: { request in
                                authService.handleAppleRequest(request)
                            },
                            onCompletion: { result in
                                print("🍎 [Apple Sign In] Completion callback triggered")
                                switch result {
                                case .success(let authorization):
                                    print("✅ [Apple Sign In] Authorization successful")
                                    print("   Credential type: \(type(of: authorization.credential))")
                                    
                                    if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                        print("   User ID: \(appleIDCredential.user)")
                                        print("   Has identity token: \(appleIDCredential.identityToken != nil)")
                                        print("   Has authorization code: \(appleIDCredential.authorizationCode != nil)")
                                        print("   Email: \(appleIDCredential.email ?? "nil")")
                                        print("   Full name: \(appleIDCredential.fullName?.givenName ?? "nil")")
                                        
                                        Task {
                                            print("🚀 [Apple Sign In] Starting backend authentication...")
                                            let success = await authService.signInWithApple(appleIDCredential)
                                            print("🎯 [Apple Sign In] Backend result: \(success ? "✅ SUCCESS" : "❌ FAILED")")
                                            if !success {
                                                print("⚠️ [Apple Sign In] Error message: \(authService.errorMessage ?? "Unknown error")")
                                            }
                                        }
                                    } else {
                                        print("❌ [Apple Sign In] Failed to cast credential to ASAuthorizationAppleIDCredential")
                                    }
                                case .failure(let error):
                                    print("❌ [Apple Sign In] Authorization failed")
                                    print("   Error: \(error.localizedDescription)")
                                    print("   Error code: \((error as NSError).code)")
                                    print("   Error domain: \((error as NSError).domain)")
                                }
                            }
                        )
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                        
                        // Google Sign In (Custom Button)
                        Button(action: {
                            Task {
                                let success = await authService.signInWithGoogle()
                                if !success {
                                    print("Google Sign In failed: \(authService.errorMessage ?? "Unknown error")")
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "globe") // Placeholder for Google G logo
                                Text("Sign in with Google")
                                    .font(.system(size: 17, weight: .medium))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        }
                        
                        // Email Toggle
                        Button(action: {
                            withAnimation { showEmailLogin = true }
                        }) {
                            Text("Continue with Email")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.textSub)
                        }
                        .padding(.top, 10)
                    }
                    .padding(.horizontal, 30)
                }
                
                Spacer()
                
                // MARK: - Terms
                Text(.init("By continuing, you agree to our [Terms](https://www.chillnoteai.com/terms.html) & [Privacy Policy](https://www.chillnoteai.com/privacy.html)."))
                    .font(.caption)
                    .foregroundColor(.textSub.opacity(0.8))
                    .tint(.textSub.opacity(0.95))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
            }
        }
        .onChange(of: authService.isSignedIn) { oldValue, newValue in
            if newValue {
                dismiss()
            }
        }
    }
    
    var emailLoginForm: some View {
        VStack(spacing: 20) {
            if !sentCode {
                TextField("name@example.com", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color.bgSecondary)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.textSub.opacity(0.1), lineWidth: 1)
                    )
                
                Button(action: {
                    Task {
                        isSendingCode = true
                        defer { isSendingCode = false }
                        let success = await authService.signInWithEmailOTP(email: email)
                        if success {
                            withAnimation {
                                sentCode = true
                            }
                        }
                    }
                }) {
                    if isSendingCode {
                         ProgressView()
                             .progressViewStyle(CircularProgressViewStyle(tint: .white))
                             .frame(maxWidth: .infinity)
                             .frame(height: 50)
                             .background(Color.accentPrimary)
                             .cornerRadius(12)
                    } else {
                        Text("Send Verification Code")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.accentPrimary)
                            .cornerRadius(12)
                    }
                }
                .disabled(isSendingCode || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            } else {
                VStack(spacing: 8) {
                    Text("Enter code sent to \(email)")
                        .font(.caption)
                        .foregroundColor(.textSub)
                    
                    TextField("123456", text: $otpCode)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.title2)
                        .padding()
                        .background(Color.bgSecondary)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.textSub.opacity(0.1), lineWidth: 1)
                        )
                }
                
                Button(action: {
                    Task {
                        isVerifyingCode = true
                        defer { isVerifyingCode = false }
                        let success = await authService.verifyEmailOTP(email: email, code: otpCode)
                        if !success {
                           // Error is handled in AuthService and published via errorMessage
                           // potentially show an alert here if needed
                        }
                    }
                }) {
                    if isVerifyingCode {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.textMain)
                            .cornerRadius(12)
                    } else {
                        Text("Verify & Login")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.textMain)
                            .cornerRadius(12)
                    }
                }
                .disabled(isVerifyingCode || otpCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            }
            
            Button("Back to Options") {
                withAnimation {
                    showEmailLogin = false
                    sentCode = false
                    otpCode = ""
                }
            }
            .font(.footnote)
            .foregroundColor(.textSub)
        }
        .padding(.horizontal, 30)
        .transition(.move(edge: .trailing))
    }
}
