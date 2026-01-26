import Foundation
import SwiftData

@MainActor
final class NoteExportService {
    static let shared = NoteExportService()
    
    private init() {}
    
    func createExportBundle(modelContext: ModelContext) throws -> URL {
        let descriptor = FetchDescriptor<Note>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let notes = try modelContext.fetch(descriptor)
        
        let fileManager = FileManager.default
        
        // Create a unique temporary directory for this export
        // Format: "ChillNote Export YYYY-MM-DD"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: Date())
        let folderName = "ChillNote_Export_\(dateStr)"
        
        // Base temp directory: /tmp/{UUID}/ChillNote_Export_.../
        // Using a UUID parent folder ensures we don't conflict with previous exports
        let tempBase = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let exportURL = tempBase.appendingPathComponent(folderName)
        
        try fileManager.createDirectory(at: exportURL, withIntermediateDirectories: true)
        
        var usedFilenames: Set<String> = []
        
        for note in notes {
            let filename = generateFileName(for: note, usedFilenames: &usedFilenames)
            let fileURL = exportURL.appendingPathComponent(filename)
            
            // Ensure we use the best content representation
            let contentToExport = note.exportAsMarkdown()
            try contentToExport.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        
        return exportURL
    }
    
    private func generateFileName(for note: Note, usedFilenames: inout Set<String>) -> String {
        // Use first line as title or generic
        let firstLine = note.content.components(separatedBy: .newlines).first ?? "Untitled Note"
        
        // Sanitize: remove illegal chars
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        var sanitized = firstLine.components(separatedBy: invalidCharacters).joined(separator: "")
        sanitized = sanitized
            .replacingOccurrences(of: #"[#\[\]]"#, with: "", options: .regularExpression) // Remove Markdown heading chars # and link brackets []
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if sanitized.isEmpty {
            sanitized = "Untitled Note"
        }
        
        // Trim length
        if sanitized.count > 60 {
            sanitized = String(sanitized.prefix(60))
        }
        
        var finalName = "\(sanitized).md"
        var counter = 1
        
        // Check for duplicates
        while usedFilenames.contains(finalName) {
            finalName = "\(sanitized) \(counter).md"
            counter += 1
        }
        
        usedFilenames.insert(finalName)
        return finalName
    }
}
