import SwiftUI
import SwiftData
import GoogleSignIn
import GoMarketMe

@main
struct ChillScriptApp: App {
    @UIApplicationDelegateAdaptor(ChillScriptAppDelegate.self) private var appDelegate
    @StateObject private var authService = AuthService.shared
    @StateObject private var syncManager = SyncManager()
    @StateObject private var dataService = DataService.shared
    @StateObject private var aiConsentManager = AIConsentManager.shared

    
    init() {
        GoMarketMe.shared.initialize(apiKey: AppConfig.goMarketMeAPIKey)
        MediaLinkTranscriptSectionPreferences.syncToShareExtension()

        // Ensure data is seeded on launch
        Task { @MainActor in
            // Clean up old recording files (>24 hours)
            RecordingFileManager.shared.cleanupOldRecordings()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if let container = dataService.container {
#if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-weekly-topics-design-preview") {
                        WeeklyTopicsDesignPreview()
                    } else if ProcessInfo.processInfo.arguments.contains("-first-action-spotlight-design-preview") {
                        FirstActionGuideSpotlightDesignPreview()
                    } else if ProcessInfo.processInfo.arguments.contains("-first-action-guide-design-preview") {
                        HomeEmptyStateDesignPreview(showsFirstActionPrompt: true)
                    } else if ProcessInfo.processInfo.arguments.contains("-home-empty-state-design-preview") {
                        HomeEmptyStateDesignPreview()
                    } else {
                        mainContent(container: container)
                    }
#else
                    mainContent(container: container)
#endif
                } else {
                    DataInitializationFailedView(
                        errorMessage: dataService.initializationErrorMessage,
                        onRetry: {
                            dataService.reloadContainer()
                        }
                    )
                    .environmentObject(authService)
                    .environmentObject(syncManager)
                }
            }
        }
    }

    private func mainContent(container: ModelContainer) -> some View {
        ContentView()
            // Inject the modelContext into the environment
            .modelContainer(container)
            .environmentObject(authService)
            .environmentObject(syncManager)
            .environmentObject(aiConsentManager)
            .onOpenURL { url in
                // Handle Google Sign-In URL
                if GIDSignIn.sharedInstance.handle(url) {
                    return
                }

                if url.scheme == "chillnote" && url.host == "record" {
                    NotificationCenter.default.post(name: NSNotification.Name("StartRecording"), object: nil)
                    return
                }

                if url.scheme == "chillnote" && url.host == "shared-imports" {
                    NotificationCenter.default.post(name: .sharedImportsRequested, object: nil)
                    return
                }
            }
    }
}

private struct DataInitializationFailedView: View {
    let errorMessage: String?
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(L10n.text("app_init.title"))
                .font(.title2)
                .fontWeight(.semibold)
            Text(L10n.text("app_init.message"))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            Button(L10n.text("app_init.retry"), action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
