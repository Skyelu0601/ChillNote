import SwiftUI
import UIKit

struct SettingsAutoNavigationPolicy {
    private var hasConsumedPendingAutoNavigation = false

    mutating func shouldAutoNavigatePending(autoNavigateToPendingRecordings: Bool) -> Bool {
        guard autoNavigateToPendingRecordings, !hasConsumedPendingAutoNavigation else {
            return false
        }
        hasConsumedPendingAutoNavigation = true
        return true
    }
}

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
    @State private var isPendingRecordingsActive = false
    @State private var pendingRecordingsCount = 0
    @StateObject private var exportViewModel = ExportViewModel()
    @State private var showExportAllSheet = false
    @State private var showVoiceLanguageSheet = false
    // Auto Navigation
    var autoNavigateToAI: Bool = false
    var autoNavigateToPendingRecordings: Bool = false
    @State private var isAIConfigActive = false
    @State private var autoNavigationPolicy = SettingsAutoNavigationPolicy()
    
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
                        Text("Settings")
                        .font(.bodyLarge)
                        .fontWeight(.bold)
                        Spacer()
                        // invisible spacer to balance
                        Image(systemName: "arrow.left").opacity(0)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            accountSection
                            aiCapabilitiesSection
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
            .navigationDestination(isPresented: $isAIConfigActive) {
                ChillRecipesView()
            }
            .navigationDestination(isPresented: $isPendingRecordingsActive) {
                PendingRecordingsView()
            }
            .onAppear {
                refreshPendingRecordingsCount()
                if autoNavigateToAI {
                    // Small delay to ensure View is fully loaded before triggering navigation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isAIConfigActive = true
                    }
                }
                if autoNavigateToPendingRecordings {
                    if autoNavigationPolicy.shouldAutoNavigatePending(autoNavigateToPendingRecordings: autoNavigateToPendingRecordings) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isPendingRecordingsActive = true
                        }
                    }
                }
            }
            .onChange(of: isPendingRecordingsActive) { _, isActive in
                if !isActive {
                    refreshPendingRecordingsCount()
                }
            }

            .sheet(isPresented: $showPrivacy) {
                LegalTextView(title: "Privacy Policy", bodyText: privacyText)
            }
            .sheet(isPresented: $showAgreement) {
                LegalTextView(title: "User Agreement", bodyText: agreementText)
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
            .alert("Sign Out", isPresented: $showLogoutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authService.signOut()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Delete Account", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
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
                Text("Are you sure you want to delete your account? All your data will be permanently removed. This action cannot be undone.")
            }
            .alert("Deletion Failed", isPresented: $showDeleteError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(authService.errorMessage ?? "An unknown error occurred.")
            }
            .alert("Export Failed", isPresented: $exportViewModel.showErrorAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Retry") {
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
                                Text("My Account")
                                    .font(.headline)
                                    .foregroundColor(.textMain)
                                if storeService.currentTier == .pro {
                                    Text("PRO")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.accentPrimary))
                                }
                            }
                            let rawEmail = authService.currentUser?.email ?? ""
                            let emailLabel = rawEmail.isEmpty ? "Unknown email" : rawEmail
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
                                Text("Subscription Plan")
                                    .font(.subheadline)
                                    .foregroundColor(.textMain)
                                Text(storeService.currentTier == .pro ? "Pro Active" : "Free Plan")
                                    .font(.caption)
                                    .foregroundColor(.textSub)
                            }
                            Spacer()
                            Text(storeService.currentTier == .pro ? "Manage" : "Upgrade")
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
                        
                        Text("Sign In to ChillNote")
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
    
    private var aiCapabilitiesSection: some View {
        VStack(spacing: 0) {
            
            // New Chill Recipes Link
            Button {
                isAIConfigActive = true
            } label: {
                SettingItem(icon: "book.closed", iconColor: .accentPrimary, label: "Chill Recipes")
            }
            .buttonStyle(.plain)
            
        }
        .padding(.bottom, 8)
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
                    label: "Export All Notes"
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 56)

            Button(action: { isPendingRecordingsActive = true }) {
                SettingItem(
                    icon: "waveform",
                    iconColor: .accentPrimary,
                    label: "Pending Recordings",
                    value: pendingRecordingsCount == 0 ? nil : "\(pendingRecordingsCount)"
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 56)

            Button(action: { showVoiceLanguageSheet = true }) {
                SettingItem(
                    icon: "waveform.and.mic",
                    iconColor: .accentPrimary,
                    label: "Voice Language",
                    value: voiceTranscriptionLanguageSummary
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 56)


            
            Button(action: openAppSettings) {
                SettingItem(icon: "shield", iconColor: .accentPrimary, label: "Permissions")
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
                SettingItem(icon: "envelope", iconColor: .accentPrimary, label: "Send Feedback")
            }
            .buttonStyle(.plain)
            
            Divider().padding(.leading, 56)

            
            Button(action: openPrivacyPolicy) {
                SettingItem(icon: "hand.raised", iconColor: .accentPrimary, label: "Privacy Policy")
            }
            .buttonStyle(.plain)
            
            Divider().padding(.leading, 56)
            
            Button(action: openUserAgreement) {
                SettingItem(icon: "doc.text", iconColor: .accentPrimary, label: "User Agreement")
            }
            .buttonStyle(.plain)
            
            Divider().padding(.leading, 56)
            
            Button(action: { showAbout = true }) {
                SettingItem(icon: "info.circle", iconColor: .accentPrimary, label: "About ChillNote")
            }
            .buttonStyle(.plain)
            
            if authService.isSignedIn {
                Divider().padding(.leading, 56)
                
                Button {
                    showDeleteAlert = true
                } label: {
                    SettingItem(icon: "trash", iconColor: .accentPrimary, label: "Delete Account", showChevron: true)
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
                        SettingItem(icon: "rectangle.portrait.and.arrow.right", iconColor: .red, label: "Sign Out", labelColor: .red, showChevron: false)
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
    var labelColor: Color = .textMain
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
                    .foregroundColor(.textSub)
            }
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.textSub.opacity(0.7))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}

private struct VoiceLanguageOption: Identifiable {
    let code: String
    let name: String

    var id: String { code }

    static let all: [VoiceLanguageOption] = {
        let prioritizedIdentifiers = ["en", "zh-Hans", "zh-Hant", "es", "fr", "de", "ja", "ko", "pt", "ru", "ar", "hi", "id", "th", "vi", "tr", "it"]
        let prioritizedSet = Set(prioritizedIdentifiers.map { $0.lowercased() })
        var optionsByKey: [String: VoiceLanguageOption] = [:]

        func insert(_ identifier: String) {
            let normalized = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { return }
            let key = normalized.lowercased()
            guard optionsByKey[key] == nil else { return }
            optionsByKey[key] = VoiceLanguageOption(
                code: normalized,
                name: displayName(for: normalized)
            )
        }

        for identifier in prioritizedIdentifiers {
            insert(identifier)
        }
        for languageCode in Locale.LanguageCode.isoLanguageCodes {
            insert(languageCode.identifier)
        }

        let prioritizedOptions = prioritizedIdentifiers.compactMap { optionsByKey[$0.lowercased()] }
        let remainingOptions = optionsByKey
            .filter { !prioritizedSet.contains($0.key) }
            .map(\.value)
            .sorted {
                if $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedSame {
                    return $0.code.localizedCaseInsensitiveCompare($1.code) == .orderedAscending
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

        return prioritizedOptions + remainingOptions
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

private struct VoiceLanguagePreferenceSheet: View {
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
                    Text("Auto Detect").tag(VoiceTranscriptionLanguageMode.auto)
                    Text("Preferred Language").tag(VoiceTranscriptionLanguageMode.prefer)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)

                if selectedMode == .auto {
                    Text("Language will be inferred from audio. Mixed-language speech is preserved.")
                        .font(.bodySmall)
                        .foregroundColor(.textSub)
                        .padding(.horizontal, 20)
                    Spacer(minLength: 0)
                } else {
                    Text("Preferred language improves primary-language stability while preserving mixed-language speech.")
                        .font(.bodySmall)
                        .foregroundColor(.textSub)
                        .padding(.horizontal, 20)

                    TextField("Search language", text: $searchText)
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
            .navigationTitle("Voice Transcription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Export All Notes")
                            .font(.bodyLarge)
                            .foregroundColor(.textMain)
                        Text("Markdown (.zip)")
                            .font(.bodySmall)
                            .foregroundColor(.textSub)
                    }

                    Group {
                        if viewModel.isLoadingEstimate {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Counting notes...")
                                    .font(.bodySmall)
                                    .foregroundColor(.textSub)
                            }
                        } else {
                            let count = viewModel.estimatedNoteCount ?? 0
                            Text("Estimated notes: \(count)")
                                .font(.bodyMedium)
                                .foregroundColor(.textMain)
                        }
                    }

                    if viewModel.isExporting || viewModel.progress.processed > 0 {
                        ExportProgressView(
                            progress: viewModel.progress,
                            isExporting: viewModel.isExporting,
                            onCancel: { viewModel.cancelExport() }
                        )
                    }

                    if let successMessage = viewModel.successMessage, !viewModel.isExporting {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentPrimary)
                            Text(successMessage)
                                .font(.bodySmall)
                                .foregroundColor(.textSub)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if !viewModel.isLoadingEstimate,
                       (viewModel.estimatedNoteCount ?? 0) == 0,
                       !viewModel.isExporting {
                        Text("No notes to export.")
                            .font(.bodySmall)
                            .foregroundColor(.textSub)
                    }

                    Button(action: {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            viewModel.startExport(userId: userId)
                        }
                    }) {
                        Text("Start Export")
                            .font(.bodyMedium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentPrimary)
                    .disabled(viewModel.isLoadingEstimate || viewModel.isExporting || (viewModel.estimatedNoteCount ?? 0) == 0)

                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.bodyMedium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isExporting)
                }
                .padding(20)
            }
            .background(Color.bgPrimary.ignoresSafeArea())
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
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
}

