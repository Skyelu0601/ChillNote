import SwiftUI
import AuthenticationServices

struct LoginView: View {
    private let primaryButtonHeight: CGFloat = 54
    private let primaryButtonCornerRadius: CGFloat = 14
    private let contentMaxWidth: CGFloat = 360

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    @State private var showEmailLogin = false
    @State private var email = ""
    @State private var otpCode = ""
    @State private var sentCode = false
    @State private var isSendingCode = false
    @State private var isVerifyingCode = false

    private var emailLoginErrorMessage: String? {
        guard showEmailLogin, let message = authService.errorMessage, !message.isEmpty else { return nil }
        return message
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.bgPrimary.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer(minLength: max(68, geometry.size.height * 0.13))

                    VStack(spacing: 26) {
                        LoginBrandHeader()
                            .padding(.horizontal, 24)

                        Group {
                            if showEmailLogin {
                                emailLoginForm
                            } else {
                                socialLoginButtons
                            }
                        }
                        .frame(maxWidth: contentMaxWidth)
                    }
                    
                    Spacer(minLength: max(40, geometry.size.height * 0.08))
                    
                    Text(.init(L10n.text("auth.login.legal_markdown")))
                        .font(.caption)
                        .foregroundColor(.textSub.opacity(0.8))
                        .tint(.textSub.opacity(0.95))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: contentMaxWidth)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: authService.isSignedIn) { oldValue, newValue in
            if newValue {
                dismiss()
            }
        }
    }
    
    var socialLoginButtons: some View {
        VStack(spacing: 16) {
            Button(action: {
                Task {
                    await authService.signInWithGoogle()
                }
            }) {
                HStack(spacing: 10) {
                    Image("GoogleLogo")
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: 18, height: 18)
                    Text(L10n.text("auth.login.google_button"))
                        .font(.system(size: 19, weight: .medium))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: primaryButtonHeight)
                .background(Color.white)
                .cornerRadius(primaryButtonCornerRadius)
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: primaryButtonCornerRadius)
                        .stroke(Color.gray.opacity(0.18), lineWidth: 1)
                )
            }

            SignInWithAppleButton(
                onRequest: { request in
                    authService.handleAppleRequest(request)
                },
                onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                            Task {
                                await authService.signInWithApple(appleIDCredential)
                            }
                        }
                    case .failure:
                        break
                    }
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: primaryButtonHeight)
            .clipShape(RoundedRectangle(cornerRadius: primaryButtonCornerRadius))
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showEmailLogin = true
                }
            }) {
                Text(L10n.text("auth.login.email_button"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.textSub)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
            }
        }
        .padding(.horizontal, 24)
    }
    
    var emailLoginForm: some View {
        VStack(spacing: 20) {
            if !sentCode {
                TextField(L10n.text("auth.login.email_placeholder"), text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .onChange(of: email) { _, _ in
                        authService.errorMessage = nil
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 54)
                    .background(Color.bgSecondary)
                    .cornerRadius(primaryButtonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: primaryButtonCornerRadius)
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
                             .frame(height: primaryButtonHeight)
                             .background(Color.accentPrimary)
                             .cornerRadius(primaryButtonCornerRadius)
                    } else {
                        Text(L10n.text("auth.login.send_code"))
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: primaryButtonHeight)
                            .background(Color.accentPrimary)
                            .cornerRadius(primaryButtonCornerRadius)
                    }
                }
                .disabled(isSendingCode || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            } else {
                VStack(spacing: 8) {
                    Text(
                        String(
                            format: L10n.text("auth.login.code_sent_to_format"),
                            email
                        )
                    )
                        .font(.caption)
                        .foregroundColor(.textSub)
                    
                    TextField(L10n.text("auth.login.verification_code_placeholder"), text: $otpCode)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.title2)
                        .onChange(of: otpCode) { _, _ in
                            authService.errorMessage = nil
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 54)
                        .background(Color.bgSecondary)
                        .cornerRadius(primaryButtonCornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: primaryButtonCornerRadius)
                                .stroke(
                                    emailLoginErrorMessage == nil ? Color.textSub.opacity(0.1) : Color.red.opacity(0.45),
                                    lineWidth: 1
                                )
                        )

                    if let errorMessage = emailLoginErrorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)

                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.leading)

                            Spacer(minLength: 0)
                        }
                        .padding(.top, 2)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(errorMessage)
                    }
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
                            .frame(height: primaryButtonHeight)
                            .background(Color.textMain)
                            .cornerRadius(primaryButtonCornerRadius)
                    } else {
                        Text(L10n.text("auth.login.verify_button"))
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: primaryButtonHeight)
                            .background(Color.textMain)
                            .cornerRadius(primaryButtonCornerRadius)
                    }
                }
                .disabled(isVerifyingCode || otpCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            }

            Button(L10n.text("auth.login.back_to_options")) {
                withAnimation {
                    authService.errorMessage = nil
                    showEmailLogin = false
                    sentCode = false
                    otpCode = ""
                }
            }
            .font(.footnote)
            .foregroundColor(.textSub)
        }
        .padding(.horizontal, 24)
        .transition(.move(edge: .trailing))
    }
}

private struct LaunchScreenStyleWordmark: View {
    var body: some View {
        HStack(spacing: 0) {
            Text(verbatim: "Chill")
                .font(.custom("AvenirNext-DemiBold", size: 42))
                .foregroundColor(Color(red: 0.184, green: 0.525, blue: 1.0))

            Text(verbatim: "Note")
                .font(.custom("AvenirNext-HeavyItalic", size: 44))
                .foregroundColor(Color(red: 0.365, green: 0.569, blue: 0.961))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(L10n.text("auth.login.brand_title")))
    }
}

private struct LoginBrandHeader: View {
    var body: some View {
        VStack(spacing: 14) {
            Image("LoginBrandIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 68, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 8)

            LaunchScreenStyleWordmark()
        }
        .frame(maxWidth: .infinity)
    }
}
