import Foundation

struct ChecklistMarkdown {
    struct ParsedChecklist {
        let notes: String
        let items: [(isDone: Bool, text: String)]
    }

    private static let checkboxRegex = try? NSRegularExpression(
        pattern: #"^\s*[-*]\s*\[( |x|X)\]\s*(.*?)\s*$"#,
        options: []
    )

    static func parse(_ content: String) -> ParsedChecklist? {
        guard let checkboxRegex else { return nil }
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var items: [(Bool, String)] = []
        var notesLines: [String] = []
        var currentItemIndex: Int?

        for line in lines {
            let nsLine = line as NSString
            let range = NSRange(location: 0, length: nsLine.length)
            if let match = checkboxRegex.firstMatch(in: line, options: [], range: range),
               match.numberOfRanges >= 3
            {
                let doneMark = nsLine.substring(with: match.range(at: 1))
                let text = nsLine.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                let isDone = doneMark.lowercased() == "x"
                items.append((isDone, text))
                currentItemIndex = items.count - 1
            } else {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    continue
                }

                if let currentItemIndex {
                    let existingText = items[currentItemIndex].1
                    items[currentItemIndex].1 = existingText.isEmpty
                        ? trimmed
                        : "\(existingText)\n\(trimmed)"
                } else {
                    notesLines.append(line)
                }
            }
        }

        guard !items.isEmpty else { return nil }
        let notes = notesLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return ParsedChecklist(notes: notes, items: items)
    }

    static func serialize(notes: String, items: [ChecklistItem]) -> String {
        var parts: [String] = []
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty {
            parts.append(trimmedNotes)
            parts.append("")
        }

        for item in items.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let mark = item.isDone ? "x" : " "
            let lines = item.text
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            guard let firstLine = lines.first else {
                parts.append("- [\(mark)]")
                continue
            }

            parts.append("- [\(mark)] \(firstLine)")
            for continuation in lines.dropFirst() {
                parts.append("    \(continuation)")
            }
        }

        return parts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func serializePlainText(notes: String, items: [ChecklistItem]) -> String {
        var parts: [String] = []
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty {
            parts.append(trimmedNotes)
            parts.append("")
        }

        for item in items.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            // User requested no prefixes when converting back to text
            let text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            parts.append(text)
        }

        return parts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
