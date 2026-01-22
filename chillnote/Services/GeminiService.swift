import Foundation
import NaturalLanguage

enum GeminiError: Error {
    case missingAPIKey
    case invalidURL
    case networkError(Error)
    case apiError(String)
    case invalidResponse
}

struct GeminiService {
    static let shared = GeminiService()
    
    /// Generates content from prompt and optional media (Multimodal)
    /// - Parameters:
    ///   - prompt: The text prompt
    ///   - audioFileURL: Optional URL to an audio file. The file will be read and sent as inline base64 data.
    ///   - systemInstruction: Optional system instruction (system prompt)
    ///   - jsonMode: If true, requests JSON output
    /// - Returns: Generated text content
    func generateContent(prompt: String, audioFileURL: URL? = nil, systemInstruction: String? = nil, jsonMode: Bool = false) async throws -> String {
        let serverURL = AppConfig.backendBaseURL + "/ai/gemini"
        guard let url = URL(string: serverURL) else {
            throw GeminiError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        
        // Build payload for backend proxy
        var requestBody: [String: Any] = [
            "prompt": prompt,
            "jsonMode": jsonMode
        ]
        
        if let systemInstruction = systemInstruction {
            requestBody["systemPrompt"] = systemInstruction
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

    /// Voice note: transcribe + lightly polish, returning final text.
    func transcribeAndPolish(audioFileURL: URL, locale: String? = nil) async throws -> String {
        let serverURL = AppConfig.backendBaseURL + "/ai/voice-note"
        guard let url = URL(string: serverURL) else {
            throw GeminiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Upload + model latency can exceed 60s for longer recordings.
        request.timeoutInterval = 180

        guard let audioData = try? Data(contentsOf: audioFileURL) else {
            throw GeminiError.invalidResponse
        }

        let base64Audio = audioData.base64EncodedString()
        let ext = audioFileURL.pathExtension.lowercased()
        let mimeType = ext == "wav" ? "audio/wav" : (ext == "m4a" ? "audio/m4a" : (ext == "mp3" ? "audio/mp3" : "application/octet-stream"))

        var requestBody: [String: Any] = [
            "audioBase64": base64Audio,
            "mimeType": mimeType
        ]
        if let locale, !locale.isEmpty {
            requestBody["locale"] = locale
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
                let localeHintLine: String
                if let locale, !locale.isEmpty {
                    localeHintLine = "Locale hint: \(locale)."
                } else {
                    localeHintLine = ""
                }
                let fallbackPrompt = """
                Transcribe the attached audio and return the final cleaned text.
                Requirements:
                - Remove filler words and disfluencies (e.g., um, uh, like, you know).
                - Remove unnecessary repetition while preserving intentional emphasis.
                - If the speaker corrects themselves mid-sentence, keep only the final intended wording.
                - Auto-format lists/steps/key points into clear structured Markdown when appropriate.
                - Lightly improve word choice for clarity without changing meaning.
                - If the speaker indicates a target (email/twitter/support/chat), adapt tone and format accordingly.
                - Do NOT translate; keep the original language spoken. \(localeHintLine)
                Return ONLY the final text, no explanations.
                """
                let text = try await generateContent(
                    prompt: fallbackPrompt,
                    audioFileURL: audioFileURL,
                    systemInstruction: """
                    You are a professional voice transcription assistant.
                    Rules:
                    - Do NOT translate; keep the original language spoken. \(localeHintLine)
                    - Preserve the speaker's meaning, tone, and intent.
                    - Remove fillers and disfluencies, unnecessary repetition, and false starts.
                    - When the speaker changes their mind mid-sentence, keep only the final intended message.
                    - Auto-format lists/steps into clear structured Markdown when appropriate.
                    - If the speaker indicates a target channel/app (email/twitter/support/chat), adapt tone and formatting accordingly.
                    - Return ONLY the final text, no explanations.
                    """
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
    
    /// Simple chat method for text-based AI interactions
    /// - Parameter prompt: The user's message/prompt
    /// - Returns: AI's response
    func chat(prompt: String) async throws -> String {
        return try await generateContent(prompt: prompt)
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
            return "- Keep the output in the same language as the input (language hint: \(tag)); do NOT translate unless explicitly requested."
        }
        return "- Keep the output in the same language(s) as the input; do NOT translate unless explicitly requested."
    }
}
