import SwiftUI

/// A view that renders markdown-formatted text as rich text for preview purposes
/// This is a read-only, lightweight version optimized for list cards
struct RichTextPreview: View {
    let content: String
    var lineLimit: Int = 3
    var font: Font = .bodyMedium
    var textColor: Color = .textMain

    var body: some View {
        parseMarkdownToText(content)
            .font(font)
            .foregroundColor(textColor)
            .lineLimit(lineLimit)
            .multilineTextAlignment(.leading)
    }

    /// Parse markdown text and convert to SwiftUI Text for inline symbol support
    private func parseMarkdownToText(_ markdown: String) -> Text {
        let lines = markdown.components(separatedBy: "\n")
        return lines.enumerated().reduce(Text(verbatim: "")) { partial, item in
            let (index, line) = item
            let parsedLine = parseLine(line)
            if index < lines.count - 1 {
                return partial + parsedLine + Text(verbatim: "\n")
            }
            return partial + parsedLine
        }
    }

    /// Parse a single line of markdown
    private func parseLine(_ line: String) -> Text {
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
            return Text(verbatim: "───").foregroundColor(.secondary)
        }

        return parseInlineFormatting(line)
    }

    private func parseHeader(_ text: String, weight: Font.Weight) -> Text {
        parseInlineFormatting(text).font(.system(size: 15, weight: weight))
    }

    private func parseCheckbox(_ text: String, isChecked: Bool) -> Text {
        let prefix: Text
        if isChecked {
            prefix =
                Text(Image(systemName: "checkmark.circle.fill"))
                .foregroundColor(.green)
                .font(.system(size: 16, weight: .semibold))
                + Text(verbatim: " ")
        } else {
            prefix =
                Text(verbatim: "\(RichTextConverter.Config.checkboxUncheckedSymbol) ")
                .foregroundColor(.accentPrimary)
                .baselineOffset(RichTextConverter.Config.checkboxBaselineOffset)
        }

        let contentText = parseInlineFormatting(text)
        if isChecked {
            return prefix + contentText.foregroundColor(.secondary).strikethrough()
        }
        return prefix + contentText
    }

    private func parseBulletPoint(_ text: String) -> Text {
        Text(verbatim: "• ").foregroundColor(.secondary) + parseInlineFormatting(text)
    }

    private func parseNumberedItem(number: String, content: String) -> Text {
        Text(verbatim: number).foregroundColor(.secondary) + parseInlineFormatting(content)
    }

    private func parseBlockquote(_ text: String) -> Text {
        Text(verbatim: "│ ").foregroundColor(.accentPrimary) + parseInlineFormatting(text).foregroundColor(.secondary)
    }

    /// Parse inline formatting (**bold**, *italic*, `code`)
    private func parseInlineFormatting(_ text: String) -> Text {
        var currentIndex = text.startIndex
        var result = Text(verbatim: "")

        while currentIndex < text.endIndex {
            if text[currentIndex...].hasPrefix("**"),
               let endIndex = text.range(of: "**", range: text.index(currentIndex, offsetBy: 2)..<text.endIndex)?.lowerBound {
                let boldContent = String(text[text.index(currentIndex, offsetBy: 2)..<endIndex])
                result = result + Text(verbatim: boldContent).bold()
                currentIndex = text.index(endIndex, offsetBy: 2)
                continue
            }

            if text[currentIndex...].hasPrefix("*"),
               !text[currentIndex...].hasPrefix("**"),
               let endIndex = text.range(of: "*", range: text.index(currentIndex, offsetBy: 1)..<text.endIndex)?.lowerBound {
                let italicContent = String(text[text.index(currentIndex, offsetBy: 1)..<endIndex])
                result = result + Text(verbatim: italicContent).italic()
                currentIndex = text.index(endIndex, offsetBy: 1)
                continue
            }

            if text[currentIndex] == "`",
               let endIndex = text.range(of: "`", range: text.index(currentIndex, offsetBy: 1)..<text.endIndex)?.lowerBound {
                let codeContent = String(text[text.index(currentIndex, offsetBy: 1)..<endIndex])
                result = result + Text(verbatim: " \(codeContent) ").font(.system(size: 13, design: .monospaced)).foregroundColor(.purple)
                currentIndex = text.index(endIndex, offsetBy: 1)
                continue
            }

            result = result + Text(verbatim: String(text[currentIndex]))
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
