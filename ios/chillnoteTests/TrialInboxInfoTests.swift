import XCTest
@testable import chillnote

final class TrialInboxInfoTests: XCTestCase {
    func testOlderResponsesAndUnknownFieldsRemainCompatible() throws {
        let data = Data(#"{"id":"item","kind":"welcome_pro","createdAt":"2026-10-10T12:00:00Z","futureField":true}"#.utf8)
        let item = try JSONDecoder().decode(InboxNotification.self, from: data)
        XCTAssertTrue(item.isSupported)
        XCTAssertNil(item.trial)
        XCTAssertNil(item.readAt)
    }

    func testCancellationKeepsTheTrialEndAndReadState() throws {
        let data = Data(#"{"id":"item","kind":"welcome_pro","createdAt":"2026-10-10T12:00:00Z","readAt":"2026-10-11T12:00:00Z","trial":{"expiresAt":"2026-10-17T12:00:00.000Z","autoRenew":false,"reminderStatus":"cancelled","manageSubscriptionURL":"https://play.google.com/store/account/subscriptions"}}"#.utf8)
        let item = try JSONDecoder().decode(InboxNotification.self, from: data)
        XCTAssertEqual(item.trial?.endDate, ISO8601DateFormatter().date(from: "2026-10-17T12:00:00Z"))
        XCTAssertEqual(item.trial?.autoRenew, false)
        XCTAssertNotNil(item.readAt)
        XCTAssertNotNil(item.trial?.subscriptionURL)
    }

    func testMalformedDatesAndUntrustedSubscriptionLinksFailSafely() {
        for raw in ["http://play.google.com/store/account/subscriptions",
                    "https://play.google.com.evil.test/store/account/subscriptions", "https://example.com",
                    "https://user@play.google.com/store/account/subscriptions", "https://apps.apple.com/account/billing"] {
            let trial = TrialInboxInfo(expiresAt: "invalid", autoRenew: true, reminderStatus: "future_status",
                                      reminderAt: "invalid", maskedEmail: nil, manageSubscriptionURL: raw)
            XCTAssertNil(trial.endDate)
            XCTAssertNil(trial.reminderDate)
            XCTAssertNil(trial.subscriptionURL)
        }
        let apple = TrialInboxInfo(expiresAt: "2026-10-17T12:00:00Z", autoRenew: true, reminderStatus: "scheduled",
                                  reminderAt: nil, maskedEmail: nil, manageSubscriptionURL: "https://apps.apple.com/account/subscriptions")
        XCTAssertNotNil(apple.subscriptionURL)
    }
}
