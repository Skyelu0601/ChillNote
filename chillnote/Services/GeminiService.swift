import Foundation
import NaturalLanguage
import OSLog

enum GeminiError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case networkError(Error)
    case apiError(String)
    case invalidResponse
    case consentDeclined
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return AppErrorCode.geminiServiceKeyMissing.message
        case .invalidURL:
            return AppErrorCode.geminiInvalidConfiguration.message
        case .networkError(let error):
            return AppErrorCode.geminiNetworkError.message(error.localizedDescription)
        case .apiError(let message):
            return AppErrorCode.geminiServiceError.message(message)
        case .invalidResponse:
            return AppErrorCode.geminiInvalidResponse.message
        case .consentDeclined:
            return L10n.text("speech_recognizer.error.ai_permission_not_granted")
        }
    }
}

enum VoiceTranscriptionLanguageMode: String, CaseIterable {
    case auto
    case prefer
}

struct VoiceTranscriptionPreferences {
    static let modeStorageKey = "voice_language_mode"
    static let hintStorageKey = "voice_language_hint"

    let mode: VoiceTranscriptionLanguageMode
    let preferredLanguageHint: String?

    static func load(from userDefaults: UserDefaults = .standard) -> VoiceTranscriptionPreferences {
        let rawMode = userDefaults.string(forKey: modeStorageKey) ?? VoiceTranscriptionLanguageMode.auto.rawValue
        let mode = VoiceTranscriptionLanguageMode(rawValue: rawMode) ?? .auto

        let rawHint = userDefaults.string(forKey: hintStorageKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let hint = (rawHint?.isEmpty == false) ? rawHint : nil

        return VoiceTranscriptionPreferences(mode: mode, preferredLanguageHint: hint)
    }
}

struct MediaLinkTranscriptionResult: Decodable {
    let available: Bool
    let text: String?
    let reason: String?
}

struct GeminiService {
    static let shared = GeminiService()
    private static let logger = Logger(subsystem: "com.chillnote.app", category: "gemini")

