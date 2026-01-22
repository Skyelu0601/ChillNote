import SwiftUI
import SwiftData

@MainActor
class DataService {
    static let shared = DataService()
    
    var container: ModelContainer?
    
    private init() {
        do {
            let schema = Schema([
                Note.self,
                Tag.self,
                CustomAIAction.self
            ])
            
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            
            // Try to create container with migration support
            do {
                container = try ModelContainer(for: schema, configurations: [modelConfiguration])
                print("✅ ModelContainer created successfully")
            } catch {
                // If migration fails, try to delete and recreate the store
                print("⚠️ Migration failed, attempting to reset database...")
                print("⚠️ Error: \(error)")
                
                // Get the default store URL
                let storeURL = URL.applicationSupportDirectory.appending(path: "default.store")
                
                // Delete old store files
                try? FileManager.default.removeItem(at: storeURL)
                try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
                try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
                
                print("🗑️ Old database deleted")
                
                // Create fresh container
                container = try ModelContainer(for: schema, configurations: [modelConfiguration])
                print("✅ Fresh ModelContainer created")
            }
        } catch {
            print("CRITICAL ERROR: Could not create ModelContainer: \(error)")
        }
    }
    
    /// Seeds the database with a welcome note if empty
    func seedDataIfNeeded() {
        guard let container = container else { return }
        let context = container.mainContext
        
        do {

            
            // Seed welcome note if needed
            let existingNotes = try context.fetch(FetchDescriptor<Note>())
            if !existingNotes.isEmpty { return }
            
            let welcomeNote = Note(content: "Welcome to ChillNote! Tap the yellow button to record a voice note.")
            // Use a fixed UUID and old timestamp so that if the user has deleted/modified this note
            // on the server, the server version (which is newer) will override this default one
            // during sync, preventing duplicate or zombie welcome notes.
            welcomeNote.id = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
            welcomeNote.createdAt = Date.distantPast
            welcomeNote.updatedAt = Date.distantPast
            
            context.insert(welcomeNote)
            try? context.save()
        } catch {
            print("Error checking seed data: \(error)")
        }
    }
}
