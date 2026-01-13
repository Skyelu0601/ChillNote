import Foundation

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

    /// Voice note: transcribe + lightly polish, returning only final text.
    func transcribeAndPolish(audioFileURL: URL, locale: String? = nil) async throws -> String {
        let serverURL = AppConfig.backendBaseURL + "/ai/voice-note"
        guard let url = URL(string: serverURL) else {
            throw GeminiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

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
                let fallbackPrompt = """
                Transcribe the attached audio. Remove filler words (um, ah, like, you know), \
                fix grammar, and lightly polish the text while preserving the original meaning \
                and tone. Return ONLY the polished text, no explanations.
                """
                return try await generateContent(prompt: fallbackPrompt, audioFileURL: audioFileURL)
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
}