#Preview {
    SettingsView()
}

private extension SettingsView {
    var voiceTranscriptionLanguageSummary: String {
        let mode = VoiceTranscriptionLanguageMode(rawValue: voiceLanguageModeRawValue) ?? .auto
        switch mode {
        case .auto:
            return "Auto"
        case .prefer:
            let trimmed = voiceLanguageHint.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return "Not Set" }
            return VoiceLanguageOption.shortDisplayName(for: trimmed)
        }
    }

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }

    func refreshPendingRecordingsCount() {
        RecordingFileManager.shared.cleanupOldRecordings()
        let pending = RecordingFileManager.shared.checkForPendingRecordings()
        pendingRecordingsCount = pending.count
    }

    func handleExportAllTap() {
        guard authService.isSignedIn else {
            bannerData = BannerData(message: "Sign in required to export.", style: .warning)
            return
        }
        exportViewModel.resetEstimate()
        showExportAllSheet = true
    }
    
    var privacyText: String {
        """
        ChillNote stores your notes locally and syncs them to the cloud when you're signed in. We protect your data in transit and at rest.

        Microphone access is used to turn your voice into text. Recordings are stored locally on your device for crash recovery and pending transcription, and are deleted after successful processing or within 7 days.
        """
    }
    
    var agreementText: String {
        """
        By using ChillNote, you agree to use the app responsibly and understand that your notes are stored locally and synced to the cloud when you're signed in.
        """
    }
    
    var aboutText: String {
        """
        **ChillNote: Design Philosophy**

        "Capturing the speed of thought, one voice at a time."

        ChillNote realigns how we capture thoughts. By prioritizing voice input and AI organization, we bridge the gap between your mind's speed and your typing speed.

        **Who is it for?**

        **1. The ADHD & Hyper-Active Mind**
        "My thoughts run faster than my fingers." Voice is the path of least resistance, letting your stream of consciousness flow freely.

        **2. The "Struggling Writer"**
        "I have the idea, but I can't find the words." Pour out messy thoughts, and let ChillNote's AI restructure them into clear prose.

        **3. Creative Workers**
        "Typing is unnatural; Speaking is instinct." Speak your ideas; let the system handle formatting and structure.

        **4. Reflective Thinkers**
        "Talk helps untangle thoughts." Use your voice to journal, vent, and reflect.

        **5. The "Format Haters"**
        "Life is too short to adjust margins." One-click perfection. Focus on content, not aesthetics.

        **What ChillNote is NOT**

        • **Not for Meeting Minutes**: For personal reflections, not polished corporate records.
        • **Not for Long-Form Writing**: For seeds of ideas, not entire novels.
        • **The 10-Minute Limit**: If it takes >10 mins, it's not Chill.

        **Our Vision**
        To return us to a natural, healthy state of being. For the dreamers, the creators, and anyone whose ideas deserve to be heard.
        """
    }
    
    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
    
    func sendFeedback() {
        guard let url = URL(string: "mailto:support@chillnoteai.com?subject=ChillNote%20Feedback") else { return }
        UIApplication.shared.open(url)
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
    let bodyText: String
    
    var body: some View {
        NavigationStack {
            ScrollView {
                Text(LocalizedStringKey(bodyText))
                    .font(.bodyMedium)
                    .foregroundColor(.textMain)
                    .padding(24)
            }
            .background(Color.bgPrimary.ignoresSafeArea())
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
