import XCTest
@testable import chillnote

final class PaywallContentTests: XCTestCase {
    private let englishLocale = Locale(identifier: "en_US_POSIX")

    func testAllContextsHaveCopyAndBenefits() {
        for context in [
            PaywallContext.recordingTimeLimit,
            .dailyVoiceLimit,
            .dailyTidyLimit,
            .dailyRecipeLimit,
            .dailyChatLimit,
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

    func testAnnualPlanWithFreeTrialBuildsTrialMessaging() {
        let info = SubscriptionDisplayInfo.build(
            price: 68,
            priceFormatStyle: .currency(code: "USD"),
            billingPeriod: SubscriptionPeriodDescriptor(unit: .year, value: 1),
            introductoryOffer: IntroductoryOfferDescriptor(
                paymentMode: .freeTrial,
                period: SubscriptionPeriodDescriptor(unit: .day, value: 7)
            ),
            locale: englishLocale
        )

        XCTAssertTrue(info.isAnnual)
        XCTAssertTrue(info.hasFreeTrial)
        XCTAssertEqual(info.trialDurationText, "7 days")
        XCTAssertEqual(info.badgeText, "7 DAYS FREE TRIAL")
        XCTAssertEqual(info.ctaText, "Start 7 days Free Trial")
        XCTAssertEqual(info.billingPeriodText, "per year")
        XCTAssertEqual(info.equivalentMonthlyText, "Equivalent to $5.67/month, billed yearly")
        XCTAssertEqual(info.renewalText, "Free for 7 days, then $68.00/year. Cancel anytime.")
    }

    func testMonthlyPlanDoesNotShowFreeTrialMessaging() {
        let info = SubscriptionDisplayInfo.build(
            price: 9.99,
            priceFormatStyle: .currency(code: "USD"),
            billingPeriod: SubscriptionPeriodDescriptor(unit: .month, value: 1),
            introductoryOffer: nil,
            locale: englishLocale
        )

        XCTAssertFalse(info.isAnnual)
        XCTAssertFalse(info.hasFreeTrial)
        XCTAssertEqual(info.badgeText, "FLEXIBLE")
        XCTAssertEqual(info.ctaText, "Start Monthly Plan")
        XCTAssertEqual(info.billingPeriodText, "per month")
        XCTAssertNil(info.equivalentMonthlyText)
        XCTAssertNil(info.renewalText)
    }

    func testAnnualPlanWithoutIntroOfferFallsBackToStandardMessaging() {
        let info = SubscriptionDisplayInfo.build(
            price: 68,
            priceFormatStyle: .currency(code: "USD"),
            billingPeriod: SubscriptionPeriodDescriptor(unit: .year, value: 1),
            introductoryOffer: nil,
            locale: englishLocale
        )

        XCTAssertTrue(info.isAnnual)
        XCTAssertFalse(info.hasFreeTrial)
        XCTAssertEqual(info.badgeText, "BEST VALUE")
        XCTAssertEqual(info.ctaText, "Start Annual Plan")
        XCTAssertEqual(info.billingPeriodText, "per year")
        XCTAssertEqual(info.equivalentMonthlyText, "Equivalent to $5.67/month, billed yearly")
        XCTAssertNil(info.renewalText)
    }
}
