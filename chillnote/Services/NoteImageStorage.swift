import Foundation

enum NoteImageStorage {
    static func markdownImageFileURLs(in markdown: String) -> [URL] {
        let pattern = #"!\[[^\]]*\]\(([^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)

        return regex.matches(in: markdown, range: nsRange).compactMap { match in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: markdown) else {
                return nil
            }
            let urlString = String(markdown[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: urlString), url.isFileURL else { return nil }
            return url
        }
    }

    static func removingMarkdownImages(from markdown: String) -> String {
        let pattern = #"!\[[^\]]*\]\([^)]+\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return markdown }
        let nsRange = NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)
        return regex.stringByReplacingMatches(in: markdown, range: nsRange, withTemplate: "")
    }
}
