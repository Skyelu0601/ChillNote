import XCTest
@testable import chillnote

final class RevenueCatIdentityTests: XCTestCase {
    func testUUIDUsesSameLowercaseIdentityAsBackend() {
        let lower = "c1a99945-082b-423f-bc09-eca9176b14f5"
        XCTAssertEqual(RevenueCatIdentity.canonicalUserID(lower.uppercased()), lower)
        XCTAssertEqual(RevenueCatIdentity.canonicalUserID(lower), lower)
    }

    func testDoesNotRewriteAnonymousOrOpaqueIDs() {
        for value in ["$RCAnonymousID:AbC", "CustomAccount", ""] {
            XCTAssertEqual(RevenueCatIdentity.canonicalUserID(value), value)
        }
    }
}
