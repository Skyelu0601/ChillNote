import UIKit

enum NoteImageStorage {
    private static let directoryName = "NoteImages"

    static func saveImportedImage(_ image: UIImage) throws -> URL {
        let directoryURL = try imagesDirectoryURL()
        let fileURL = directoryURL
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")

        guard let data = normalizedJPEGData(from: image, maxDimension: 4_096, compressionQuality: 0.95) else {
            throw CocoaError(.fileWriteUnknown)
        }

        try data.write(to: fileURL, options: [.atomic])
        return fileURL
    }

    static func markdownImageLine(for fileURL: URL) -> String {
        "![](\(fileURL.absoluteString))"
    }

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

    private static func imagesDirectoryURL() throws -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directoryURL = baseURL.appendingPathComponent(directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    private static func normalizedJPEGData(
        from image: UIImage,
        maxDimension: CGFloat,
        compressionQuality: CGFloat
    ) -> Data? {
        let originalSize = image.size
        let longestSide = max(originalSize.width, originalSize.height)
        let scale = longestSide > maxDimension ? maxDimension / longestSide : 1
        let targetSize = CGSize(width: originalSize.width * scale, height: originalSize.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let normalizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return normalizedImage.jpegData(compressionQuality: compressionQuality)
    }
}
