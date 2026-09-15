import Foundation
import GoogleSignIn

/// Only bounded codes and numeric diagnostics belong in analytics. Never include
/// localizedDescription, response bodies, tokens, prompts, or note content.
struct ClientFailureAnalytics {
    let outcome: String
    let code: String
    let category: String
    var stage: String = "request"
    var httpStatus: Int?
    var sdkCode: Int?
    var sdkDomain: String?

    var properties: [String: Any] {
        var result: [String: Any] = [
            "diagnostic_schema": 2, "error_code": code,
            "error_category": category, "error_stage": stage
        ]
        if let httpStatus { result["http_status"] = httpStatus }
        if let sdkCode { result["sdk_error_code"] = sdkCode }
        if let sdkDomain { result["sdk_error_domain"] = sdkDomain }
        return result
    }

    static func ai(_ error: Error) -> Self {
        if isCancellation(error) {
            return Self(outcome: "cancelled", code: "request_cancelled", category: "cancelled")
        }
        if let error = error as? GeminiError {
            switch error {
            case .consentDeclined:
                return Self(outcome: "blocked", code: "ai_consent_required", category: "consent", stage: "consent")
            case .insufficientCredits: return http(402)
            case .rateLimited: return http(429)
            case .authenticationRequired:
                return Self(outcome: "blocked", code: "authentication_required", category: "authentication", stage: "session")
            case .httpError(let status): return http(status)
            case .networkError(let underlying): return ai(underlying)
            case .invalidResponse:
                return Self(outcome: "failed", code: "invalid_response", category: "response", stage: "response")
            case .missingAPIKey, .invalidURL:
                return Self(outcome: "failed", code: "invalid_configuration", category: "configuration", stage: "configuration")
            case .apiError:
                return Self(outcome: "failed", code: "api_error", category: "api")
            }
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return Self(outcome: "failed", code: nsError.code == NSURLErrorTimedOut ? "network_timeout" : "network_error",
                        category: "network", sdkCode: nsError.code, sdkDomain: NSURLErrorDomain)
        }
        return Self(outcome: "failed", code: "unknown_error", category: "unknown")
    }

    static func http(_ status: Int) -> Self {
        switch status {
        case 402:
            return Self(outcome: "blocked", code: "insufficient_credits", category: "credits", httpStatus: status)
        case 429:
            return Self(outcome: "blocked", code: "rate_limited", category: "rate_limit", httpStatus: status)
        case 401:
            return Self(outcome: "blocked", code: "authentication_required", category: "authentication", httpStatus: status)
        case 403:
            return Self(outcome: "blocked", code: "access_denied", category: "authorization", httpStatus: status)
        default:
            return Self(outcome: "failed", code: status >= 500 ? "server_error" : "http_error",
                        category: "http", httpStatus: status)
        }
    }

    static func login(_ error: Error, stage: String) -> Self {
        let nsError = error as NSError
        if stage == "provider" && nsError.domain == kGIDSignInErrorDomain
            && nsError.code == GIDSignInError.canceled.rawValue {
            return Self(outcome: "cancelled", code: "user_cancelled", category: "cancelled", stage: stage)
        }
        if isCancellation(error) {
            return Self(outcome: "cancelled", code: "request_cancelled", category: "cancelled", stage: stage)
        }
        let domain = [kGIDSignInErrorDomain, NSURLErrorDomain].contains(nsError.domain) ? nsError.domain : "other"
        return Self(outcome: "failed", code: stage == "provider" ? "provider_error" : "token_exchange_error",
                    category: nsError.domain == NSURLErrorDomain ? "network" : "authentication",
                    stage: stage, sdkCode: nsError.code, sdkDomain: domain)
    }

    private static func isCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        return error is CancellationError || (nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled)
    }
}
