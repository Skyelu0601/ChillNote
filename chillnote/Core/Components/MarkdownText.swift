import SwiftUI

/// A view that renders markdown-formatted text with support for bold, italic, and other basic markdown syntax
struct MarkdownText: View {
    let content: String
    
    init(_ content: String) {
        self.content = content
    }
    
    var body: some View {
        Text(parseMarkdown(content))
    }
    
    /// Parse markdown text and return an AttributedString with proper formatting
    private func parseMarkdown(_ text: String) -> AttributedString {
        // Use SwiftUI's built-in markdown support (iOS 15+)
        do {
            let attributedString = try AttributedString(
                markdown: text,
                options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            )
            return attributedString
        } catch {
            // If markdown parsing fails, return plain text
            return AttributedString(text)
        }
    }
}

#if DEBUG
struct MarkdownText_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 16) {
            MarkdownText("This is **bold** text")
                .font(.bodyMedium)

            MarkdownText("This is *italic* text")
                .font(.bodyMedium)

            MarkdownText("This is **bold** and *italic* text")
                .font(.bodyMedium)

            MarkdownText("This is a `code` snippet")
                .font(.bodyMedium)

            MarkdownText("Normal text with **bold**, *italic*, and `code`")
                .font(.bodyMedium)
        }
        .padding()
    }
}
#endif
