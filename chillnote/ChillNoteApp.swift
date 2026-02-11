import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct ChillNoteApp: App {
    @StateObject private var authService = AuthService.shared
    @StateObject private var syncManager = SyncManager()
    @StateObject private var dataService = DataService.shared

    
    init() {
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
                    ContentView()
                        // Inject the modelContext into the environment
                        .modelContainer(container)
                        .environmentObject(authService)
                        .environmentObject(syncManager)

                        .onOpenURL { url in
                            // Handle Google Sign-In URL
                            if GIDSignIn.sharedInstance.handle(url) {
                                return
                            }
                            
                            if url.scheme == "chillnote" && url.host == "record" {
                                NotificationCenter.default.post(name: NSNotification.Name("StartRecording"), object: nil)
                            }
                        }
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
}

private struct DataInitializationFailedView: View {
    let errorMessage: String?
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Couldn't Start ChillNote")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Local data initialization failed. Please try again. If it still fails, restart the app or free up device storage and try again.")
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
            Button("Retry Initialization", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
