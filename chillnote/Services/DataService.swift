import SwiftUI
import SwiftData

@MainActor
class DataService {
    static let shared = DataService()
    
    var container: ModelContainer?
    
    private init() {
        do {
            let schema = Schema([
                Note.self
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("CRITICAL ERROR: Could not create ModelContainer: \(error)")
        }
    }
    
    /// Seeds the database with a welcome note if empty
    func seedDataIfNeeded() {
        guard let container = container else { return }
        let context = container.mainContext
        
        do {
            let existingNotes = try context.fetch(FetchDescriptor<Note>())
            if !existingNotes.isEmpty { return }
            context.insert(Note(content: "Welcome to ChillNote! Tap the yellow button to record a voice note."))
            try? context.save()
        } catch {
            print("Error checking seed data: \(error)")
        }
    }
}
