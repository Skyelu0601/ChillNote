import XCTest
@testable import chillnote

final class AppRatingPromptPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    func testFirstSuccessfulEventRequestsImmediately() {
        XCTAssertTrue(
            AppRatingPromptPolicy.shouldRequest(
                successfulEventCount: 1,
                attemptDates: [],
                lastAttemptEventCount: 0,
                now: now
            )
        )
    }

    func testRetryRequiresThirtyDaysAndThreeAdditionalEvents() {
        let previousAttempt = now.addingTimeInterval(-AppRatingPromptPolicy.repeatInterval)

        XCTAssertFalse(
            AppRatingPromptPolicy.shouldRequest(
                successfulEventCount: 3,
                attemptDates: [previousAttempt],
                lastAttemptEventCount: 1,
                now: now
            )
        )
        XCTAssertTrue(
            AppRatingPromptPolicy.shouldRequest(
                successfulEventCount: 4,
                attemptDates: [previousAttempt],
                lastAttemptEventCount: 1,
                now: now
            )
        )
    }

    func testRetryDoesNotRequestBeforeThirtyDays() {
        XCTAssertFalse(
            AppRatingPromptPolicy.shouldRequest(
                successfulEventCount: 10,
                attemptDates: [now.addingTimeInterval(-AppRatingPromptPolicy.repeatInterval + 1)],
                lastAttemptEventCount: 1,
                now: now
            )
        )
    }

    func testStopsAfterThreeAttemptsInWindow() {
        let dates = [30.0, 60.0, 90.0].map {
            now.addingTimeInterval(-$0 * 24 * 60 * 60)
        }

        XCTAssertFalse(
            AppRatingPromptPolicy.shouldRequest(
                successfulEventCount: 20,
                attemptDates: dates,
                lastAttemptEventCount: 10,
                now: now
            )
        )
    }
}
