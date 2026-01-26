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
                Tag.self
            ])
            
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

            // Ensure the Application Support directory exists to prevent Core Data errors
            try? FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
            
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
        // Check if we have already seeded the welcome note to prevent duplicates
        // This solves the issue where the note reappears after invalidation or sync delays
        let hasSeededKey = "hasSeededWelcomeNote"
        if UserDefaults.standard.bool(forKey: hasSeededKey) {
            return
        }
        
        guard let container = container else { return }
        let context = container.mainContext
        
        do {
            // Check if there are any existing notes
            let existingNotesDescriptor = FetchDescriptor<Note>()
            let noteCount = try context.fetchCount(existingNotesDescriptor)
            
            if noteCount > 0 {
                // If notes exist but flag wasn't set, set it now to prevent future seeding
                UserDefaults.standard.set(true, forKey: hasSeededKey)
                return
            }
            
            // Insert Welcome Note
            context.insert(Note(content: "Welcome to ChillNote! Tap the yellow button to record a voice note."))
            try? context.save()
            
            // Mark as seeded
            UserDefaults.standard.set(true, forKey: hasSeededKey)
            
        } catch {
            print("Error checking seed data: \(error)")
        }
    }
}
