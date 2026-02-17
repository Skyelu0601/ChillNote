import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authService: AuthService
    
    // App Flow State
    // In a real app, these would probably check logic or Keychain on init
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    var body: some View {
        Group {
            if !hasSeenOnboarding {
                OnboardingView(isCompleted: $hasSeenOnboarding)
            } else {
                switch authService.state {
                case .checking:
                    if authService.canOptimisticallyEnterHome {
                        HomeView()
                    } else {
                        ProgressView("Checking session...")
                    }
                case .signedIn:
                    HomeView()
                case .signedOut:
                    LoginView()
                case .signingIn:
                    LoginView()
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(DataService.shared.container!)
        .environmentObject(AuthService.shared)
}
