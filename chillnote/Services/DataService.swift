import SwiftUI
import SwiftData

struct WelcomeNoteFlagStore {
    private static let globalKey = "hasSeededWelcomeNote"
    private static let perUserKey = "welcomeNoteSeededByUserId"
    
    static func hasSeenWelcome(for userId: String?) -> Bool {
        let defaults = UserDefaults.standard
        if let userId,
           let map = defaults.dictionary(forKey: perUserKey) as? [String: Bool],
           let value = map[userId] {
            return value
        }
        if userId != nil {
            return false
        } else {
            return defaults.bool(forKey: globalKey)
        }
    }
    
    static func setHasSeenWelcome(_ value: Bool, for userId: String?) {
        let defaults = UserDefaults.standard
        if let userId {
            var map = defaults.dictionary(forKey: perUserKey) as? [String: Bool] ?? [:]
            map[userId] = value
            defaults.set(map, forKey: perUserKey)
        }
        defaults.set(value, forKey: globalKey)
    }
    
    static func syncGlobalFlag(for userId: String?) {
        let value = hasSeenWelcome(for: userId)
        UserDefaults.standard.set(value, forKey: globalKey)
    }
}

@MainActor
class DataService: ObservableObject {
    static let shared = DataService()
    
    @Published private(set) var container: ModelContainer?
    @Published private(set) var initializationErrorMessage: String?
    
    private init() {
        reloadContainer()
    }

    func reloadContainer() {
        container = nil
        initializationErrorMessage = nil

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
            initializationErrorMessage = error.localizedDescription
        }
    }
    

    /// Seeds the database with a welcome note if empty (per-user)
    @discardableResult
    func seedDataIfNeeded(context: ModelContext? = nil, userId: String? = nil) -> Bool {
        let effectiveUserId = userId ?? AuthService.shared.currentUserId
        
        if WelcomeNoteFlagStore.hasSeenWelcome(for: effectiveUserId) {
            return false
        }
        
        guard let context = context ?? container?.mainContext else { return false }
        guard let userId = effectiveUserId else { return false }
        
        do {
            // Check if there are any existing notes for this user
            var existingNotesDescriptor = FetchDescriptor<Note>()
            existingNotesDescriptor.predicate = #Predicate<Note> { note in
                note.userId == userId
            }
            let noteCount = try context.fetchCount(existingNotesDescriptor)
            
            if noteCount > 0 {
                // If notes exist but flag wasn't set, set it now to prevent future seeding
                WelcomeNoteFlagStore.setHasSeenWelcome(true, for: effectiveUserId)
                return false
            }
            
            // Insert Welcome Note
            context.insert(Note(content: "Welcome to ChillNote! Tap the yellow button to record a voice note.", userId: userId))
            try? context.save()
            
            // Mark as seeded
            WelcomeNoteFlagStore.setHasSeenWelcome(true, for: effectiveUserId)
            return true
        } catch {
            print("Error checking seed data: \(error)")
            return false
        }
    }
}
