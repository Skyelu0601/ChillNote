import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authService: AuthService
    
    // App Flow State
    // In a real app, these would probably check logic or Keychain on init
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("hasGuestAccess") private var hasGuestAccess = false
    var body: some View {
        Group {
            if !hasSeenOnboarding {
                OnboardingView(isCompleted: $hasSeenOnboarding)
            } else {
                if authService.isSignedIn || hasGuestAccess {
                    HomeView()
                } else {
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
