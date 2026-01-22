import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var authService: AuthService
    @AppStorage("hasGuestAccess") private var hasGuestAccess = false
    
    @State private var showPrivacy = false
    @State private var showAgreement = false
    @State private var showAbout = false
    @State private var showAIActionsSettings = false
    @State private var bannerData: BannerData?
    @State private var showLogoutConfirmation = false
    
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
                            // Section 1: Account
                            VStack(spacing: 0) {
                                if authService.isSignedIn {
                                    SettingItem(label: "Account", value: "Signed In")
                                    Divider().padding(.leading, 20)
                                    Button {
                                        showLogoutConfirmation = true
                                    } label: {
                                        SettingItem(label: "Sign Out", labelColor: .red)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    SettingItem(label: "Account", value: "Guest")
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)

                            // Section 2: AI & Customization
                            VStack(spacing: 0) {
                                Button(action: { showAIActionsSettings = true }) {
                                    SettingItem(label: "AI Quick Actions")
                                }
                                .buttonStyle(.plain)
                            }
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
                            
                            // Section 3: Permissions + Legal/About
                            VStack(spacing: 0) {
                                Button(action: openAppSettings) {
                                    SettingItem(label: "Permissions")
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
                            }
                            .background(Color.white)
                            .cornerRadius(16)
                             .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
                            
                            

                            
                            // Section 4: Actions
                            VStack(spacing: 0) {
                                Button(action: sendFeedback) {
                                    SettingItem(label: "Send Feedback")
                                }
                                .buttonStyle(.plain)
                                Divider().padding(.leading, 20)
                                if authService.isSignedIn {
                                    EmptyView()
                                } else {
                                    Button {
                                        dismiss()
                                    } label: {
                                        SettingItem(label: "Sign In", labelColor: .textMain)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(16)
                             .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
                        }
                        .padding(.horizontal, 24)
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
            .fullScreenCover(isPresented: $showAIActionsSettings) {
                AIActionsSettingsView()
                    .environmentObject(AIActionsManager.shared)
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
