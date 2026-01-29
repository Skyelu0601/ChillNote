import Foundation

struct AppConfig {
    static let backendBaseURL: String = {
        if let env = ProcessInfo.processInfo.environment["BACKEND_BASE_URL"], !env.isEmpty {
            return env
        }
        return "https://api.chillnoteai.com"
    }()
    
    // Supabase Configuration
    static let supabaseURL = URL(string: "https://qsyhkpaeyzhjojdvbntq.supabase.co")!
    // TODO: Replace with your actual Anon Key from Supabase Dashboard -> Settings -> API
    static let supabaseAnonKey = "sb_publishable_smWWadjejdbKYvmg3fidsg_41XPu70e" 
    
    static var isAIEnabled: Bool {
        return !backendBaseURL.isEmpty
    }
}
