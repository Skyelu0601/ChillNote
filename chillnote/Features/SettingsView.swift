import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var authService: AuthService
    @AppStorage(VoiceTranscriptionPreferences.modeStorageKey) private var voiceLanguageModeRawValue = VoiceTranscriptionLanguageMode.auto.rawValue
    @AppStorage(VoiceTranscriptionPreferences.hintStorageKey) private var voiceLanguageHint = ""
    
    @State private var showPrivacy = false
    @State private var showAgreement = false
    @State private var showAbout = false

    @StateObject private var storeService = StoreService.shared
    @State private var showSubscription = false
    @State private var bannerData: BannerData?
    @State private var showLogoutConfirmation = false
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var showDeleteError = false
    @StateObject private var exportViewModel = ExportViewModel()
    @State private var showExportAllSheet = false
    @State private var showVoiceLanguageSheet = false
    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 24))
                                .foregroundColor(.textMain)
                        }
                        Spacer()
                        Text(L10n.text("settings.title"))
                        .font(.bodyLarge)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        Spacer()
                        // invisible spacer to balance
                        Image(systemName: "arrow.left").opacity(0)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            accountSection
                            dataSection
                            supportSection
                            signOutSection
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showPrivacy) {
                LegalTextView(title: L10n.text("settings.support.privacy_policy"), bodyKey: "settings.support.privacy_policy_body")
            }
            .sheet(isPresented: $showAgreement) {
                LegalTextView(title: L10n.text("settings.support.user_agreement"), bodyKey: "settings.support.user_agreement_body")
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
            .sheet(isPresented: $showSubscription) {
                SubscriptionView()
            }
            .sheet(isPresented: $showExportAllSheet, onDismiss: {
                exportViewModel.resetEstimate()
            }) {
                ExportAllNotesSheet(
                    viewModel: exportViewModel,
                    userId: authService.currentUserId
                )
                .interactiveDismissDisabled(exportViewModel.isExporting)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showVoiceLanguageSheet) {
                VoiceLanguagePreferenceSheet(
                    modeRawValue: $voiceLanguageModeRawValue,
                    preferredLanguageHint: $voiceLanguageHint
                )
            }
            .banner(data: $bannerData)
            .alert(L10n.text("settings.alert.sign_out.title"), isPresented: $showLogoutConfirmation) {
                Button(L10n.text("common.cancel"), role: .cancel) { }
                Button(L10n.text("settings.account.sign_out"), role: .destructive) {
                    authService.signOut()
                    dismiss()
                }
            } message: {
                Text(L10n.text("settings.alert.sign_out.message"))
            }
            .alert(L10n.text("settings.alert.delete_account.title"), isPresented: $showDeleteAlert) {
                Button(L10n.text("common.cancel"), role: .cancel) { }
                Button(L10n.text("common.delete"), role: .destructive) {
                    isDeleting = true
                    Task {
                        let success = await authService.deleteAccount()
                        if success {
                            dismiss()
                        } else {
                            isDeleting = false
                            showDeleteError = true
                        }
                    }
                }
            } message: {
                Text(L10n.text("settings.alert.delete_account.message"))
            }
            .alert(L10n.text("settings.alert.deletion_failed.title"), isPresented: $showDeleteError) {
                Button(L10n.text("common.ok"), role: .cancel) { }
            } message: {
                Text(authService.errorMessage ?? L10n.text("common.error.unknown"))
            }
            .alert(L10n.text("settings.alert.export_failed.title"), isPresented: $exportViewModel.showErrorAlert) {
                Button(L10n.text("common.cancel"), role: .cancel) { }
                Button(L10n.text("common.retry")) {
                    exportViewModel.startExport(userId: authService.currentUserId)
                }
            } message: {
                Text(exportViewModel.errorMessage)
            }
            .disabled(isDeleting)
        }
    }

