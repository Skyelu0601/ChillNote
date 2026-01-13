import Foundation

struct AppConfig {
    // Prefer runtime configuration for device debugging, fallback to localhost for simulator.
    static let backendBaseURL: String = {
        if let env = ProcessInfo.processInfo.environment["BACKEND_BASE_URL"],
           !env.isEmpty {
            return env
        }
        if let plist = Bundle.main.object(forInfoDictionaryKey: "BACKEND_BASE_URL") as? String,
           !plist.isEmpty {
            return plist
        }
        return "https://api.chillnoteai.com"
    }()
    
    // All AI features are now handled through the backend proxy
    // No need for client-side API keys
    
    // Check if AI features are available by testing backend connectivity
    static var isAIEnabled: Bool {
        // In production, you might want to cache this or check asynchronously
        // For now, we assume if backend is configured, AI is available
        return !backendBaseURL.isEmpty
    }
}
