import Foundation
import SwiftData

class TagService {
    static let shared = TagService()
    private init() {}
    
    /// Suggests tags for a given content, considering existing tags to maintain consistency.
    func suggestTags(for content: String, existingTags: [String]) async throws -> [String] {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedContent.count > 5 else { return [] }
        
        let existingTagsList = existingTags.isEmpty ? "None" : existingTags.joined(separator: ", ")
        
        let languageRule = LanguageDetection.languagePreservationRule(for: trimmedContent)
        
        let prompt = """
        Suggest exactly 3 tags for this note, each at a different level of specificity:
        
        Note:
        \"\"\"
        \(trimmedContent)
        \"\"\"
        
        User's existing tags: \(existingTagsList)
        
        Tag levels (output in this exact order):
        1st tag: Broad — a life/work area (e.g., Work, Life, Learning, Health)
        2nd tag: Topic — a subject you'd build knowledge around (e.g., AI, Product Design, Fitness)
        3rd tag: Specific — a focused subtopic within that subject (e.g., LLM, User Research, Running)
        
        Guidelines:
        - Prefer reusing existing tags when they fit well.
        \(languageRule)
        
        Output format: "Broad, Topic, Specific" — Example: "Work, AI, LLM"
        """
        
        let systemInstruction = """
        You suggest meaningful topic tags for personal notes at three levels: broad area, topic, and specific subtopic.
        \(languageRule)
        """
        
        do {
            let response = try await GeminiService.shared.generateContent(
                prompt: prompt,
                systemInstruction: systemInstruction,
                countUsage: false
            )
            
            // Clean up response
            let suggestions = response.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .map { $0.replacingOccurrences(of: "#", with: "") } // Remove stray hashtags
                .filter { !$0.isEmpty }
            
            return Array(Set(suggestions)).prefix(3).map { String($0) }
        } catch {
            print("⚠️ TagService Error: \(error)")
            return []
        }
    }
    
    /// Marks tags that are no longer associated with any active notes as deleted (soft-delete for sync).
    /// If candidates are provided, only those tags are checked.
    func cleanupEmptyTags(context: ModelContext, candidates: [Tag]? = nil) {
        let tagsToCheck: [Tag]
        if let candidates, !candidates.isEmpty {
            var seen = Set<UUID>()
            tagsToCheck = candidates.filter { tag in
                guard !seen.contains(tag.id) else { return false }
                seen.insert(tag.id)
                return true
            }
        } else {
            let fetchDescriptor = FetchDescriptor<Tag>()
            tagsToCheck = (try? context.fetch(fetchDescriptor)) ?? []
        }
        for tag in tagsToCheck {
            let activeNotes = tag.notes.filter { $0.deletedAt == nil }
            if activeNotes.isEmpty {
                let now = Date()
                tag.deletedAt = now
                tag.updatedAt = now
            }
        }
        do {
            try context.save()
        } catch {
            print("⚠️ TagService Cleanup Error: \(error)")
        }
    }
}