// MARK: - Sections
    
    private var accountSection: some View {
        VStack(spacing: 0) {
            if authService.isSignedIn {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(L10n.text("settings.account.title"))
                                    .font(.headline)
                                    .foregroundColor(.textMain)
                                if storeService.currentTier == .pro {
                                    Text(L10n.text("settings.account.pro_badge"))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.accentPrimary))
                                }
                            }
                            let rawEmail = authService.currentUser?.email ?? ""
                            let emailLabel = rawEmail.isEmpty ? L10n.text("settings.account.unknown_email") : rawEmail
                            HStack(spacing: 4) {
                                Image(systemName: loginProviderIconName)
                                Text(emailLabel)
                            }
                            .font(.caption)
                            .foregroundColor(.textSub)
                        }
                        Spacer()
                    }
                    
                    Divider()
                    
                    Button {
                        showSubscription = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.text("settings.account.subscription_plan"))
                                    .font(.subheadline)
                                    .foregroundColor(.textMain)
                                Text(storeService.currentTier == .pro ? L10n.text("settings.account.pro_active") : L10n.text("settings.account.free_plan"))
                                    .font(.caption)
                                    .foregroundColor(.textSub)
                            }
                            Spacer()
                            Text(storeService.currentTier == .pro ? L10n.text("settings.account.manage") : L10n.text("settings.account.upgrade"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(storeService.currentTier == .pro ? .textMain : .accentPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    storeService.currentTier == .pro ? 
                                    Color.gray.opacity(0.1) : 
                                    Color.accentPrimary.opacity(0.1)
                                )
                                .cornerRadius(12)
                        }
                        .padding(.top, 4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            } else {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color.accentColor.opacity(0.1))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.title3)
                                    .foregroundColor(.accentColor)
                            )
                        
                        Text(L10n.text("settings.account.sign_in"))
                            .font(.headline)
                            .foregroundColor(.textMain)
                            
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.textSub)
                    }
                    .padding(20)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
    }
    
    private var dataSection: some View {
        VStack(spacing: 0) {
            Button(action: handleExportAllTap) {
                SettingItem(
                    icon: "square.and.arrow.up",
                    iconColor: .accentPrimary,
                    label: "settings.data.export_all_notes"
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 56)

            Button(action: { showVoiceLanguageSheet = true }) {
                SettingItem(
                    icon: "globe",
                    iconColor: .accentPrimary,
                    label: "settings.data.voice_language",
                    value: voiceTranscriptionLanguageSummary
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 56)


            
            Button(action: openAppSettings) {
                SettingItem(icon: "shield", iconColor: .accentPrimary, label: "settings.data.permissions")
            }
            .buttonStyle(.plain)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
    }
    
    private var supportSection: some View {
        VStack(spacing: 0) {
            Button(action: sendFeedback) {
                SettingItem(icon: "envelope", iconColor: .accentPrimary, label: "settings.support.send_feedback")
            }
            .buttonStyle(.plain)
            
            Divider().padding(.leading, 56)

            
            Button(action: openPrivacyPolicy) {
                SettingItem(icon: "hand.raised", iconColor: .accentPrimary, label: "settings.support.privacy_policy")
            }
            .buttonStyle(.plain)
            
            Divider().padding(.leading, 56)
            
            Button(action: openUserAgreement) {
                SettingItem(icon: "doc.text", iconColor: .accentPrimary, label: "settings.support.user_agreement")
            }
            .buttonStyle(.plain)
            
            Divider().padding(.leading, 56)
            
            Button(action: { showAbout = true }) {
                SettingItem(icon: "info.circle", iconColor: .accentPrimary, label: "settings.support.about")
            }
            .buttonStyle(.plain)
            
            if authService.isSignedIn {
                Divider().padding(.leading, 56)
                
                Button {
                    showDeleteAlert = true
                } label: {
                    SettingItem(icon: "trash", iconColor: .accentPrimary, label: "settings.account.delete_account", showChevron: true)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
    }

    private var signOutSection: some View {
        Group {
            if authService.isSignedIn {
                VStack(spacing: 0) {
                    Button {
                        showLogoutConfirmation = true
                    } label: {
                        SettingItem(icon: "rectangle.portrait.and.arrow.right", iconColor: .red, label: "settings.account.sign_out", labelColor: .red, showChevron: false)
                    }
                    .buttonStyle(.plain)
                }
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
            } else {
                EmptyView()
            }
        }
    }

}

struct SettingItem: View {
    let icon: String // Icon name
    let iconColor: Color
    let label: String
    var value: String? = nil
    var showsBadgeDot: Bool = false
    var labelColor: Color = .textMain
    var valueColor: Color = .textSub
    var showChevron: Bool = true
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.system(size: 20)) // Slightly larger since no background
                .frame(width: 24, height: 24) // Fixed frame for alignment
            
            Text(LocalizedStringKey(label))
                .font(.bodyMedium)
                .foregroundColor(labelColor)
            
            Spacer()
            
            if let value = value {
                Text(value)
                    .font(.bodySmall)
                    .foregroundColor(valueColor)
            }

            if showsBadgeDot {
                Circle()
                    .fill(Color.red)
                    .frame(width: 7, height: 7)
                    .offset(y: -0.5)
            }
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.textSub.opacity(0.7))
                    .padding(.leading, showsBadgeDot ? 4 : 0)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}

struct VoiceLanguageOption: Identifiable {
    let code: String
    let name: String

    var id: String { code }

    static let all: [VoiceLanguageOption] = {
        // Keep onboarding/settings aligned with Gemini's published language support.
        // Chinese is split into Simplified and Traditional for a clearer user choice.
        let curatedIdentifiers = [
            "en", "zh-Hans", "zh-Hant", "ja", "ko", "fr", "de", "es",
            "ar", "bn", "bg", "hr", "cs", "da", "nl", "et",
            "fi", "el", "he", "hi", "hu", "id", "it", "lv",
            "lt", "no", "pl", "pt", "ro", "ru", "sr",
            "sk", "sl", "sw", "sv", "th", "tr", "uk", "vi"
        ]

        return curatedIdentifiers.map { identifier in
            VoiceLanguageOption(
                code: identifier,
                name: displayName(for: identifier)
            )
        }
    }()

    static func displayName(for identifier: String) -> String {
        if let localizedByIdentifier = Locale.current.localizedString(forIdentifier: identifier),
           !localizedByIdentifier.isEmpty {
            return localizedByIdentifier
        }
        if let localizedByLanguageCode = Locale.current.localizedString(forLanguageCode: identifier),
           !localizedByLanguageCode.isEmpty {
            return localizedByLanguageCode
        }
        return identifier
    }

    static func shortDisplayName(for identifier: String) -> String {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return identifier }

        switch trimmed.lowercased() {
        case "zh-hans":
            return "简体中文"
        case "zh-hant":
            return "繁體中文"
        default:
            break
        }

        if let languageCode = Locale.Language(identifier: trimmed).languageCode?.identifier,
           let localizedByLanguageCode = Locale.current.localizedString(forLanguageCode: languageCode),
           !localizedByLanguageCode.isEmpty {
            return localizedByLanguageCode
        }

        if let localizedByLanguageCode = Locale.current.localizedString(forLanguageCode: trimmed),
           !localizedByLanguageCode.isEmpty {
            return localizedByLanguageCode
        }

        return trimmed.uppercased()
    }
}

struct VoiceLanguagePreferenceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var modeRawValue: String
    @Binding var preferredLanguageHint: String

    @State private var searchText = ""

    private var selectedMode: VoiceTranscriptionLanguageMode {
        VoiceTranscriptionLanguageMode(rawValue: modeRawValue) ?? .auto
    }

    private var normalizedPreferredLanguageHint: String? {
        let trimmed = preferredLanguageHint.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var filteredLanguages: [VoiceLanguageOption] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return VoiceLanguageOption.all }
        return VoiceLanguageOption.all.filter { option in
            option.code.localizedCaseInsensitiveContains(trimmedSearch)
            || option.name.localizedCaseInsensitiveContains(trimmedSearch)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Mode", selection: Binding(
                    get: { selectedMode },
                    set: { newMode in
                        modeRawValue = newMode.rawValue
                    }
                )) {
                    Text(L10n.text("settings.voice.mode.auto_detect")).tag(VoiceTranscriptionLanguageMode.auto)
                    Text(L10n.text("settings.voice.mode.preferred_language")).tag(VoiceTranscriptionLanguageMode.prefer)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)

                if selectedMode == .auto {
                    Text(L10n.text("settings.voice.auto_help"))
                        .font(.bodySmall)
                        .foregroundColor(.textSub)
                        .padding(.horizontal, 20)
                    Spacer(minLength: 0)
                } else {
                    Text(L10n.text("settings.voice.preferred_help"))
                        .font(.bodySmall)
                        .foregroundColor(.textSub)
                        .padding(.horizontal, 20)

                    TextField(L10n.text("settings.voice.search_placeholder"), text: $searchText)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.bgSecondary)
                        .cornerRadius(10)
                        .padding(.horizontal, 20)

                    List(filteredLanguages) { option in
                        Button {
                            preferredLanguageHint = option.code
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.name)
                                        .font(.bodyMedium)
                                        .foregroundColor(.textMain)
                                    Text(option.code)
                                        .font(.caption)
                                        .foregroundColor(.textSub)
                                }
                                Spacer()
                                if normalizedPreferredLanguageHint?.lowercased() == option.code.lowercased() {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentPrimary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .padding(.top, 16)
            .background(Color.bgPrimary.ignoresSafeArea())
            .navigationTitle(L10n.text("settings.voice.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.text("common.close")) { dismiss() }
                }
            }
        }
    }
}



