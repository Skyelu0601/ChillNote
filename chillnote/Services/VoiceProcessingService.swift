import SwiftUI
import SwiftData

enum VoiceNoteState: Equatable {
    case idle
    case processing(stage: VoiceProcessingStage)
    case completed(originalText: String)
    case failed(message: String)
}

/// Service for processing voice transcripts with intent recognition and structuring
@MainActor
class VoiceProcessingService: ObservableObject {
    static let shared = VoiceProcessingService()
    
    @Published var processingStates: [UUID: VoiceNoteState] = [:]
    
    private init() {}
    
    /// Process the note in the background and update it dynamically
    func startProcessing(note: Note, rawTranscript: String, context: ModelContext) async {
        let noteID = note.id
        let cleanTranscript = removeTimestamps(from: rawTranscript)
        processingStates[noteID] = .processing(stage: .refining)
        
        do {
            let processedText = try await processTranscript(cleanTranscript)
            

            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                // Update the note content
                note.content = processedText
                note.syncContentStructure(with: context)
                note.updatedAt = Date()
                try? context.save()

                processingStates[noteID] = .completed(originalText: cleanTranscript)
            }
            
            // Clear the specific state after 10 seconds (hides Undo option)
            Task {
                try? await Task.sleep(nanoseconds: 10 * 1_000_000_000)
                if case .completed = processingStates[noteID] {
                    _ = withAnimation {
                        processingStates.removeValue(forKey: noteID)
                    }
                }
            }
            
        } catch {
            print("⚠️ AI processing failed: \(error)")
            // AI processing failed; do not apply local fallback.
            // Leave the note content as is (or handled by caller/UI).
            // Reset state so UI knows we are done (or failed).
            processingStates[noteID] = .failed(message: String(localized: "AI refinement failed. You can keep editing this note."))
        }
    }

    /// Process raw voice transcript into structured, usable text
    /// This handles intent recognition and automatic formatting
    func processTranscript(_ rawTranscript: String) async throws -> String {
        let trimmed = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        let isShortInput = isMinimalEditInput(trimmed)
        let toneTargetRule = toneTargetInstruction(for: trimmed)

        let prompt = """
        Process this voice transcript into clean, directly usable text.

        Voice transcript:
        \(trimmed)
        """

        let languageRule = LanguageDetection.languagePreservationRule(for: trimmed)

        let systemInstruction = """
        You are a voice-to-text optimizer called "chillnote". Your job is to transform raw speech transcripts into polished, ready-to-use notes.

        STRICT RULES:
        - PRIMARY OBJECTIVE: Preserve the user's intent, meaning, and factual content exactly.
        \(languageRule)
        - NO TRANSLATION unless the user explicitly asks for translation.
        - ALLOWED EDITS ONLY:
          - Remove obvious filler words and accidental repetitions.
          - Resolve explicit self-corrections to the user's final intended wording.
          - Light grammar and punctuation cleanup for readability.
        - FORBIDDEN EDITS:
          - Do NOT add new facts, assumptions, dates, names, or commitments.
          - Do NOT delete key information, constraints, conditions, or action items.
          - Do NOT change the meaning, priority, or certainty level of statements.
          - Do NOT rewrite in a different style unless the user explicitly requests a target format/tone.
        \(toneTargetRule)
        - If any part is ambiguous or uncertain, keep the original wording for that part instead of guessing.
        - For short inputs (under 30 characters): use MINIMAL-EDIT mode and keep wording nearly verbatim.
          - Current input short mode: \(isShortInput ? "ON" : "OFF")
        - IMPLICIT STRUCTURING:
          - Even without explicit keywords, detect structural intent (topic shifts, sequence, steps, conclusions, action items).
          - If structure is clearly implied: split into clean paragraphs, and optionally add short one-line subheadings.
          - If structure is weak: do light paragraphing only, avoid forced headings.
        - TODO / CHECKLIST:
          - If content is task-oriented (next steps, action items, commitments), format tasks as Markdown checklist items:
            - [ ] Task
          - For mixed content, keep short context notes first, then one blank line, then checklist.
          - Do NOT invent tasks; only convert/reorganize user-provided intent.
        - SHORT-INPUT SAFETY:
          - If short mode is ON, do not force structuring or checklist conversion.
        - NO EXPLANATIONS: Return ONLY the processed note text. Do not add "Here is your note" or any metadata.
        - Keep markdown style simple and directly editable.
        """

        let refined = try await GeminiService.shared.generateContent(
            prompt: prompt,
            systemInstruction: systemInstruction,
            countUsage: false
        )

        return refined
    }
    
    /// Process voice command for the Voice Agent (placeholder for future expansion)
    /// Currently returns the command for logging, but will be expanded for actual agent actions
    func processAgentCommand(_ rawTranscript: String) async throws -> AgentCommandResult {
        let trimmed = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // For now, just return a placeholder result
        // This will be expanded when Voice Agent features are defined
        return AgentCommandResult(
            command: trimmed,
            action: .unknown,
            message: "Voice Agent received: \(trimmed)"
        )
    }
}

private extension VoiceProcessingService {
    func isMinimalEditInput(_ text: String) -> Bool {
        text.count < 30
    }

    func toneTargetInstruction(for text: String) -> String {
        let normalized = text.lowercased()
        let hasEmail = normalized.contains("email") || normalized.contains("邮件") || normalized.contains("郵件")
        let hasTweet = normalized.contains("twitter") || normalized.contains("tweet") || normalized.contains("x ")
            || normalized.hasSuffix(" x") || normalized.contains("推特")
        let hasMeeting = normalized.contains("meeting note") || normalized.contains("meeting notes")
            || normalized.contains("会议纪要") || normalized.contains("會議紀要")

        if hasEmail || hasTweet || hasMeeting {
            return """
            - TONE ADAPTATION: Enabled only because an explicit target was detected.
              - Email: professional format with greeting and closing.
              - Twitter/X/Tweet: concise and scan-friendly.
              - Meeting Notes: structured with headers and action items.
            """
        }

        return "- TONE ADAPTATION: Disabled by default. Keep the user's original tone and register."
    }

    func removeTimestamps(from text: String) -> String {
        // Matches timestamps like 00:00, [00:00], 00:00 00:01 at the start of lines
        // Pattern: Start of line, optional brackets, digits:digits, optional seconds, optional brackets, whitespace
        let pattern = #"^(?:\[?\d{1,2}:\d{2}(?::\d{2})?\]?\s*)+"#
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        } catch {
            return text
        }
    }
}

// MARK: - Voice Agent Types (Placeholder for future expansion)

struct AgentCommandResult {
    let command: String
    let action: AgentAction
    let message: String
}

enum AgentAction {
    case unknown
    case createNote
    case searchNotes
    case summarizeNotes
    case deleteNote
    // Future actions to be added
}
