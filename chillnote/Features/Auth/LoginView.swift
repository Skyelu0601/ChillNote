import SwiftUI
import AuthenticationServices

struct LoginView: View {
    private let primaryButtonHeight: CGFloat = BrandTokens.Size.primaryButtonHeight
    private let primaryButtonCornerRadius: CGFloat = BrandTokens.Radius.button
    private let contentMaxWidth: CGFloat = 360

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    @State private var showEmailLogin = false
    @State private var email = ""
    @State private var otpCode = ""
    @State private var sentCode = false
    @State private var isSendingCode = false
    @State private var isVerifyingCode = false
    @State private var appleSignInCoordinator = AppleSignInCoordinator()

    private var emailLoginErrorMessage: String? {
        guard showEmailLogin, let message = authService.errorMessage, !message.isEmpty else { return nil }
        return message
    }
    
    var body: some View {
        ZStack {
            BrandBackground()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                LoginBrandHeader()
                    .padding(.horizontal, 24)

                Spacer(minLength: 0)

                Group {
                    if showEmailLogin {
                        emailLoginForm
                    } else {
                        socialLoginButtons
                    }
                }
                .frame(maxWidth: contentMaxWidth)
                .padding(.bottom, 24)

                Text(.init(L10n.text("auth.login.legal_markdown")))
                    .font(.caption)
                    .foregroundColor(.textSub.opacity(0.8))
                    .tint(.textSub.opacity(0.95))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: contentMaxWidth)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: authService.isSignedIn) { oldValue, newValue in
            if newValue {
                dismiss()
            }
        }
    }
    
    var socialLoginButtons: some View {
        VStack(spacing: 12) {
            Button {
                Task { await authService.signInWithGoogle() }
            } label: {
                HStack(spacing: 10) {
                    Image("GoogleLogo")
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: 18, height: 18)
                    Text(L10n.text("auth.login.google_button"))
                }
                .brandNeutralButtonStyle()
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showEmailLogin = true
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "envelope")
                        .font(.system(size: 17, weight: .medium))
                    Text(L10n.text("auth.login.email_button"))
                }
                .brandNeutralButtonStyle()
            }

            Button {
                appleSignInCoordinator.start(
                    configure: { request in
                        authService.handleAppleRequest(request)
                    },
                    onCompletion: { result in
                        if case .success(let authorization) = result,
                           let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                            Task {
                                await authService.signInWithApple(credential)
                            }
                        }
                    }
                )
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "applelogo")
                        .font(.system(size: 17, weight: .medium))
                    Text(L10n.text("auth.login.apple_button"))
                }
                .brandNeutralButtonStyle()
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
                
                Button {
                    Task {
                        isSendingCode = true
                        defer { isSendingCode = false }
                        let success = await authService.signInWithEmailOTP(email: email)
                        if success {
                            withAnimation { sentCode = true }
                        }
                    }
                } label: {
                    Group {
                        if isSendingCode {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(L10n.text("auth.login.send_code"))
                        }
                    }
                    .brandPrimaryCTAStyle()
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
                
                Button {
                    Task {
                        isVerifyingCode = true
                        defer { isVerifyingCode = false }
                        _ = await authService.verifyEmailOTP(email: email, code: otpCode)
                    }
                } label: {
                    Group {
                        if isVerifyingCode {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(L10n.text("auth.login.verify_button"))
                        }
                    }
                    .brandPrimaryCTAStyle()
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

final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var onCompletion: ((Result<ASAuthorization, Error>) -> Void)?

    func start(
        configure: (ASAuthorizationAppleIDRequest) -> Void,
        onCompletion: @escaping (Result<ASAuthorization, Error>) -> Void
    ) {
        self.onCompletion = onCompletion
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        configure(request)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        onCompletion?(.success(authorization))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        onCompletion?(.failure(error))
    }
}

private struct LoginBrandHeader: View {
    var body: some View {
        VStack(spacing: BrandTokens.Space.s4) {
            NoteDetailLightningBallIcon(size: 96)

            BrandWordmark()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(L10n.text("auth.login.brand_title")))
    }
}
