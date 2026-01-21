import SwiftUI

/// A view that renders markdown-formatted text as rich text for preview purposes
/// This is a read-only, lightweight version optimized for list cards
struct RichTextPreview: View {
    let content: String
    var lineLimit: Int = 3
    var font: Font = .bodyMedium
    var textColor: Color = .textMain
    
    var body: some View {
        Text(parseMarkdownToAttributedString(content))
            .font(font)
            .foregroundColor(textColor)
            .lineLimit(lineLimit)
            .multilineTextAlignment(.leading)
    }
    
    /// Parse markdown text and convert to AttributedString for SwiftUI Text
    private func parseMarkdownToAttributedString(_ markdown: String) -> AttributedString {
        var result = AttributedString()
        
        // Split into lines and process each
        let lines = markdown.components(separatedBy: "\n")
        
        for (lineIndex, line) in lines.enumerated() {
            let parsedLine = parseLine(line)
            result.append(parsedLine)
            
            // Add newline except for the last line
            if lineIndex < lines.count - 1 {
                result.append(AttributedString("\n"))
            }
        }
        
        return result
    }
    
    /// Parse a single line of markdown
    private func parseLine(_ line: String) -> AttributedString {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Check for headers - show them as bold
        if trimmed.hasPrefix("### ") {
            return parseHeader(String(trimmed.dropFirst(4)), weight: .semibold)
        } else if trimmed.hasPrefix("## ") {
            return parseHeader(String(trimmed.dropFirst(3)), weight: .semibold)
        } else if trimmed.hasPrefix("# ") {
            return parseHeader(String(trimmed.dropFirst(2)), weight: .bold)
        }
        
        // Check for checkbox items - show with visual checkbox
        if trimmed.hasPrefix("- [ ] ") {
            return parseCheckbox(String(trimmed.dropFirst(6)), isChecked: false)
        } else if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
            return parseCheckbox(String(trimmed.dropFirst(6)), isChecked: true)
        }
        
        // Check for bullet points
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("• ") {
            return parseBulletPoint(String(trimmed.dropFirst(2)))
        }
        
        // Check for numbered list
        if let match = trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) {
            let content = String(trimmed[match.upperBound...])
            let number = String(trimmed[..<match.upperBound])
            return parseNumberedItem(number: number, content: content)
        }
        
        // Check for blockquote
        if trimmed.hasPrefix("> ") {
            return parseBlockquote(String(trimmed.dropFirst(2)))
        }
        
        // Check for divider - convert to a line
        if trimmed == "---" || trimmed.hasPrefix("═") {
            var divider = AttributedString("───")
            divider.foregroundColor = .secondary
            return divider
        }
        
        // Regular text with inline formatting
        return parseInlineFormatting(line)
    }
    
    /// Parse header
    private func parseHeader(_ text: String, weight: Font.Weight) -> AttributedString {
        var result = parseInlineFormatting(text)
        result.font = .system(size: 15, weight: weight)
        return result
    }
    
    /// Parse checkbox
    private func parseCheckbox(_ text: String, isChecked: Bool) -> AttributedString {
        var result = AttributedString()
        
        // Checkbox symbol
        var checkbox = AttributedString(isChecked ? "☑ " : "☐ ")
        checkbox.foregroundColor = isChecked ? .green : .secondary
        result.append(checkbox)
        
        // Content
        var content = parseInlineFormatting(text)
        if isChecked {
            content.foregroundColor = .secondary
            content.strikethroughStyle = .single
        }
        result.append(content)
        
        return result
    }
    
    /// Parse bullet point
    private func parseBulletPoint(_ text: String) -> AttributedString {
        var result = AttributedString()
        
        var bullet = AttributedString("• ")
        bullet.foregroundColor = .orange
        result.append(bullet)
        
        result.append(parseInlineFormatting(text))
        
        return result
    }
    
    /// Parse numbered item
    private func parseNumberedItem(number: String, content: String) -> AttributedString {
        var result = AttributedString()
        
        var num = AttributedString(number)
        num.foregroundColor = .orange
        result.append(num)
        
        result.append(parseInlineFormatting(content))
        
        return result
    }
    
    /// Parse blockquote
    private func parseBlockquote(_ text: String) -> AttributedString {
        var result = AttributedString()
        
        var bar = AttributedString("│ ")
        bar.foregroundColor = .orange
        result.append(bar)
        
        var quote = parseInlineFormatting(text)
        quote.foregroundColor = .secondary
        result.append(quote)
        
        return result
    }
    
    /// Parse inline formatting (**bold**, *italic*, `code`)
    private func parseInlineFormatting(_ text: String) -> AttributedString {
        var result = AttributedString()
        var currentIndex = text.startIndex
        
        while currentIndex < text.endIndex {
            // Check for bold (**text**)
            if text[currentIndex...].hasPrefix("**") {
                if let endIndex = text.range(of: "**", range: text.index(currentIndex, offsetBy: 2)..<text.endIndex)?.lowerBound {
                    let boldContent = String(text[text.index(currentIndex, offsetBy: 2)..<endIndex])
                    var boldText = AttributedString(boldContent)
                    boldText.font = .system(size: 15, weight: .bold)
                    result.append(boldText)
                    currentIndex = text.index(endIndex, offsetBy: 2)
                    continue
                }
            }
            
            // Check for italic (*text*) - but not bold
            if text[currentIndex...].hasPrefix("*") && !text[currentIndex...].hasPrefix("**") {
                if let endIndex = text.range(of: "*", range: text.index(currentIndex, offsetBy: 1)..<text.endIndex)?.lowerBound {
                    let italicContent = String(text[text.index(currentIndex, offsetBy: 1)..<endIndex])
                    var italicText = AttributedString(italicContent)
                    italicText.font = .italic(.body)()
                    result.append(italicText)
                    currentIndex = text.index(endIndex, offsetBy: 1)
                    continue
                }
            }
            
            // Check for inline code (`code`)
            if text[currentIndex] == "`" {
                if let endIndex = text.range(of: "`", range: text.index(currentIndex, offsetBy: 1)..<text.endIndex)?.lowerBound {
                    let codeContent = String(text[text.index(currentIndex, offsetBy: 1)..<endIndex])
                    var codeText = AttributedString(" \(codeContent) ")
                    codeText.font = .system(size: 13, design: .monospaced)
                    codeText.foregroundColor = .purple
                    codeText.backgroundColor = Color(.systemGray6)
                    result.append(codeText)
                    currentIndex = text.index(endIndex, offsetBy: 1)
                    continue
                }
            }
            
            // Regular character
            result.append(AttributedString(String(text[currentIndex])))
            currentIndex = text.index(after: currentIndex)
        }
        
        return result
    }
}

// MARK: - Preview

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
