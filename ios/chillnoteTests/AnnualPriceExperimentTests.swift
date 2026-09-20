import Testing
@testable import chillnote

struct AnnualPriceExperimentTests {
    @Test func assignmentIsStableAndCaseInsensitive() {
        let userID = "A3B9CB58-0B4C-43DA-9BE2-2F18AA6743EA"

        #expect(AnnualPriceExperiment.variant(for: userID) == AnnualPriceExperiment.variant(for: userID))
        #expect(AnnualPriceExperiment.variant(for: userID) == AnnualPriceExperiment.variant(for: userID.lowercased()))
    }

    @Test func knownAssignmentsMatchAndroid() {
        #expect(AnnualPriceExperiment.variant(for: "user-0") == .annual4999)
        #expect(AnnualPriceExperiment.variant(for: "user-2") == .annual5999)
    }

    @Test func eachVariantUsesOnlyItsOwnAnnualProductAndOffering() {
        #expect(AnnualPriceExperiment.annual4999.offeringIdentifier == "post_login_two_page_trial_4999")
        #expect(AnnualPriceExperiment.annual4999.allowedProductIdentifiers == [
            "com.chillnote.pro.weekly",
            "com.chillnote.pro.yearly49"
        ])
        #expect(AnnualPriceExperiment.annual5999.offeringIdentifier == "post_login_two_page_trial_5999")
        #expect(AnnualPriceExperiment.annual5999.allowedProductIdentifiers == [
            "com.chillnote.pro.weekly",
            "com.chillnote.pro.yearly"
        ])
    }

    @Test func revenueCatIdentityMatchingIsCanonicalAndRejectsDifferentUsers() {
        let uppercase = "A3B9CB58-0B4C-43DA-9BE2-2F18AA6743EA"
        let lowercase = uppercase.lowercased()

        #expect(RevenueCatIdentity.matches(uppercase, lowercase))
        #expect(!RevenueCatIdentity.matches(uppercase, "user-2"))
        #expect(!RevenueCatIdentity.matches(nil, lowercase))
    }
}
