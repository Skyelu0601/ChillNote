import SwiftUI
import AuthenticationServices

struct LoginView: View {
    private enum FocusField: Hashable {
        case email
        case verificationCode
    }

    private static let verificationCodeLength = 6
    private static let resendDelaySeconds = 45

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
    @State private var showEmailValidationError = false
    @State private var resendSecondsRemaining = 0
    @State private var resendCountdownGeneration = 0
    @State private var appleSignInCoordinator = AppleSignInCoordinator()
    @FocusState private var focusedField: FocusField?

    private var emailLoginErrorMessage: String? {
        guard showEmailLogin, let message = authService.errorMessage, !message.isEmpty else { return nil }
        return message
    }

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isEmailValid: Bool {
        normalizedEmail.range(
            of: #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private var emailInputErrorMessage: String? {
        if showEmailValidationError, !isEmailValid {
            return L10n.text("auth.login.email_invalid")
        }
        return emailLoginErrorMessage
    }

    private var isVerificationCodeComplete: Bool {
        otpCode.count == Self.verificationCodeLength
    }
    
    var body: some View {
        ZStack {
            BrandBackground()

            Group {
                if showEmailLogin {
                    focusedEmailLoginLayout
                } else {
                    socialLoginLayout
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: authService.isSignedIn) { oldValue, newValue in
            if newValue {
                AppInteractionFeedback.success()
                dismiss()
            }
        }
        .onChange(of: authService.errorMessage) { _, message in
            if let message, !message.isEmpty {
                AppInteractionFeedback.error()
            }
        }
        .onChange(of: focusedField) { oldValue, newValue in
            if oldValue == .email, newValue != .email, !normalizedEmail.isEmpty {
                showEmailValidationError = !isEmailValid
            }
        }
        .task(id: resendCountdownGeneration) {
            guard sentCode, resendSecondsRemaining > 0 else { return }

            while resendSecondsRemaining > 0, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                resendSecondsRemaining -= 1
            }
        }
    }

    private var socialLoginLayout: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            LoginBrandHeader()
                .padding(.horizontal, 24)

            Spacer(minLength: 0)

            socialLoginButtons
                .frame(maxWidth: contentMaxWidth)
                .padding(.bottom, 24)

            legalNotice
        }
    }

