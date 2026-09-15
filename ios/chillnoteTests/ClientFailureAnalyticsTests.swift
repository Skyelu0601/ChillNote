import XCTest
import GoogleSignIn
@testable import chillnote

final class ClientFailureAnalyticsTests: XCTestCase {
    func testAISeparatesConsentCreditsRateLimitsNetworkAndServerFailures() {
        let cases: [(Error, String, String)] = [
            (GeminiError.consentDeclined, "blocked", "ai_consent_required"),
            (GeminiError.insufficientCredits, "blocked", "insufficient_credits"),
            (GeminiError.rateLimited, "blocked", "rate_limited"),
            (GeminiError.authenticationRequired, "blocked", "authentication_required"),
            (GeminiError.httpError(403), "blocked", "access_denied"),
            (GeminiError.httpError(502), "failed", "server_error"),
            (GeminiError.invalidResponse, "failed", "invalid_response"),
            (GeminiError.networkError(URLError(.timedOut)), "failed", "network_timeout"),
            (GeminiError.networkError(URLError(.cancelled)), "cancelled", "request_cancelled"),
            (CancellationError(), "cancelled", "request_cancelled")
        ]
        for (error, outcome, code) in cases {
            let failure = ClientFailureAnalytics.ai(error)
            XCTAssertEqual(failure.outcome, outcome)
            XCTAssertEqual(failure.code, code)
        }
        XCTAssertEqual(ClientFailureAnalytics.ai(GeminiError.httpError(502)).httpStatus, 502)
    }

    func testGoogleCancellationRequiresProviderStageAndCorrectDomain() {
        let error = NSError(domain: kGIDSignInErrorDomain, code: -5)
        XCTAssertEqual(ClientFailureAnalytics.login(error, stage: "provider").outcome, "cancelled")
        XCTAssertEqual(ClientFailureAnalytics.login(error, stage: "token_exchange").outcome, "failed")
        XCTAssertEqual(ClientFailureAnalytics.login(NSError(domain: "another", code: -5), stage: "provider").outcome, "failed")
        XCTAssertEqual(ClientFailureAnalytics.login(CancellationError(), stage: "token_exchange").code, "request_cancelled")
    }

    func testDiagnosticsDoNotContainErrorMessagesOrArbitraryDomains() {
        let secret = "private note and access_token"
        let error = NSError(domain: secret, code: 123, userInfo: [NSLocalizedDescriptionKey: secret])
        let properties = ClientFailureAnalytics.login(error, stage: "token_exchange").properties
        XCTAssertFalse(String(describing: properties).contains(secret))
        XCTAssertEqual(properties["sdk_error_domain"] as? String, "other")
        XCTAssertFalse(String(describing: ClientFailureAnalytics.ai(GeminiError.apiError(secret)).properties).contains(secret))
    }
}
