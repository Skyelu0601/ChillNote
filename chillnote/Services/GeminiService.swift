import Foundation
import NaturalLanguage

enum GeminiError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case networkError(Error)
    case apiError(String)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Chillo service key is not configured."
        case .invalidURL:
            return "Invalid Chillo configuration."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let message):
            return "Chillo Service Error: \(message)"
        case .invalidResponse:
            return "Invalid response from Chillo."
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

struct GeminiService {
    static let shared = GeminiService()

    private func makeAuthorizedJSONRequest(url: URL, timeout: TimeInterval) async throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout

        guard let token = await AuthService.shared.getSessionToken(), !token.isEmpty else {
            throw GeminiError.apiError("Sign in required")
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
        systemInstruction: String? = nil,
        jsonMode: Bool = false,
        countUsage: Bool = false,
        usageType: DailyQuotaFeature? = nil
    ) async throws -> String {
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
        
        // Add Audio if present
        if let audioURL = audioFileURL, let audioData = try? Data(contentsOf: audioURL) {
            let base64Audio = audioData.base64EncodedString()
            let ext = audioURL.pathExtension.lowercased()
            let mimeType = ext == "m4a" ? "audio/m4a" : (ext == "mp3" ? "audio/mp3" : "audio/wav")
            
            requestBody["audioBase64"] = base64Audio
            requestBody["mimeType"] = mimeType
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("🌐 Sending request to \(serverURL)")
        // Execute Request
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            print("📥 Got response")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GeminiError.invalidResponse
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
        locale: String? = nil,
        countUsage: Bool = true
    ) async throws -> String {
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
        let ext = audioFileURL.pathExtension.lowercased()
        let mimeType = ext == "wav" ? "audio/wav" : (ext == "m4a" ? "audio/m4a" : (ext == "mp3" ? "audio/mp3" : "application/octet-stream"))
        let transcriptionPreferences = VoiceTranscriptionPreferences.load()
        let effectiveLocale: String? = {
            if let locale {
                let trimmed = locale.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
            let preferred = Locale.preferredLanguages.first?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let preferred, !preferred.isEmpty { return preferred }
            return nil
        }()

        var requestBody: [String: Any] = [
            "audioBase64": base64Audio,
            "mimeType": mimeType,
            "spokenLanguageMode": transcriptionPreferences.mode.rawValue,
            "countUsage": countUsage
        ]
        if let preferredLanguageHint = transcriptionPreferences.preferredLanguageHint {
            requestBody["spokenLanguageHint"] = preferredLanguageHint
        }
        if let effectiveLocale {
            requestBody["locale"] = effectiveLocale
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        print("🌐 Sending request to \(serverURL)")

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
                } else if let effectiveLocale {
                    languageHintLine = "Locale hint: \(effectiveLocale)."
                } else {
                    languageHintLine = ""
                }
                let fallbackPrompt = """
                Transcribe the attached audio verbatim and return plain text only.
                Requirements:
                - Preserve the speaker's original wording and order.
                - Preserve fillers, repetitions, and self-corrections when present.
                - Preserve multilingual/code-switched speech exactly as spoken.
                - Do NOT summarize, rewrite, polish, or format as Markdown.
                - Do NOT infer intent or adapt tone for any target app.
                - Do NOT translate; keep the original spoken language(s). \(languageHintLine)
                Return ONLY the transcript text, no explanations.
                """
                let text = try await generateContent(
                    prompt: fallbackPrompt,
                    audioFileURL: audioFileURL,
                    systemInstruction: """
                    You are a professional voice transcription assistant.
                    Rules:
                    - Do NOT translate; keep the original language(s) spoken. \(languageHintLine)
                    - Preserve multilingual/code-switched speech exactly as spoken.
                    - Preserve the speaker's original wording as faithfully as possible.
                    - Keep fillers, repetitions, and false starts as spoken.
                    - Do NOT clean up, summarize, or restructure.
                    - Return ONLY the transcript text, no explanations.
                    """,
                    countUsage: false,
                    usageType: countUsage ? .voice : nil
                )
                return text
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
                return text
            }

            throw GeminiError.invalidResponse
        } catch let error as GeminiError {
            throw error
        } catch {
            throw GeminiError.networkError(error)
        }
    }

    /// Backward compatible alias. Intentionally returns STT-only text now.
    func transcribeAndPolish(audioFileURL: URL, locale: String? = nil) async throws -> String {
        try await transcribeAudio(audioFileURL: audioFileURL, locale: locale)
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
                    
                    print("🌐 Sending streaming request to \(serverURL)")
                    
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw GeminiError.invalidResponse
                    }
                    
                    guard (200...299).contains(httpResponse.statusCode) else {
                        // Validate error if possible, though handling bytes error content is tricky without consuming stream
                        print("❌ Stream failed with status: \(httpResponse.statusCode)")
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
                    print("❌ Stream error: \(error.localizedDescription)")
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
