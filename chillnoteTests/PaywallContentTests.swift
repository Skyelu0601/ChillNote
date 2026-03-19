import XCTest
@testable import chillnote

final class PaywallContentTests: XCTestCase {
    func testAllContextsHaveCopyAndBenefits() {
        for context in [
            PaywallContext.recordingTimeLimit,
            .dailyVoiceLimit,
            .dailyTidyLimit,
            .dailyRecipeLimit,
            .dailyChatLimit,
            .postOnboardingWelcome,
            .firstVoiceSuccess
        ] {
            let content = context.content
            XCTAssertFalse(content.titleKey.isEmpty)
            XCTAssertFalse(content.messageKey.isEmpty)
            XCTAssertFalse(content.primaryButtonKey.isEmpty)
            XCTAssertFalse(content.secondaryButtonKey.isEmpty)
            XCTAssertFalse(content.benefitKeys.isEmpty)
        }
    }
}
