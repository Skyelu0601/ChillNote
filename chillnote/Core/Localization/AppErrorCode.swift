import Foundation

enum AppErrorCode: String {
    case authAppleInitFailed = "error.auth.apple_init_failed"
    case authInvalidAppleCredential = "error.auth.invalid_apple_credential"
    case authRootViewControllerMissing = "error.auth.root_view_controller_missing"
    case authGoogleTokenMissing = "error.auth.google_token_missing"

    case syncDisabled = "error.sync.disabled"
    case syncSignInRequired = "error.sync.sign_in_required"
    case syncServerURLRequired = "error.sync.server_url_required"
    case syncUnavailable = "error.sync.unavailable"
    case syncSessionExpired = "error.sync.session_expired"
    case syncAuthorizationFailed = "error.sync.authorization_failed"
    case syncFailedWithReason = "error.sync.failed_with_reason"

    case geminiServiceKeyMissing = "error.gemini.service_key_missing"
    case geminiInvalidConfiguration = "error.gemini.invalid_configuration"
    case geminiNetworkError = "error.gemini.network_error"
    case geminiServiceError = "error.gemini.service_error"
    case geminiInvalidResponse = "error.gemini.invalid_response"
    case geminiSignInRequired = "error.gemini.sign_in_required"

    case recordingPermissionNeeded = "error.recording.permission_needed"
    case recordingNetworkUnavailable = "error.recording.network_unavailable"
    case recordingTimeout = "error.recording.timeout"
    case recordingFailed = "error.recording.failed"
    case recordingStateReady = "recording.state.ready"
    case recordingStateProcessing = "recording.state.processing"
    case recordingStateError = "recording.state.error"
    case recordingLimitReached = "recording.limit.reached"
    case recordingDailyLimitReached = "recording.limit.daily_reached"

    var message: String {
        L10n.text(rawValue)
    }

    func message(_ args: CVarArg...) -> String {
        let format = L10n.text(rawValue)
        return withVaList(args) { pointer in
            NSString(format: format, locale: Locale.current, arguments: pointer) as String
        }
    }
}