    private var focusedEmailLoginLayout: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    leaveEmailLogin()
                } label: {
                    Label(L10n.text("auth.login.back_to_options"), systemImage: "chevron.left")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.textMain)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.tactile)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)

            ScrollView {
                VStack(spacing: 0) {
                    LoginBrandHeader(iconSize: 60, showsWordmark: false)
                        .padding(.top, 48)

                    emailLoginForm
                        .frame(maxWidth: contentMaxWidth)
                        .padding(.top, 30)
                        .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var legalNotice: some View {
        Text(.init(L10n.text("auth.login.legal_markdown")))
            .font(.caption)
            .foregroundColor(.textSub.opacity(0.8))
            .tint(.textSub.opacity(0.95))
            .multilineTextAlignment(.center)
            .frame(maxWidth: contentMaxWidth)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
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
            .buttonStyle(.tactile)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showEmailLogin = true
                }
                focus(.email)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "envelope")
                        .font(.system(size: 17, weight: .medium))
                    Text(L10n.text("auth.login.email_button"))
                }
                .brandNeutralButtonStyle()
            }
            .buttonStyle(.tactile)

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
            .buttonStyle(.tactile)
        }
        .padding(.horizontal, 24)
    }
    
    var emailLoginForm: some View {
        VStack(spacing: 20) {
            if !sentCode {
                emailEntrySection
                
                Button {
                    submitEmail()
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
                .buttonStyle(.bouncy)
                .disabled(isSendingCode || !isEmailValid)

            } else {
                verificationCodeSection
                
                Button {
                    Task { await verifyCode() }
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
                .buttonStyle(.bouncy)
                .disabled(isVerifyingCode || !isVerificationCodeComplete)

            }

        }
        .padding(.horizontal, 24)
        .transition(.move(edge: .trailing))
    }

    private var emailEntrySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.text("auth.login.email_title"))
                    .font(.headline)
                    .foregroundStyle(Color.textMain)

                Text(L10n.text("auth.login.email_help"))
                    .font(.footnote)
                    .foregroundStyle(Color.textSub)
            }

            TextField(L10n.text("auth.login.email_placeholder"), text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.continue)
                .focused($focusedField, equals: .email)
                .onSubmit { submitEmail() }
                .onChange(of: email) { _, _ in
                    authService.errorMessage = nil
                    showEmailValidationError = false
                }
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background(Color.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: primaryButtonCornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: primaryButtonCornerRadius, style: .continuous)
                        .stroke(
                            emailInputErrorMessage == nil ? Color.textSub.opacity(0.1) : Color.red.opacity(0.45),
                            lineWidth: 1
                        )
                )

            if let errorMessage = emailInputErrorMessage {
                loginErrorMessage(errorMessage)
            }
        }
    }

    private var verificationCodeSection: some View {
        VStack(spacing: 14) {
            VStack(spacing: 5) {
                Text(L10n.text("auth.login.code_title"))
                    .font(.headline)
                    .foregroundStyle(Color.textMain)

                Text(L10n.text("auth.login.code_sent_to_format", normalizedEmail))
                    .font(.footnote)
                    .foregroundStyle(Color.textSub)
                    .multilineTextAlignment(.center)

                Button(L10n.text("auth.login.change_email")) {
                    changeEmail()
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.accentPrimaryText)
                .buttonStyle(.tactile)
            }

            verificationCodeInput

            if let errorMessage = emailLoginErrorMessage {
                loginErrorMessage(errorMessage)
            }

            Button {
                resendCode()
            } label: {
                if resendSecondsRemaining > 0 {
                    Text(L10n.text("auth.login.resend_countdown_format", resendSecondsRemaining))
                } else {
                    Text(L10n.text("auth.login.resend_code"))
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(resendSecondsRemaining > 0 ? Color.textSub : Color.accentPrimaryText)
            .buttonStyle(.tactile)
            .disabled(isSendingCode || isVerifyingCode || resendSecondsRemaining > 0)
        }
    }

    private var verificationCodeInput: some View {
        ZStack {
            HStack(spacing: 8) {
                ForEach(0..<Self.verificationCodeLength, id: \.self) { index in
                    let characters = Array(otpCode)
                    let character = index < characters.count ? String(characters[index]) : ""
                    let isActive = focusedField == .verificationCode && index == min(otpCode.count, Self.verificationCodeLength - 1)

                    Text(character)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.textMain)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(verificationCodeBorderColor(isActive: isActive), lineWidth: isActive ? 1.5 : 1)
                        )
                        .accessibilityHidden(true)
                }
            }

            TextField("", text: $otpCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focusedField, equals: .verificationCode)
                .foregroundStyle(.clear)
                .tint(.clear)
                .opacity(0.02)
                .onChange(of: otpCode, handleVerificationCodeChange)
                .accessibilityLabel(Text(L10n.text("auth.login.verification_code_placeholder")))
                .accessibilityValue(Text(otpCode))
        }
        .contentShape(Rectangle())
        .onTapGesture { focusedField = .verificationCode }
    }

    private func verificationCodeBorderColor(isActive: Bool) -> Color {
        if emailLoginErrorMessage != nil {
            return Color.red.opacity(0.55)
        }
        if isActive {
            return Color.accentPrimary
        }
        return Color.textSub.opacity(0.14)
    }

    private func loginErrorMessage(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)

            Text(message)
                .font(.footnote)
                .foregroundColor(.red)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }

    private func submitEmail() {
        showEmailValidationError = !isEmailValid
        guard isEmailValid, !isSendingCode else { return }

        focusedField = nil
        Task { await sendCode() }
    }

    @MainActor
    private func sendCode() async {
        isSendingCode = true
        defer { isSendingCode = false }

        let success = await authService.signInWithEmailOTP(email: normalizedEmail)
        guard success else { return }

        email = normalizedEmail
        otpCode = ""
        withAnimation(.easeInOut(duration: 0.2)) {
            sentCode = true
        }
        startResendCountdown()
        focus(.verificationCode)
    }

    private func resendCode() {
        guard resendSecondsRemaining == 0, !isSendingCode else { return }

        authService.errorMessage = nil
        otpCode = ""
        Task { await resendVerificationCode() }
    }

    @MainActor
    private func resendVerificationCode() async {
        isSendingCode = true
        defer { isSendingCode = false }

        let success = await authService.signInWithEmailOTP(email: normalizedEmail)
        guard success else { return }

        startResendCountdown()
        AppInteractionFeedback.success()
        focus(.verificationCode)
    }

    @MainActor
    private func verifyCode() async {
        guard isVerificationCodeComplete, !isVerifyingCode else { return }

        isVerifyingCode = true
        focusedField = nil
        let success = await authService.verifyEmailOTP(email: normalizedEmail, code: otpCode)
        isVerifyingCode = false

        if !success {
            otpCode = ""
            focus(.verificationCode)
        }
    }

    private func handleVerificationCodeChange(oldValue: String, newValue: String) {
        let normalizedCode = String(newValue.filter(\.isNumber).prefix(Self.verificationCodeLength))
        let oldNormalizedCount = oldValue.filter(\.isNumber).count

        if normalizedCode != newValue {
            otpCode = normalizedCode
            return
        }

        authService.errorMessage = nil

        if normalizedCode.count == Self.verificationCodeLength,
           oldNormalizedCount < Self.verificationCodeLength {
            Task { await verifyCode() }
        }
    }

    private func changeEmail() {
        authService.errorMessage = nil
        otpCode = ""
        resendSecondsRemaining = 0
        resendCountdownGeneration += 1
        withAnimation(.easeInOut(duration: 0.2)) {
            sentCode = false
        }
        focus(.email)
    }

    private func leaveEmailLogin() {
        focusedField = nil
        withAnimation(.easeInOut(duration: 0.2)) {
            authService.errorMessage = nil
            showEmailLogin = false
            sentCode = false
            otpCode = ""
        }
    }

    private func startResendCountdown() {
        resendSecondsRemaining = Self.resendDelaySeconds
        resendCountdownGeneration += 1
    }

    private func focus(_ field: FocusField) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            focusedField = field
        }
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
    var iconSize: CGFloat = 96
    var showsWordmark = true

    var body: some View {
        VStack(spacing: BrandTokens.Space.s4) {
            NoteDetailLightningBallIcon(size: iconSize)

            if showsWordmark {
                BrandWordmark()
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(L10n.text("auth.login.brand_title")))
    }
}