private struct ExportAllNotesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ExportViewModel
    let userId: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        exportHeroSection

                        if viewModel.isExporting || viewModel.progress.processed > 0 {
                            ExportProgressView(
                                progress: viewModel.progress,
                                isExporting: viewModel.isExporting,
                                onCancel: { viewModel.cancelExport() }
                            )
                            .padding(.horizontal, 20)
                        } else if let successMessage = viewModel.successMessage {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title3)
                                Text(successMessage)
                                    .font(.bodyMedium)
                                    .foregroundColor(.textMain)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(16)
                            .padding(.horizontal, 20)
                        } else if !viewModel.isLoadingEstimate && (viewModel.estimatedNoteCount ?? 0) == 0 {
                             Text(L10n.text("settings.export.no_notes"))
                                .font(.bodyMedium)
                                .foregroundColor(.textSub)
                                .padding(.top, 10)
                        }

                        exportBenefitsSection
                    }
                    .padding(.bottom, 40)
                }
                
                VStack {
                    Divider()
                    Button(action: {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            viewModel.startExport(userId: userId)
                        }
                    }) {
                        HStack {
                            if viewModel.isExporting {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.trailing, 8)
                            }
                            Text(viewModel.isExporting ? L10n.text("settings.export.exporting") : L10n.text("settings.export.cta"))
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            (viewModel.isLoadingEstimate || viewModel.isExporting || (viewModel.estimatedNoteCount ?? 0) == 0) 
                            ? Color.gray.opacity(0.3) 
                            : Color.accentPrimary
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }
                    .disabled(viewModel.isLoadingEstimate || viewModel.isExporting || (viewModel.estimatedNoteCount ?? 0) == 0)
                    .padding(20)
                }
                .background(Color.bgPrimary.ignoresSafeArea(edges: .bottom))
            }
            .background(Color.bgPrimary.ignoresSafeArea())
            .navigationTitle(L10n.text("settings.export.nav_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.text("common.close")) {
                        dismiss()
                    }
                    .disabled(viewModel.isExporting)
                }
            }
            .task {
                viewModel.prepareIfNeeded(userId: userId)
            }
            .sheet(isPresented: $viewModel.showShareSheet, onDismiss: {
                viewModel.handleShareDismissed()
            }) {
                if let exportURL = viewModel.exportURL {
                    ShareSheet(activityItems: [exportURL])
                }
            }
        }
    }

    private var exportHeroSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                Text(L10n.text("settings.export.title"))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.textMain)
                    .multilineTextAlignment(.center)

                Text(L10n.text("settings.export.subtitle"))
                    .font(.bodyMedium)
                    .foregroundColor(.textSub)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ExportFactCard(
                    icon: "doc.text",
                    title: L10n.text("settings.export.total_notes"),
                    value: estimatedNoteCountText
                )

                ExportFactCard(
                    icon: "curlybraces.square",
                    title: L10n.text("settings.export.format"),
                    value: L10n.text("settings.export.format_markdown")
                )
            }
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color.white, Color.accentPrimary.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.accentPrimary.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private var exportBenefitsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.text("settings.export.benefits_title"))
                .font(.caption.weight(.semibold))
                .foregroundColor(.textSub)
                .tracking(1)

            VStack(spacing: 12) {
                ExportBenefitRow(
                    icon: "lock.open.fill",
                    title: L10n.text("settings.export.benefit_portable_title"),
                    message: L10n.text("settings.export.benefit_portable_body")
                )
                ExportBenefitRow(
                    icon: "sparkles.rectangle.stack.fill",
                    title: L10n.text("settings.export.benefit_ai_title"),
                    message: L10n.text("settings.export.benefit_ai_body")
                )
                ExportBenefitRow(
                    icon: "square.and.arrow.up.on.square.fill",
                    title: L10n.text("settings.export.benefit_move_title"),
                    message: L10n.text("settings.export.benefit_move_body")
                )
            }
        }
        .padding(.horizontal, 20)
    }

    private var estimatedNoteCountText: String {
        if viewModel.isLoadingEstimate {
            return "..."
        }
        return "\(viewModel.estimatedNoteCount ?? 0)"
    }
}

