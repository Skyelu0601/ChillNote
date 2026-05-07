import SwiftUI

/// A view that renders markdown-formatted text as rich text for preview purposes
/// This is a read-only, lightweight version optimized for list cards
struct RichTextPreview: View {
    let content: String
    var lineLimit: Int = 3
    var font: Font = .bodyMedium
    var textColor: Color = .textMain

    var body: some View {
        Text(makePreviewAttributedString(from: content))
            .font(font)
            .foregroundColor(textColor)
            .lineLimit(lineLimit)
            .multilineTextAlignment(.leading)
    }

    /// Parse markdown text into a flat AttributedString.
    ///
    /// Building a preview with thousands of concatenated `Text` values can make
    /// SwiftUI recurse until the main thread stack overflows. AttributedString
    /// keeps the same lightweight preview behavior without deep Text nesting.
    private func makePreviewAttributedString(from markdown: String) -> AttributedString {
        let lines = markdown.components(separatedBy: "\n")
        var result = AttributedString()

        for (index, line) in lines.enumerated() {
            result += parseLine(line)
            if index < lines.count - 1 {
                result += AttributedString("\n")
            }
        }

        return result
    }

    /// Parse a single line of markdown
    private func parseLine(_ line: String) -> AttributedString {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("### ") {
            return parseHeader(String(trimmed.dropFirst(4)), weight: .semibold)
        } else if trimmed.hasPrefix("## ") {
            return parseHeader(String(trimmed.dropFirst(3)), weight: .semibold)
        } else if trimmed.hasPrefix("# ") {
            return parseHeader(String(trimmed.dropFirst(2)), weight: .bold)
        }

        if trimmed.hasPrefix("- [ ] ") {
            return parseCheckbox(String(trimmed.dropFirst(6)), isChecked: false)
        } else if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
            return parseCheckbox(String(trimmed.dropFirst(6)), isChecked: true)
        }

        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("• ") {
            return parseBulletPoint(String(trimmed.dropFirst(2)))
        }

        if let match = trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) {
            let itemContent = String(trimmed[match.upperBound...])
            let number = String(trimmed[..<match.upperBound])
            return parseNumberedItem(number: number, content: itemContent)
        }

        if trimmed.hasPrefix("> ") {
            return parseBlockquote(String(trimmed.dropFirst(2)))
        }

        if trimmed == "---" || trimmed.hasPrefix("═") {
            var separator = AttributedString("───")
            separator.foregroundColor = .secondary
            return separator
        }

        return parseInlineFormatting(line)
    }

    private func parseHeader(_ text: String, weight: Font.Weight) -> AttributedString {
        var attributed = parseInlineFormatting(text)
        attributed.font = .system(size: 15, weight: weight)
        return attributed
    }

    private func parseCheckbox(_ text: String, isChecked: Bool) -> AttributedString {
        var prefix: AttributedString
        if isChecked {
            prefix = AttributedString("\(RichTextConverter.Config.checkboxCheckedSymbol) ")
            prefix.foregroundColor = .green
            prefix.font = .system(size: 16, weight: .semibold)
        } else {
            prefix = AttributedString("\(RichTextConverter.Config.checkboxUncheckedSymbol) ")
            prefix.foregroundColor = .accentPrimary
        }

        var contentText = parseInlineFormatting(text)
        if isChecked {
            contentText.foregroundColor = .secondary
            contentText.strikethroughStyle = .single
        }
        prefix += contentText
        return prefix
    }

    private func parseBulletPoint(_ text: String) -> AttributedString {
        var prefix = AttributedString("• ")
        prefix.foregroundColor = .secondary
        prefix += parseInlineFormatting(text)
        return prefix
    }

    private func parseNumberedItem(number: String, content: String) -> AttributedString {
        var prefix = AttributedString(number)
        prefix.foregroundColor = .secondary
        prefix += parseInlineFormatting(content)
        return prefix
    }

    private func parseBlockquote(_ text: String) -> AttributedString {
        var prefix = AttributedString("│ ")
        prefix.foregroundColor = .accentPrimary
        var content = parseInlineFormatting(text)
        content.foregroundColor = .secondary
        prefix += content
        return prefix
    }

    /// Parse inline formatting (**bold**, *italic*, `code`)
    private func parseInlineFormatting(_ text: String) -> AttributedString {
        var currentIndex = text.startIndex
        var result = AttributedString()

        while currentIndex < text.endIndex {
            if text[currentIndex...].hasPrefix("**"),
               let endIndex = text.range(of: "**", range: text.index(currentIndex, offsetBy: 2)..<text.endIndex)?.lowerBound {
                let boldContent = String(text[text.index(currentIndex, offsetBy: 2)..<endIndex])
                var segment = AttributedString(boldContent)
                segment.inlinePresentationIntent = .stronglyEmphasized
                result += segment
                currentIndex = text.index(endIndex, offsetBy: 2)
                continue
            }

            if text[currentIndex...].hasPrefix("*"),
               !text[currentIndex...].hasPrefix("**"),
               let endIndex = text.range(of: "*", range: text.index(currentIndex, offsetBy: 1)..<text.endIndex)?.lowerBound {
                let italicContent = String(text[text.index(currentIndex, offsetBy: 1)..<endIndex])
                var segment = AttributedString(italicContent)
                segment.inlinePresentationIntent = .emphasized
                result += segment
                currentIndex = text.index(endIndex, offsetBy: 1)
                continue
            }

            if text[currentIndex] == "`",
               let endIndex = text.range(of: "`", range: text.index(currentIndex, offsetBy: 1)..<text.endIndex)?.lowerBound {
                let codeContent = String(text[text.index(currentIndex, offsetBy: 1)..<endIndex])
                var segment = AttributedString(" \(codeContent) ")
                segment.font = .system(size: 13, design: .monospaced)
                segment.foregroundColor = .purple
                result += segment
                currentIndex = text.index(endIndex, offsetBy: 1)
                continue
            }

            let nextIndex = text.index(after: currentIndex)
            result += AttributedString(String(text[currentIndex..<nextIndex]))
            currentIndex = text.index(after: currentIndex)
        }

        return result
    }
}

#if DEBUG
struct RichTextPreview_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 16) {
            RichTextPreview(
                content: "# Header\nThis is **bold** and *italic*.",
                lineLimit: 5
            )

            RichTextPreview(
                content: "- First item\n- [ ] Todo item\n- [x] Done item",
                lineLimit: 5
            )

            RichTextPreview(
                content: "1. First step\n2. Second step\n> Important note",
                lineLimit: 5
            )
        }
        .padding()
    }
}
#endif
