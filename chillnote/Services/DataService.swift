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
                Category.self
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
            // Initialize preset categories if needed
            let existingCategories = try context.fetch(FetchDescriptor<Category>())
            if existingCategories.isEmpty {
                let presetCategories = Category.createPresets()
                for category in presetCategories {
                    context.insert(category)
                }
                print("✅ Initialized \(presetCategories.count) preset categories")
            }
            
            // Seed welcome note if needed
            let existingNotes = try context.fetch(FetchDescriptor<Note>())
            if !existingNotes.isEmpty { return }
            context.insert(Note(content: "Welcome to ChillNote! Tap the yellow button to record a voice note."))
            try? context.save()
        } catch {
            print("Error checking seed data: \(error)")
        }
    }
}
