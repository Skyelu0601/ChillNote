import SwiftUI
import SwiftData
import OSLog

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
    private static let logger = Logger(subsystem: "com.chillnote.app", category: "data")
    
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
                Tag.self,
                ChecklistItem.self
            ])
            
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

            // Ensure the Application Support directory exists before SwiftData opens the store.
            try FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)

            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            Self.logger.info("ModelContainer created successfully")
        } catch {
            Self.logger.error("Could not create ModelContainer: \(error.localizedDescription, privacy: .public)")
            initializationErrorMessage = error.localizedDescription
        }
    }
    
    /// Welcome Note seeding has been retired in favor of the first-user guide.
    /// Keep this no-op for compatibility with any older call sites.
    @discardableResult
    func seedDataIfNeeded(context: ModelContext? = nil, userId: String? = nil) -> Bool {
        false
    }
}
