import SwiftUI
import SwiftData

@main
struct ChillNoteApp: App {
    // We use the container created by our DataService to ensure the same DB instance
    // is used for both seeding and the UI.
    let container: ModelContainer
    @StateObject private var authService = AuthService.shared
    @StateObject private var syncManager = SyncManager()
    @StateObject private var actionsManager = AIActionsManager.shared
    
    init() {
        guard let dataContainer = DataService.shared.container else {
            fatalError("Failed to initialize ModelContainer from DataService")
        }
        self.container = dataContainer
        
        // Ensure data is seeded on launch
        Task { @MainActor in
            DataService.shared.seedDataIfNeeded()
            
            // Initialize AIActionsManager with model context
            if let context = DataService.shared.container?.mainContext {
                AIActionsManager.shared.initialize(context: context)
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Inject the modelContext into the environment
                .modelContainer(container)
                .environmentObject(authService)
                .environmentObject(syncManager)
                .environmentObject(actionsManager)
        }
    }
}
