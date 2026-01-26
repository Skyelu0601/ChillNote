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
                            // Section 1: Account & Subscription
                            VStack(spacing: 0) {
                                if authService.isSignedIn {
                                    // Richer Account View
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.accentColor.opacity(0.1))
                                                .frame(width: 40, height: 40)
                                            Image(systemName: "person.fill")
                                                .foregroundStyle(Color.accentColor)
                                                .font(.system(size: 20))
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("My Account")
                                                .font(.bodyMedium)
                                                .fontWeight(.medium)
                                                .foregroundColor(.textMain)
                                            
                                            if case .signedIn(_, let provider) = authService.state {
                                                Text("Signed in with \(provider.rawValue.capitalized)")
                                                    .font(.caption)
                                                    .foregroundColor(.textSub)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        if authService.isPro {
                                            Text("PRO")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.yellow.opacity(0.2))
                                                .foregroundColor(.orange)
                                                .cornerRadius(6)
                                        }
                                    }
                                    .padding(20)
                                    
                                    Divider().padding(.leading, 20)
                                    
                                    Button {
                                        // TODO: Show Paywall
                                    } label: {
                                        SettingItem(label: "Subscription", value: authService.isPro ? "Manage" : "Upgrade to Pro")
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    HStack {
                                        Image(systemName: "person.crop.circle")
                                            .font(.system(size: 24))
                                            .foregroundColor(.textSub)
                                        Text("Guest Mode")
                                            .font(.bodyMedium)
                                            .foregroundColor(.textMain)
                                        Spacer()
                                    }
                                    .padding(20)
                                    
                                    Divider().padding(.leading, 20)
                                    
                                    Button {
                                        dismiss() // Go back to login
                                    } label: {
                                        SettingItem(label: "Sign In / Sign Up")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
                            
                            // Section 2: Data & Permissions
                            VStack(spacing: 0) {
                                Button(action: exportAllNotes) {
                                    SettingItem(label: "Export All Notes", value: isExporting ? "Exporting..." : "Markdown")
                                }
                                .buttonStyle(.plain)
                                .disabled(isExporting)
                                
                                Divider().padding(.leading, 20)
                                
                                Button(action: openAppSettings) {
                                    SettingItem(label: "Permissions")
                                }
                                .buttonStyle(.plain)
                            }
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
                            
                            // Section 3: Support & About
                            VStack(spacing: 0) {
                                Button(action: sendFeedback) {
                                    SettingItem(label: "Send Feedback")
                                }
                                .buttonStyle(.plain)
                                
                                Divider().padding(.leading, 20)
                                
                                Button(action: { showPrivacy = true }) {
                                    SettingItem(label: "Privacy Policy")
                                }
                                .buttonStyle(.plain)
                                
                                Divider().padding(.leading, 20)
                                
                                Button(action: { showAgreement = true }) {
                                    SettingItem(label: "User Agreement")
                                }
                                .buttonStyle(.plain)
                                
                                Divider().padding(.leading, 20)
                                
                                Button(action: { showAbout = true }) {
                                    SettingItem(label: "About ChillNote", value: appVersion)
                                }
                                .buttonStyle(.plain)
                                
                                if authService.isSignedIn {
                                    Divider().padding(.leading, 20)
                                    
                                    Button {
                                        showDeleteAlert = true
                                    } label: {
                                        SettingItem(label: "Delete Account", labelColor: .textMain)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
                            
                            // Section 4: Sign Out (If Signed In)
                            if authService.isSignedIn {
                                VStack(spacing: 0) {
                                    Button {
                                        showLogoutConfirmation = true
                                    } label: {
                                        SettingItem(label: "Sign Out", labelColor: .red)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .background(Color.white)
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
                            }
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
                LegalTextView(title: "About ChillNote", bodyText: aboutText)
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
}

struct SettingItem: View {
    let label: String
    var value: String? = nil
    var labelColor: Color = .textMain
    
    var body: some View {
        HStack {
            Text(label)
                .font(.bodyMedium)
                .fontWeight(.medium)
                .foregroundColor(labelColor)
            Spacer()
            if let value = value {
                Text(value)
                    .font(.bodySmall)
                    .foregroundColor(.textSub)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.textSub)
            }
        }
        .padding(20)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value ?? "")
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
        ChillNote is a voice-first notes app built for quick capture. Speak your thoughts, keep them organized, and review them later.
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
                Text(bodyText)
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
