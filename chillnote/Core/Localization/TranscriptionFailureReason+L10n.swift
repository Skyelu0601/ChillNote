import Foundation

extension TranscriptionFailureReason {
    var pendingRecoveryMessage: String {
        L10n.text(pendingRecoveryMessageKey)
    }

    private var pendingRecoveryMessageKey: String {
        switch self {
        case .networkUnavailable:
            return "error.recording.pending.network"
        case .timeout:
            return "error.recording.pending.timeout"
        case .authenticationRequired:
            return "error.recording.pending.auth_required"
        case .serviceUnavailable:
            return "error.recording.pending.service_unavailable"
        case .serviceConfiguration:
            return "error.recording.pending.service_configuration"
        case .quotaReached:
            return "error.recording.pending.quota_reached"
        case .audioEmpty:
            return "error.recording.pending.audio_empty"
        case .localFileIssue:
            return "error.recording.pending.local_file"
        case .unknown:
            return "error.recording.pending.unknown"
        }
    }
}

enum TranscriptionContentValidator {
    private static let timestampOnlyRegex = try? NSRegularExpression(
        pattern: #"^(?:\[?\d{1,2}:\d{2}(?::\d{2})?\]?\s*)+$"#,
        options: []
    )

    static func normalizedTranscriptOrNil(_ rawText: String) -> String? {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !looksLikeProviderEmptyResponse(trimmed) else { return nil }
        guard !isTimestampOnlyTranscript(trimmed) else { return nil }
        return trimmed
    }

    static func fallbackEmptyTranscriptionMessage() -> String {
        String(localized: "Transcription result was empty. Please retry.")
    }

    static func looksLikeProviderEmptyResponse(_ text: String) -> Bool {
        let lowered = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lowered.isEmpty else { return true }

        let suspiciousMarkers = [
            "this transcript appears to be empty",
            "contains only timestamps",
            "provide actual speech content",
            "no clear speech",
            "no speech detected",
            "only timestamps"
        ]
        return suspiciousMarkers.contains { lowered.contains($0) }
    }

    private static func isTimestampOnlyTranscript(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
        var sawTimestampLine = false

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            if isTimestampOnlyLine(line) {
                sawTimestampLine = true
                continue
            }
            return false
        }

        return sawTimestampLine
    }

    private static func isTimestampOnlyLine(_ line: String) -> Bool {
        guard let timestampOnlyRegex else { return false }
        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        return timestampOnlyRegex.firstMatch(in: line, options: [], range: nsRange) != nil
    }
}

enum VoiceErrorPresentation {
    static var transcriptionFailedTitle: String {
        String(localized: "Transcription Failed")
    }

    static func userMessage(for rawMessage: String) -> String {
        let trimmed = rawMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return L10n.text("error.recording.pending.unknown")
        }

        let lowered = trimmed.lowercased()

        if lowered.contains("microphone permission required")
            || lowered.contains("no microphone available")
            || (lowered.contains("permission") && lowered.contains("microphone"))
            || (lowered.contains("microphone") && lowered.contains("denied")) {
            return String(localized: "Microphone and Speech access are required.")
        }

        if lowered.contains("network error") || lowered.contains("network unavailable") || lowered.contains("offline") {
            return L10n.text("error.recording.pending.network")
        }
        if lowered.contains("timed out") || lowered.contains("timeout") || lowered.contains("504") {
            return L10n.text("error.recording.pending.timeout")
        }
        if lowered.contains("sign in required")
            || lowered.contains("missing token")
            || lowered.contains("invalid token")
            || lowered.contains("unauthorized")
            || lowered.contains("session expired")
            || lowered.contains("auth") {
            return L10n.text("error.recording.pending.auth_required")
        }
        if lowered.contains("daily free voice limit reached")
            || lowered.contains("daily voice limit reached")
            || lowered.contains("too many requests")
            || lowered.contains("rate limit")
            || lowered.contains("quota")
            || lowered.contains("429") {
            return L10n.text("error.recording.pending.quota_reached")
        }
        if lowered.contains("service key")
            || lowered.contains("api key")
            || lowered.contains("not configured")
            || lowered.contains("invalid configuration")
            || lowered.contains("invalid configuration url") {
            return L10n.text("error.recording.pending.service_configuration")
        }
        if lowered.contains("provider error")
            || lowered.contains("internal server error")
            || lowered.contains("invalid response from chillo")
            || lowered.contains("service unavailable")
            || lowered.contains("service error")
            || lowered.contains("status code: 5")
            || lowered.contains("500")
            || lowered.contains("502")
            || lowered.contains("503") {
            return L10n.text("error.recording.pending.service_unavailable")
        }
        if lowered.contains("could not read audio file")
            || lowered.contains("unable to read the recording file")
            || lowered.contains("local file") {
            return L10n.text("error.recording.pending.local_file")
        }
        if lowered.contains("no audio captured")
            || lowered.contains("audio empty")
            || lowered.contains("transcription result was empty")
            || TranscriptionContentValidator.looksLikeProviderEmptyResponse(lowered) {
            return L10n.text("error.recording.pending.audio_empty")
        }
        if lowered.contains("transcription failed") {
            return L10n.text("error.recording.pending.unknown")
        }

        return trimmed
    }
}
