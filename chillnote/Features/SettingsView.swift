import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var authService: AuthService
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasGuestAccess") private var hasGuestAccess = false
    
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
    
    // Export State
    @State private var showExportSheet = false
    @State private var exportURL: URL?
    @State private var isExporting = false
    
    var body: some View {
        NavigationView {
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
            .sheet(isPresented: $showExportSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }

            .banner(data: $bannerData)
            .alert("Sign Out", isPresented: $showLogoutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authService.signOut()
                    hasGuestAccess = false
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
                        if await authService.deleteAccount() {
                            hasGuestAccess = false
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
            .disabled(isDeleting)
            .overlay {
                if isDeleting {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        ProgressView("Deleting...")
                            .controlSize(.large)
                            .padding(24)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(radius: 10)
                    }
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var accountSection: some View {
        VStack(spacing: 0) {
            if authService.isSignedIn {
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(storeService.currentTier == .pro ? 
                                      AnyShapeStyle(LinearGradient(colors: [Color.accentPrimary, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing)) :
                                      AnyShapeStyle(Color.gray.opacity(0.1)))
                                .frame(width: 56, height: 56)
                            
                            Image(systemName: storeService.currentTier == .pro ? "sparkles" : "person.fill")
                                .font(.system(size: 24))
                                .foregroundColor(storeService.currentTier == .pro ? .white : .gray)
                        }
                        
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
                            if let email = authService.currentUser?.email {
                                HStack(spacing: 4) {
                                    let provider = authService.loginProvider
                                    if provider.contains("google") {
                                        Image(systemName: "globe")
                                    } else if provider.contains("apple") {
                                        Image(systemName: "apple.logo")
                                    } else {
                                        Image(systemName: "envelope")
                                    }
                                    
                                    Text(email)
                                }
                                .font(.caption)
                                .foregroundColor(.textSub)
                            }
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
    
    private var dataSection: some View {
        VStack(spacing: 0) {
            Button(action: exportAllNotes) {
                SettingItem(icon: "square.and.arrow.up", iconColor: .accentPrimary, label: "Export All Notes", value: isExporting ? "Exporting..." : nil)
            }
            .buttonStyle(.plain)
            .disabled(isExporting)
            
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
            Button(action: openAppSettings) {
                SettingItem(icon: "globe", iconColor: .accentPrimary, label: "settings.language")
            }
            .buttonStyle(.plain)
            
            Divider().padding(.leading, 56)

            Button(action: sendFeedback) {
                SettingItem(icon: "envelope", iconColor: .accentPrimary, label: "Send Feedback")
            }
            .buttonStyle(.plain)
            
            Divider().padding(.leading, 56)
            
            Button(action: { showPrivacy = true }) {
                SettingItem(icon: "hand.raised", iconColor: .accentPrimary, label: "Privacy Policy")
            }
            .buttonStyle(.plain)
            
            Divider().padding(.leading, 56)
            
            Button(action: { showAgreement = true }) {
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

#Preview {
    SettingsView()
}

private extension SettingsView {
    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }
    
    var privacyText: String {
        """
        ChillNote stores your notes locally and syncs them to the cloud when you're signed in. We protect your data in transit and at rest.

        Microphone and Speech access are used to turn your voice into text. Recordings are not kept after transcription unless you explicitly choose to keep them.
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

        **4. Seekers of Self-Healing**
        "Talk is a way to heal yourself." Use your voice to journal, vent, and reflect.

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
        guard let url = URL(string: "mailto:skye@sponteoai.com?subject=ChillNote%20Feedback") else { return }
        UIApplication.shared.open(url)
    }
    
    func exportAllNotes() {
        isExporting = true
        Task {
            do {
                // Ensure we are on main actor for modelContext access if strict, 
                // but NoteExportService needs context passed to it.
                // We'll run logic on MainActor because SwiftData is MainActor bound usually.
                let url = try NoteExportService.shared.createExportBundle(modelContext: modelContext)
                
                exportURL = url
                showExportSheet = true
            } catch {
                print("Export failed: \(error)")
                // In production, show error alert
            }
            isExporting = false
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