    private static func mediaMimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "heic":
            return "image/heic"
        case "webp":
            return "image/webp"
        case "wav":
            return "audio/wav"
        case "m4a":
            return "audio/m4a"
        case "mp3":
            return "audio/mp3"
        case "aac":
            return "audio/aac"
        case "aiff", "aif":
            return "audio/aiff"
        case "flac":
            return "audio/flac"
        case "mp4":
            return "video/mp4"
        case "mov":
            return "video/quicktime"
        case "m4v":
            return "video/x-m4v"
        default:
            return "application/octet-stream"
        }
    }

    private func makeAuthorizedJSONRequest(url: URL, timeout: TimeInterval) async throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout

        guard let token = await AuthService.shared.getSessionToken(), !token.isEmpty else {
            throw GeminiError.apiError(AppErrorCode.geminiSignInRequired.message)
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    /// Generates content from prompt and optional media (Multimodal)
    /// - Parameters:
    ///   - prompt: The text prompt
    ///   - audioFileURL: Optional URL to an audio file. The file will be read and sent as inline base64 data.
    ///   - systemInstruction: Optional system instruction (system prompt)
    ///   - jsonMode: If true, requests JSON output
    /// - Returns: Generated text content
    func generateContent(
        prompt: String,
        audioFileURL: URL? = nil,
        imageFileURL: URL? = nil,
        systemInstruction: String? = nil,
        jsonMode: Bool = false,
        countUsage: Bool = false,
        usageType: DailyQuotaFeature? = nil
    ) async throws -> String {
        let hasConsent = await AIConsentManager.shared.ensureConsentIfNeeded(for: .text)
        guard hasConsent else {
            throw GeminiError.consentDeclined
        }

        _ = countUsage // Reserved for backward compatibility at call sites.
        let serverURL = AppConfig.backendBaseURL + "/ai/gemini"
        guard let url = URL(string: serverURL) else {
            throw GeminiError.invalidURL
        }
        
        var request = try await makeAuthorizedJSONRequest(url: url, timeout: 60)
        
        // Build payload for backend proxy
        var requestBody: [String: Any] = [
            "prompt": prompt,
            "jsonMode": jsonMode
        ]
        
        if let systemInstruction = systemInstruction {
            requestBody["systemPrompt"] = systemInstruction
        }
        if let usageType {
            requestBody["usageType"] = usageType.rawValue
        }
        
        // Add media if present
        if let audioURL = audioFileURL {
            let audioData = try Data(contentsOf: audioURL)
            let base64Audio = audioData.base64EncodedString()
            let mimeType = Self.mediaMimeType(for: audioURL)
            
            requestBody["audioBase64"] = base64Audio
            requestBody["mimeType"] = mimeType
        }

        if let imageURL = imageFileURL {
            let imageData = try Data(contentsOf: imageURL)
            requestBody["imageBase64"] = imageData.base64EncodedString()
            requestBody["imageMimeType"] = Self.mediaMimeType(for: imageURL)
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        Self.logger.debug("Sending generateContent request to \(serverURL, privacy: .private)")
        // Execute Request
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            Self.logger.debug("Received generateContent response")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GeminiError.invalidResponse
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                // Fast-path: credits exhausted (402) or rate-limited (429).
                if httpResponse.statusCode == 402 || httpResponse.statusCode == 429 {
                    throw GeminiError.apiError("Insufficient credits")
                }
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let message = errorJson["error"] as? String {
                        throw GeminiError.apiError(message)
                    }
                    if let errorDict = errorJson["error"] as? [String: Any],
                       let message = errorDict["message"] as? String {
                        throw GeminiError.apiError(message)
                    }
                    if let message = errorJson["message"] as? String {
                        throw GeminiError.apiError(message)
                    }
                }
                throw GeminiError.apiError("Status code: \(httpResponse.statusCode)")
            }

            // Parse response from our backend (it returns { "content": "..." })
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = json["content"] as? String {
                return content
            }
            
            throw GeminiError.invalidResponse
            
        } catch let error as GeminiError {
            throw error
        } catch {
            throw GeminiError.networkError(error)
        }
    }

    /// Voice note: STT only (no intent optimization, no rewriting).
    func transcribeAudio(
        audioFileURL: URL,
        countUsage: Bool = true
    ) async throws -> String {
        let hasConsent = await AIConsentManager.shared.ensureConsentIfNeeded(for: .audio)
        guard hasConsent else {
            throw GeminiError.consentDeclined
        }

        let serverURL = AppConfig.backendBaseURL + "/ai/voice-note"
        guard let url = URL(string: serverURL) else {
            throw GeminiError.invalidURL
        }

        // Upload + model latency can exceed 60s for longer recordings.
        var request = try await makeAuthorizedJSONRequest(url: url, timeout: 180)

        guard let audioData = try? Data(contentsOf: audioFileURL) else {
            throw GeminiError.invalidResponse
        }

        let base64Audio = audioData.base64EncodedString()
        let mimeType = Self.mediaMimeType(for: audioFileURL)
        let transcriptionPreferences = VoiceTranscriptionPreferences.load()

        var requestBody: [String: Any] = [
            "audioBase64": base64Audio,
            "mimeType": mimeType,
            "spokenLanguageMode": transcriptionPreferences.mode.rawValue,
            "countUsage": countUsage
        ]
        if let preferredLanguageHint = transcriptionPreferences.preferredLanguageHint {
            requestBody["spokenLanguageHint"] = preferredLanguageHint
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        Self.logger.debug("Sending transcribeAudio request to \(serverURL, privacy: .private)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GeminiError.invalidResponse
            }

            // Backward-compat: older backends don't have /ai/voice-note yet.
            if httpResponse.statusCode == 404 {
                let languageHintLine: String
                if let preferredLanguageHint = transcriptionPreferences.preferredLanguageHint {
                    languageHintLine = "Preferred primary language hint: \(preferredLanguageHint). Keep code-switching exactly as spoken."
                } else {
                    languageHintLine = ""
                }
                let fallbackPrompt = """
                Transcribe the attached audio or video verbatim and return plain text only.
                Requirements:
                - Preserve the speaker's original wording and order.
                - Preserve fillers, repetitions, and self-corrections when present.
                - Preserve multilingual/code-switched speech exactly as spoken.
                - Do NOT summarize, rewrite, polish, or format as Markdown.
                - Do NOT infer intent or adapt tone for any target app.
                - Do NOT translate; keep the original spoken language(s). \(languageHintLine)
                - Do NOT include timestamps, speaker labels, or line numbers.
                Return ONLY the transcript text, no explanations.
                """
                let text = try await generateContent(
                    prompt: fallbackPrompt,
                    audioFileURL: audioFileURL,
                    systemInstruction: """
                    You are a professional media transcription assistant.
                    Rules:
                    - Do NOT translate; keep the original language(s) spoken. \(languageHintLine)
                    - Preserve multilingual/code-switched speech exactly as spoken.
                    - Preserve the speaker's original wording as faithfully as possible.
                    - Keep fillers, repetitions, and false starts as spoken.
                    - Do NOT clean up, summarize, or restructure.
                    - Do NOT include timestamps, speaker labels, or line numbers.
                    - Return ONLY the transcript text, no explanations.
                    """,
                    countUsage: false,
                    usageType: countUsage ? .voice : nil
                )
                if let normalized = TranscriptionContentValidator.normalizedTranscriptOrNil(text) {
                    return normalized
                }
                throw GeminiError.apiError(TranscriptionContentValidator.fallbackEmptyTranscriptionMessage())
            }

            if !(200...299).contains(httpResponse.statusCode) {
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let message = errorJson["error"] as? String {
                        throw GeminiError.apiError(message)
                    }
                    if let errorDict = errorJson["error"] as? [String: Any],
                       let message = errorDict["message"] as? String {
                        throw GeminiError.apiError(message)
                    }
                    if let message = errorJson["message"] as? String {
                        throw GeminiError.apiError(message)
                    }
                }
                throw GeminiError.apiError("Status code: \(httpResponse.statusCode)")
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let text = json["text"] as? String {
                if let normalized = TranscriptionContentValidator.normalizedTranscriptOrNil(text) {
                    return normalized
                }
                throw GeminiError.apiError(TranscriptionContentValidator.fallbackEmptyTranscriptionMessage())
            }

            throw GeminiError.invalidResponse
        } catch let error as GeminiError {
            throw error
        } catch {
            throw GeminiError.networkError(error)
        }
    }

    func transcribeMediaLink(_ url: URL) async throws -> MediaLinkTranscriptionResult {
        let serverURL = AppConfig.backendBaseURL + "/ai/media-link-transcript"
        guard let endpointURL = URL(string: serverURL) else {
            throw GeminiError.invalidURL
        }

        var request = try await makeAuthorizedJSONRequest(url: endpointURL, timeout: 300)
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "url": url.absoluteString
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw GeminiError.apiError("Status code: \(httpResponse.statusCode)")
        }

        return try JSONDecoder().decode(MediaLinkTranscriptionResult.self, from: data)
    }

    func extractTextFromImage(imageFileURL: URL) async throws -> String {
        let prompt = """
        Extract all readable text from the attached image.

        Rules:
        - Return plain text only.
        - Preserve the original language.
        - Preserve useful line breaks when they help readability.
        - Do not summarize.
        - Do not describe the image unless the description is visible text.
        - If there is no readable text, return an empty string.
        """

        let text = try await generateContent(
            prompt: prompt,
            imageFileURL: imageFileURL,
            systemInstruction: """
            You are an OCR assistant. Return only text found in the image.
            """,
            countUsage: false
        )

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func transcribeTikTokLink(_ url: URL) async throws -> MediaLinkTranscriptionResult {
        try await transcribeMediaLink(url)
    }

    /// Backward compatible alias. Intentionally returns STT-only text now.
    func transcribeAndPolish(audioFileURL: URL) async throws -> String {
        try await transcribeAudio(audioFileURL: audioFileURL)
    }
    
    /// Simple chat method for text-based AI interactions
    /// - Parameter prompt: The user's message/prompt
    /// - Returns: AI's response
    func chat(prompt: String) async throws -> String {
        return try await generateContent(prompt: prompt)
    }
    
    /// Generates content with streaming response
    /// - Parameters:
    ///   - prompt: The text prompt
    ///   - systemInstruction: Optional system instruction
    /// - Returns: An async throwing stream of text chunks
    func streamGenerateContent(
        prompt: String,
        systemInstruction: String? = nil,
        usageType: DailyQuotaFeature? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let serverURL = AppConfig.backendBaseURL + "/ai/gemini"
                    guard let url = URL(string: serverURL) else {
                        throw GeminiError.invalidURL
                    }
                    
                    var request = try await makeAuthorizedJSONRequest(url: url, timeout: 120) // Longer timeout for stream
                    
                    var requestBody: [String: Any] = [
                        "prompt": prompt,
                        "stream": true
                    ]
                    
                    if let systemInstruction = systemInstruction {
                        requestBody["systemPrompt"] = systemInstruction
                    }
                    if let usageType {
                        requestBody["usageType"] = usageType.rawValue
                    }
                    
                    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                    
                    Self.logger.debug("Sending streaming request to \(serverURL, privacy: .private)")
                    
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw GeminiError.invalidResponse
                    }
                    
                    guard (200...299).contains(httpResponse.statusCode) else {
                        Self.logger.error("Streaming request failed with status \(httpResponse.statusCode, privacy: .public)")
                        if httpResponse.statusCode == 429 || httpResponse.statusCode == 402 {
                            throw GeminiError.apiError("Insufficient credits")
                        }
                        throw GeminiError.apiError("Status code: \(httpResponse.statusCode)")
                    }
                    
                    for try await line in bytes.lines {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty { continue }
                        
                        // Handle potential SSE format "data: {json}"
                        let jsonString = trimmed.hasPrefix("data: ") ? String(trimmed.dropFirst(6)) : trimmed
                        
                        if jsonString == "[DONE]" { break }
                        
                        guard let data = jsonString.data(using: .utf8) else { continue }
                        
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            // Extract text content from various potential backend formats
                            if let content = json["content"] as? String {
                                continuation.yield(content)
                            } else if let text = json["text"] as? String {
                                continuation.yield(text)
                            } else if let error = json["error"] as? String {
                                throw GeminiError.apiError(error)
                            }
                        }
                    }
                    
                    continuation.finish()
                    
                } catch {
                    Self.logger.error("Stream error: \(error.localizedDescription, privacy: .public)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

enum LanguageDetection {
    /// Returns a best-effort BCP-47-ish language tag (e.g. "en", "zh-Hans") if confidence is high.
    static func dominantLanguageTag(for text: String, minConfidence: Double = 0.6) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(String(trimmed.prefix(5000)))

        let hypotheses = recognizer.languageHypotheses(withMaximum: 2)
        guard let best = hypotheses.max(by: { $0.value < $1.value }) else { return nil }
        guard best.value >= minConfidence else { return nil }
        return best.key.rawValue
    }

    static func languagePreservationRule(for text: String) -> String {
        if let tag = dominantLanguageTag(for: text) {
            return """
            - Keep the output in the same language as the input (language hint: \(tag)).
            - Do NOT translate unless explicitly requested.
            """
        }
        return """
        - Keep the output in the same language(s) as the input.
        - If the input is mixed-language, preserve each segment's original language instead of normalizing to a single language.
        - Do NOT translate unless explicitly requested.
        """
    }
}
