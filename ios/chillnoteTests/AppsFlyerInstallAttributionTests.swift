import XCTest
@testable import chillnote

final class AppsFlyerInstallAttributionTests: XCTestCase {
    func testMapsAppsFlyerCampaignFieldsForRevenueCat() {
        let attribution = AppsFlyerInstallAttribution(conversionData: [
            "media_source": "tiktokglobal_int",
            "campaign": "spark_launch",
            "af_adset": "creator_a",
            "af_ad": "video_01"
        ])

        XCTAssertEqual(attribution.mediaSource, "tiktokglobal_int")
        XCTAssertEqual(attribution.campaign, "spark_launch")
        XCTAssertEqual(attribution.adGroup, "creator_a")
        XCTAssertEqual(attribution.ad, "video_01")
    }

    func testIgnoresMissingAndEmptyCampaignFields() {
        let attribution = AppsFlyerInstallAttribution(conversionData: [
            "media_source": "  "
        ])

        XCTAssertNil(attribution.mediaSource)
        XCTAssertNil(attribution.campaign)
        XCTAssertNil(attribution.adGroup)
        XCTAssertNil(attribution.ad)
    }
}