private struct ExportFactCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.accentPrimary)

            Text(title)
                .font(.caption)
                .foregroundColor(.textSub)

            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundColor(.textMain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct ExportBenefitRow: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentPrimary.opacity(0.10))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.accentPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.bodyMedium.weight(.semibold))
                    .foregroundColor(.textMain)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.textSub)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }
}

#Preview {
    SettingsView()
}

private extension SettingsView {
    var voiceTranscriptionLanguageSummary: String {
        let mode = VoiceTranscriptionLanguageMode(rawValue: voiceLanguageModeRawValue) ?? .auto
        switch mode {
        case .auto:
            return L10n.text("settings.voice.summary.auto")
        case .prefer:
            let trimmed = voiceLanguageHint.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return L10n.text("settings.voice.summary.not_set") }
            return VoiceLanguageOption.shortDisplayName(for: trimmed)
        }
    }

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }

    func handleExportAllTap() {
        guard authService.isSignedIn else {
            bannerData = BannerData(message: L10n.text("export.error.sign_in_required"), style: .warning)
            return
        }
        exportViewModel.resetEstimate()
        showExportAllSheet = true
    }
    
    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
    
    func sendFeedback() {
        AppRatingService.shared.openFeedbackEmail()
    }
    
    func openPrivacyPolicy() {
        guard let url = URL(string: "https://www.chillnoteai.com/privacy.html") else { return }
        UIApplication.shared.open(url)
    }
    
    func openUserAgreement() {
        guard let url = URL(string: "https://www.chillnoteai.com/terms.html") else { return }
        UIApplication.shared.open(url)
    }
    
    var loginProviderIconName: String {
        guard authService.isSignedIn else {
            return "envelope"
        }
        let providerLiteral = authService.loginProvider.lowercased()
        if providerLiteral.contains("google") {
            return "globe"
        } else if providerLiteral.contains("apple") {
            return "apple.logo"
        } else {
            return "envelope"
        }
    }
}

private struct LegalTextView: View {
    @Environment(\.dismiss) var dismiss
    let title: String
    let bodyKey: String
    
    var body: some View {
        NavigationStack {
            ScrollView {
                Text(L10n.text(bodyKey))
                    .font(.bodyMedium)
                    .foregroundColor(.textMain)
                    .padding(24)
            }
            .background(Color.bgPrimary.ignoresSafeArea())
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.text("common.done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}
