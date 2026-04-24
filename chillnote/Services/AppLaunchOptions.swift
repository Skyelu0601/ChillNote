import Foundation

enum AppLaunchOptions {
    private static let arguments = ProcessInfo.processInfo.arguments
    private static let environment = ProcessInfo.processInfo.environment

    static var isOnboardingScreenshotMode: Bool {
        arguments.contains("-OnboardingScreenshotMode")
    }

    static var onboardingScreenshotPage: Int {
        guard let rawValue = environment["CHILLNOTE_SCREENSHOT_PAGE"],
              let page = Int(rawValue) else {
            return 0
        }

        return max(0, page)
    }
}
