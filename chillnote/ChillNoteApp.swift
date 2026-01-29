import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct ChillNoteApp: App {
    // We use the container created by our DataService to ensure the same DB instance
    // is used for both seeding and the UI.
    let container: ModelContainer
    @StateObject private var authService = AuthService.shared
    @StateObject private var syncManager = SyncManager()

    
    init() {
        guard let dataContainer = DataService.shared.container else {
            fatalError("Failed to initialize ModelContainer from DataService")
        }
        self.container = dataContainer
        
        // Ensure data is seeded on launch
        Task { @MainActor in
            // Clean up old recording files (>24 hours)
            RecordingFileManager.shared.cleanupOldRecordings()
        }
    }
    
    var body: some Scene {
        WindowGroup {
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
        }
    }
}
