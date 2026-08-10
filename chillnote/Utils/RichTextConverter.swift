import SwiftUI
import UIKit

struct RichTextSerializationSnapshot {
    let markdown: String
    let visualBoundaryToMarkdownCharacterOffset: [Int]
    let visualBoundaryToMarkdownSelectionEndOffset: [Int]

    func markdownSelection(for visualRange: NSRange) -> RichTextEditorSelection {
        let startVisual = min(max(visualRange.location, 0), visualBoundaryToMarkdownCharacterOffset.count - 1)
        let endVisual = min(
            max(visualRange.location + visualRange.length, startVisual),
            visualBoundaryToMarkdownCharacterOffset.count - 1
        )
        let start = visualBoundaryToMarkdownCharacterOffset[startVisual]
        let end = max(start, visualBoundaryToMarkdownSelectionEndOffset[endVisual])
        let selectedText = substring(characterLocation: start, length: end - start)
        return RichTextEditorSelection(location: start, length: end - start, selectedText: selectedText)
    }

    func visualRange(forMarkdownLocation location: Int, length: Int) -> NSRange {
        let boundedStart = min(max(location, 0), markdown.count)
        let boundedEnd = min(max(location + length, boundedStart), markdown.count)
        let start = nearestVisualBoundary(toMarkdownOffset: boundedStart)
        let end = nearestVisualBoundary(
            toMarkdownOffset: boundedEnd,
            mapping: visualBoundaryToMarkdownSelectionEndOffset
        )
        return NSRange(location: start, length: max(0, end - start))
    }

    private func nearestVisualBoundary(
        toMarkdownOffset target: Int,
        mapping: [Int]? = nil
    ) -> Int {
        let offsets = mapping ?? visualBoundaryToMarkdownCharacterOffset
        guard !offsets.isEmpty else { return 0 }
        var bestIndex = 0
        var bestDistance = Int.max
        for (index, offset) in offsets.enumerated() {
            let distance = abs(offset - target)
            let bestOffset = offsets[bestIndex]
            let isBetterTie = distance == bestDistance
                && bestOffset > target
                && offset <= target
            if distance < bestDistance || isBetterTie {
                bestIndex = index
                bestDistance = distance
            }
        }
        return bestIndex
    }

    private func substring(characterLocation: Int, length: Int) -> String {
        guard length > 0,
              let start = markdown.index(markdown.startIndex, offsetBy: characterLocation, limitedBy: markdown.endIndex),
              let end = markdown.index(start, offsetBy: length, limitedBy: markdown.endIndex) else {
            return ""
        }
        return String(markdown[start..<end])
    }
}

/// Utility for converting between Markdown and NSAttributedString
/// Supports bidirectional conversion for a WYSIWYG editing experience.
struct RichTextConverter {
    
    // MARK: - Constants & Configuration
    
    struct Config {
        static let baseFontSize: CGFloat = 17
        static let h1Size: CGFloat = 24
        static let h2Size: CGFloat = 20
        static let h3Size: CGFloat = 17 // Same as base but bold
        // Keep both states as single text glyphs. This makes the tap target,
        // caret position, and Markdown serialization identical in both states.
        static let checkboxUncheckedSymbol = "☐"
        static let checkboxCheckedSymbol = "☑"
        static let checkboxAttachmentPrefix = "\u{FFFC} "
        static let checkboxSymbolFontSizeOffset: CGFloat = 4
        static let checkboxBaselineOffset: CGFloat = -1
        static let imageMaxWidth: CGFloat = 320
        static let imageMaxHeight: CGFloat = 260
        
        static let listPrefixColor = UIColor.secondaryLabel
        static let checkboxUncheckedColor = UIColor.tertiaryLabel
        static let checkboxCheckedColor = UIColor(Color.accentPrimary)
        static let quoteBarColor = UIColor(Color.accentPrimary)
        static let codeColor = UIColor.systemPurple
        static let codeBgColor = UIColor.systemGray6
        
        // Paragraph Styles
        static func baseStyle() -> NSMutableParagraphStyle {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 6
            style.paragraphSpacing = 12
            return style
        }

        static func checkboxStyle() -> NSMutableParagraphStyle {
            let style = baseStyle()
            style.headIndent = 24
            style.firstLineHeadIndent = 0
            return style
        }

        static func headerStyle(level: Int) -> NSMutableParagraphStyle {
            let style = baseStyle()
            switch level {
            case 1:
                style.paragraphSpacingBefore = 16
            case 2, 3:
                style.paragraphSpacingBefore = 12
            default:
                break
            }
            return style
        }
    }
    
    // MARK: - Custom Attributes Keys
    
    enum Key {
        static let headerLevel = NSAttributedString.Key("richTextHeaderLevel")
        static let checkbox = NSAttributedString.Key("richTextCheckbox") // Bool
        static let bullet = NSAttributedString.Key("richTextBullet") // Bool
        static let orderedList = NSAttributedString.Key("richTextOrderedList") // String (e.g. "1.")
        static let blockquote = NSAttributedString.Key("richTextBlockquote") // Bool
        static let divider = NSAttributedString.Key("richTextDivider") // Bool
        static let imageURL = NSAttributedString.Key("richTextImageURL") // String
        static let inlineCode = NSAttributedString.Key("richTextInlineCode") // Bool
    }
    
    // MARK: - Markdown -> AttributedString
    
    static func markdownToAttributedString(_ markdown: String, baseFont: UIFont = .systemFont(ofSize: Config.baseFontSize), textColor: UIColor = .label) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let normalizedLineEndings = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{2028}", with: "\n")
            .replacingOccurrences(of: "\u{2029}", with: "\n")
        let lines = normalizedLineEndings.components(separatedBy: "\n")
        
        for (index, line) in lines.enumerated() {
            let parsedLine = parseLine(line, baseFont: baseFont, textColor: textColor)
            result.append(parsedLine)

            if index < lines.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: [
                    .font: baseFont,
                    .foregroundColor: textColor,
                    .paragraphStyle: Config.baseStyle()
                ]))
            }
        }
        
        return result
    }

    private static func parseLine(_ line: String, baseFont: UIFont, textColor: UIColor) -> NSAttributedString {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let paragraphStyle = Config.baseStyle()

        if let imageURL = parseMarkdownImageURL(from: trimmed) {
            return parseImage(urlString: imageURL, paragraphStyle: paragraphStyle)
        }
        
        // --- Headers ---
        if trimmed.hasPrefix("### ") {
            return parseHeader(String(trimmed.dropFirst(4)), level: 3, textColor: textColor, paragraphStyle: paragraphStyle)
        } else if trimmed.hasPrefix("## ") {
            return parseHeader(String(trimmed.dropFirst(3)), level: 2, textColor: textColor, paragraphStyle: paragraphStyle)
        } else if trimmed.hasPrefix("# ") {
            return parseHeader(String(trimmed.dropFirst(2)), level: 1, textColor: textColor, paragraphStyle: paragraphStyle)
        }
        
        // --- Checkboxes ---
        if trimmed == "- [ ]" || trimmed.hasPrefix("- [ ] ") {
            let content = trimmed == "- [ ]" ? "" : String(trimmed.dropFirst(6))
            return parseCheckbox(content, checked: false, baseFont: baseFont, textColor: textColor, paragraphStyle: paragraphStyle)
        } else if trimmed == "- [x]" || trimmed == "- [X]"
                    || trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
            let content = trimmed.count == 5 ? "" : String(trimmed.dropFirst(6))
            return parseCheckbox(content, checked: true, baseFont: baseFont, textColor: textColor, paragraphStyle: paragraphStyle)
        }
        
        // --- Bullets ---
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("• ") || trimmed.hasPrefix("* ") {
            let content: String
            if trimmed.hasPrefix("- ") {
                content = String(trimmed.dropFirst(2))
            } else if trimmed.hasPrefix("* ") {
                 content = String(trimmed.dropFirst(2))
            } else {
                 content = String(trimmed.dropFirst(2))
            }
            return parseBullet(content, baseFont: baseFont, textColor: textColor, paragraphStyle: paragraphStyle)
        }
        
        // --- Numbered List ---
        // matches "1. ", "2. ", etc
        if let range = trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) {
             let prefix = String(trimmed[range])
             let content = String(trimmed[range.upperBound...])
             return parseOrderedList(content, prefix: prefix, baseFont: baseFont, textColor: textColor, paragraphStyle: paragraphStyle)
        }
        
        // --- Blockquote ---
        if trimmed.hasPrefix("> ") {
            return parseBlockquote(String(trimmed.dropFirst(2)), baseFont: baseFont, textColor: textColor, paragraphStyle: paragraphStyle)
        }
        
        // --- Divider ---
        if trimmed == "---" || trimmed == "***" || trimmed == "___" {
            return parseDivider(paragraphStyle: paragraphStyle)
        }
        
        // --- Regular Text ---
        return parseInlineFormatting(line, baseFont: baseFont, textColor: textColor, paragraphStyle: paragraphStyle)
    }
    
    // --- Parsing Helpers ---
    
    private static func parseHeader(_ text: String, level: Int, textColor: UIColor, paragraphStyle: NSMutableParagraphStyle) -> NSAttributedString {
        let fontSize: CGFloat
        let fontWeight: UIFont.Weight
        let headerStyle = Config.headerStyle(level: level)
        
        switch level {
        case 1:
            fontSize = Config.h1Size
            fontWeight = .bold
        case 2:
            fontSize = Config.h2Size
            fontWeight = .semibold
        default:
            fontSize = Config.h3Size
            fontWeight = .semibold
        }
        
        let font = UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
        let attrText = parseInlineFormatting(text, baseFont: font, textColor: textColor, paragraphStyle: headerStyle)
        let result = NSMutableAttributedString(attributedString: attrText)
        
        result.addAttribute(Key.headerLevel, value: level, range: NSRange(location: 0, length: result.length))
        
        return result
    }
    
    private static func parseCheckbox(_ text: String, checked: Bool, baseFont: UIFont, textColor: UIColor, paragraphStyle: NSMutableParagraphStyle) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let checkboxStyle = Config.checkboxStyle()

        result.append(makeCheckboxPrefix(
            checked: checked,
            baseFont: baseFont,
            paragraphStyle: checkboxStyle
        ))
        
        // Content
        let contentColor = checked ? UIColor.secondaryLabel : textColor
        let contentText = parseInlineFormatting(text, baseFont: baseFont, textColor: contentColor, paragraphStyle: checkboxStyle)
        let mutableContent = NSMutableAttributedString(attributedString: contentText)
        
        if checked {
            mutableContent.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: mutableContent.length))
        }
        result.append(mutableContent)
        
        return result
    }
    
    private static func parseBullet(_ text: String, baseFont: UIFont, textColor: UIColor, paragraphStyle: NSMutableParagraphStyle) -> NSAttributedString {
        let style = paragraphStyle
        style.headIndent = 20
        style.firstLineHeadIndent = 0
        
        let result = NSMutableAttributedString()
        
        let bulletAttrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: Config.listPrefixColor,
            .paragraphStyle: style,
            Key.bullet: true
        ]
        result.append(NSAttributedString(string: "• ", attributes: bulletAttrs))
        
        result.append(parseInlineFormatting(text, baseFont: baseFont, textColor: textColor, paragraphStyle: style))
        return result
    }
    
    private static func parseOrderedList(_ text: String, prefix: String, baseFont: UIFont, textColor: UIColor, paragraphStyle: NSMutableParagraphStyle) -> NSAttributedString {
        let style = paragraphStyle
        style.headIndent = 24
        style.firstLineHeadIndent = 0
        
        let result = NSMutableAttributedString()
        
        // Number part "1. "
        let numberAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: baseFont.pointSize, weight: .medium),
            .foregroundColor: Config.listPrefixColor,
            .paragraphStyle: style,
            Key.orderedList: prefix // Persist the number used
        ]
        result.append(NSAttributedString(string: prefix, attributes: numberAttrs))
        
        result.append(parseInlineFormatting(text, baseFont: baseFont, textColor: textColor, paragraphStyle: style))
        return result
    }
    
    private static func parseBlockquote(_ text: String, baseFont: UIFont, textColor: UIColor, paragraphStyle: NSMutableParagraphStyle) -> NSAttributedString {
        let style = paragraphStyle
        style.headIndent = 16
        style.firstLineHeadIndent = 16
        
        let result = NSMutableAttributedString()
        
        // Bar
        let barAttrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: Config.quoteBarColor,
            .paragraphStyle: style,
            Key.blockquote: true
        ]
        result.append(NSAttributedString(string: "│ ", attributes: barAttrs))
        
        // Content
        let quoteFont = UIFont.systemFont(ofSize: baseFont.pointSize)
        // Note: Inline formatting might override these info, but we apply base first
        let content = parseInlineFormatting(text, baseFont: quoteFont, textColor: UIColor.secondaryLabel, paragraphStyle: style)
        // Re-apply background to ensure it covers
        let mutableContent = NSMutableAttributedString(attributedString: content)
        mutableContent.addAttributes([.backgroundColor: Config.codeBgColor], range: NSRange(location: 0, length: mutableContent.length))
        
        result.append(mutableContent)
        return result
    }

    private static func parseDivider(paragraphStyle: NSMutableParagraphStyle) -> NSAttributedString {
        let style = paragraphStyle
        style.paragraphSpacingBefore = 8
        style.paragraphSpacing = 8
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.tertiaryLabel,
            .paragraphStyle: style,
            Key.divider: true
        ]
        // Using a visual line
        return NSAttributedString(string: "─────────────────────────", attributes: attrs)
    }

    private static func parseImage(urlString: String, paragraphStyle: NSParagraphStyle) -> NSAttributedString {
        let attachment = NSTextAttachment()
        attachment.image = loadMarkdownImage(from: urlString)
        if let image = attachment.image {
            attachment.bounds = imageBounds(for: image.size)
        }

        let result = NSMutableAttributedString(attachment: attachment)
        result.addAttributes([
            .paragraphStyle: paragraphStyle,
            Key.imageURL: urlString
        ], range: NSRange(location: 0, length: result.length))
        return result
    }

    private static func parseMarkdownImageURL(from line: String) -> String? {
        guard line.hasPrefix("![]("), line.hasSuffix(")") else { return nil }
        let start = line.index(line.startIndex, offsetBy: 4)
        let end = line.index(before: line.endIndex)
        let urlString = String(line[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
        return urlString.isEmpty ? nil : urlString
    }

    private static func loadMarkdownImage(from urlString: String) -> UIImage? {
        guard let url = URL(string: urlString), url.isFileURL else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    private static func imageBounds(for size: CGSize) -> CGRect {
        guard size.width > 0, size.height > 0 else {
            return CGRect(x: 0, y: 0, width: Config.imageMaxWidth, height: Config.imageMaxHeight)
        }

        let scale = min(
            Config.imageMaxWidth / size.width,
            Config.imageMaxHeight / size.height,
            1
        )
        return CGRect(x: 0, y: 0, width: size.width * scale, height: size.height * scale)
    }
    
    private static func parseInlineFormatting(_ text: String, baseFont: UIFont, textColor: UIColor, paragraphStyle: NSParagraphStyle) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var currentIndex = text.startIndex
        
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
        
        while currentIndex < text.endIndex {
            let remaining = text[currentIndex...]

            // Escaped Markdown punctuation is literal text. This is especially
            // important for paste-and-match-style, where copied "# text" must
            // stay regular text after reopening the note.
            if remaining.hasPrefix("\\"), text.index(after: currentIndex) < text.endIndex {
                let escapedIndex = text.index(after: currentIndex)
                result.append(NSAttributedString(string: String(text[escapedIndex]), attributes: baseAttrs))
                currentIndex = text.index(after: escapedIndex)
                continue
            }

            // Bold **
            if remaining.hasPrefix("**"), let end = text.range(of: "**", range: text.index(currentIndex, offsetBy: 2)..<text.endIndex)?.lowerBound {
                let content = unescapeInlineText(String(text[text.index(currentIndex, offsetBy: 2)..<end]))
                let boldFont = applyTrait(.traitBold, to: baseFont)
                var attrs = baseAttrs
                attrs[.font] = boldFont
                result.append(NSAttributedString(string: content, attributes: attrs))
                currentIndex = text.index(end, offsetBy: 2)
                continue
            }
            
            // Legacy italic markdown *text* -> plain text (italic feature removed)
            if remaining.hasPrefix("*"), !remaining.hasPrefix("**"), let end = text.range(of: "*", range: text.index(currentIndex, offsetBy: 1)..<text.endIndex)?.lowerBound {
                let content = unescapeInlineText(String(text[text.index(currentIndex, offsetBy: 1)..<end]))
                result.append(NSAttributedString(string: content, attributes: baseAttrs))
                currentIndex = text.index(end, offsetBy: 1)
                continue
            }
            
            // Code `
            if remaining.hasPrefix("`"), let end = text.range(of: "`", range: text.index(currentIndex, offsetBy: 1)..<text.endIndex)?.lowerBound {
                let content = unescapeInlineText(String(text[text.index(currentIndex, offsetBy: 1)..<end]))
                let codeFont = UIFont.monospacedSystemFont(ofSize: baseFont.pointSize - 1, weight: .regular)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: codeFont,
                    .foregroundColor: Config.codeColor,
                    .backgroundColor: Config.codeBgColor,
                    .paragraphStyle: paragraphStyle,
                    Key.inlineCode: true
                ]
                result.append(NSAttributedString(string: content, attributes: attrs))
                currentIndex = text.index(end, offsetBy: 1)
                continue
            }
            
            // Regular char
            result.append(NSAttributedString(string: String(text[currentIndex]), attributes: baseAttrs))
            currentIndex = text.index(after: currentIndex)
        }
        
        return result
    }
    
    // MARK: - AttributedString -> Markdown
    
    static func attributedStringToMarkdown(_ attr: NSAttributedString) -> String {
        serializationSnapshot(from: attr).markdown
    }

    private struct MarkdownBuffer {
        private(set) var value = ""
        private(set) var characterCount = 0

        mutating func append(_ string: String) {
            value.append(contentsOf: string)
            characterCount += string.count
        }

        mutating func append(_ character: Character) {
            value.append(character)
            characterCount += 1
        }
    }

    static func serializationSnapshot(from attr: NSAttributedString) -> RichTextSerializationSnapshot {
        let source = attr.string as NSString
        var markdown = MarkdownBuffer()
        var mapping = Array(repeating: 0, count: attr.length + 1)
        var selectionEndMapping = Array(repeating: 0, count: attr.length + 1)
        var lineStart = 0

        while lineStart < source.length {
            let fullLineRange = source.lineRange(for: NSRange(location: lineStart, length: 0))
            let hasNewline = fullLineRange.length > 0
                && source.substring(with: NSRange(location: fullLineRange.upperBound - 1, length: 1)) == "\n"
            let contentRange = NSRange(
                location: fullLineRange.location,
                length: fullLineRange.length - (hasNewline ? 1 : 0)
            )
            appendLine(
                from: attr,
                range: contentRange,
                markdown: &markdown,
                mapping: &mapping,
                selectionEndMapping: &selectionEndMapping
            )

            if hasNewline {
                mapping[contentRange.upperBound] = markdown.characterCount
                markdown.append("\n")
                mapping[fullLineRange.upperBound] = markdown.characterCount
                selectionEndMapping[fullLineRange.upperBound] = markdown.characterCount
            }
            lineStart = fullLineRange.upperBound
        }

        if attr.length == 0 {
            mapping[0] = 0
            selectionEndMapping[0] = 0
        } else if lineStart == attr.length {
            mapping[attr.length] = markdown.characterCount
        }

        return RichTextSerializationSnapshot(
            markdown: markdown.value,
            visualBoundaryToMarkdownCharacterOffset: mapping,
            visualBoundaryToMarkdownSelectionEndOffset: selectionEndMapping
        )
    }

    private enum InlineStyle: Equatable {
        case plain
        case bold
        case code
    }

    private static func appendLine(
        from attr: NSAttributedString,
        range: NSRange,
        markdown: inout MarkdownBuffer,
        mapping: inout [Int],
        selectionEndMapping: inout [Int]
    ) {
        guard range.length > 0 else {
            mapping[range.location] = markdown.characterCount
            selectionEndMapping[range.location] = markdown.characterCount
            return
        }

        let attributes = attr.attributes(at: range.location, effectiveRange: nil)
        if let imageURL = attributes[Key.imageURL] as? String {
            mapping[range.location] = markdown.characterCount
            selectionEndMapping[range.location] = markdown.characterCount
            markdown.append("![](\(imageURL))")
            mapping[range.upperBound] = markdown.characterCount
            selectionEndMapping[range.upperBound] = markdown.characterCount
            return
        }

        if attributes[Key.divider] != nil {
            let start = markdown.characterCount
            markdown.append("---")
            for boundary in range.location...range.upperBound {
                mapping[boundary] = boundary == range.upperBound ? markdown.characterCount : start
                selectionEndMapping[boundary] = mapping[boundary]
            }
            return
        }

        var contentRange = range
        var ignoreBold = false
        var escapeBlockPrefix = false

        if let level = attributes[Key.headerLevel] as? Int {
            markdown.append(String(repeating: "#", count: level) + " ")
            mapping[range.location] = markdown.characterCount
            selectionEndMapping[range.location] = markdown.characterCount
            ignoreBold = true
        } else if let checked = attributes[Key.checkbox] as? Bool {
            let prefix = checked ? "- [x] " : "- [ ] "
            appendVisualPrefix(
                sourcePrefix: prefix,
                visualLength: min(2, contentRange.length),
                lineRange: &contentRange,
                markdown: &markdown,
                mapping: &mapping,
                selectionEndMapping: &selectionEndMapping
            )
        } else if attributes[Key.bullet] != nil {
            appendVisualPrefix(
                sourcePrefix: "- ",
                visualLength: min(2, contentRange.length),
                lineRange: &contentRange,
                markdown: &markdown,
                mapping: &mapping,
                selectionEndMapping: &selectionEndMapping
            )
        } else if let prefix = attributes[Key.orderedList] as? String {
            appendVisualPrefix(
                sourcePrefix: prefix,
                visualLength: min((prefix as NSString).length, contentRange.length),
                lineRange: &contentRange,
                markdown: &markdown,
                mapping: &mapping,
                selectionEndMapping: &selectionEndMapping
            )
        } else if attributes[Key.blockquote] != nil {
            appendVisualPrefix(
                sourcePrefix: "> ",
                visualLength: min(2, contentRange.length),
                lineRange: &contentRange,
                markdown: &markdown,
                mapping: &mapping,
                selectionEndMapping: &selectionEndMapping
            )
        } else {
            escapeBlockPrefix = needsEscapedBlockPrefix(
                (attr.string as NSString).substring(with: contentRange)
            )
        }

        appendInline(
            from: attr,
            range: contentRange,
            ignoreBold: ignoreBold,
            escapeBlockPrefix: escapeBlockPrefix,
            markdown: &markdown,
            mapping: &mapping,
            selectionEndMapping: &selectionEndMapping
        )
    }

    private static func appendVisualPrefix(
        sourcePrefix: String,
        visualLength: Int,
        lineRange: inout NSRange,
        markdown: inout MarkdownBuffer,
        mapping: inout [Int],
        selectionEndMapping: inout [Int]
    ) {
        let start = lineRange.location
        mapping[start] = markdown.characterCount
        selectionEndMapping[start] = markdown.characterCount
        let markdownStart = markdown.characterCount
        markdown.append(sourcePrefix)
        let markdownEnd = markdown.characterCount
        let sourceLength = markdownEnd - markdownStart
        let visualEnd = start + visualLength
        if visualLength > 0 {
            for boundary in (start + 1)...visualEnd {
                let visualOffset = boundary - start
                let sourceOffset: Int
                if visualLength == sourceLength {
                    sourceOffset = visualOffset
                } else if visualOffset == visualLength {
                    sourceOffset = sourceLength
                } else {
                    // Collapsed prefixes keep the trailing space as its own
                    // visual character. Map the checkbox glyph to the Markdown
                    // prefix before that space, and the following boundary to
                    // the true start of the item content.
                    sourceOffset = max(0, sourceLength - 1)
                }
                mapping[boundary] = markdownStart + sourceOffset
                selectionEndMapping[boundary] = markdownStart + sourceOffset
            }
        }
        lineRange = NSRange(location: visualEnd, length: lineRange.length - visualLength)
    }

    private static func appendInline(
        from attr: NSAttributedString,
        range: NSRange,
        ignoreBold: Bool,
        escapeBlockPrefix: Bool,
        markdown: inout MarkdownBuffer,
        mapping: inout [Int],
        selectionEndMapping: inout [Int]
    ) {
        guard range.length > 0 else {
            mapping[range.location] = markdown.characterCount
            selectionEndMapping[range.location] = markdown.characterCount
            return
        }

        let nsText = attr.string as NSString
        var cursor = range.location
        var activeStyle: InlineStyle?
        var isFirstCharacter = true

        while cursor < range.upperBound {
            let characterRange = NSIntersectionRange(
                nsText.rangeOfComposedCharacterSequence(at: cursor),
                range
            )
            let attributes = attr.attributes(at: cursor, effectiveRange: nil)
            let style = inlineStyle(attributes: attributes, ignoreBold: ignoreBold)

            // A visual boundary at the end of styled text has two valid
            // Markdown positions: selections end before the closing marker,
            // while a caret starts after it. Keep both affinities explicitly.
            selectionEndMapping[characterRange.location] = markdown.characterCount
            if style != activeStyle {
                if let activeStyle {
                    markdown.append(closingMarker(for: activeStyle))
                }
                activeStyle = style
                markdown.append(openingMarker(for: style))
            }

            if isFirstCharacter && escapeBlockPrefix {
                markdown.append("\\")
            }
            mapping[characterRange.location] = markdown.characterCount

            let rawCharacter = nsText.substring(with: characterRange)
            markdown.append(escapedInlineText(rawCharacter, style: style))
            if characterRange.length > 1 {
                for boundary in (characterRange.location + 1)..<characterRange.upperBound {
                    mapping[boundary] = mapping[characterRange.location]
                    selectionEndMapping[boundary] = selectionEndMapping[characterRange.location]
                }
            }
            mapping[characterRange.upperBound] = markdown.characterCount
            selectionEndMapping[characterRange.upperBound] = markdown.characterCount
            cursor = characterRange.upperBound
            isFirstCharacter = false
        }

        if let activeStyle {
            markdown.append(closingMarker(for: activeStyle))
            mapping[range.upperBound] = markdown.characterCount
        }
    }

    private static func inlineStyle(
        attributes: [NSAttributedString.Key: Any],
        ignoreBold: Bool
    ) -> InlineStyle {
        if attributes[Key.inlineCode] != nil {
            return .code
        }
        if !ignoreBold,
           (attributes[.font] as? UIFont)?.fontDescriptor.symbolicTraits.contains(.traitBold) == true {
            return .bold
        }
        return .plain
    }

    private static func openingMarker(for style: InlineStyle) -> String {
        switch style {
        case .plain: ""
        case .bold: "**"
        case .code: "`"
        }
    }

    private static func closingMarker(for style: InlineStyle) -> String {
        openingMarker(for: style)
    }

    private static func escapedInlineText(_ text: String, style: InlineStyle) -> String {
        var result = text.replacingOccurrences(of: "\\", with: "\\\\")
        switch style {
        case .plain, .bold:
            result = result
                .replacingOccurrences(of: "*", with: "\\*")
                .replacingOccurrences(of: "`", with: "\\`")
        case .code:
            result = result.replacingOccurrences(of: "`", with: "\\`")
        }
        return result
    }

    private static func needsEscapedBlockPrefix(_ text: String) -> Bool {
        text.range(of: #"^(#{1,3}\s|[-*>]\s|\d+\.\s|-\s\[[ xX]\]\s|!\[\]\(|---$|\*\*\*$|___$)"#, options: .regularExpression) != nil
    }

    private static func unescapeInlineText(_ text: String) -> String {
        var result = ""
        var isEscaping = false
        for character in text {
            if isEscaping {
                result.append(character)
                isEscaping = false
            } else if character == "\\" {
                isEscaping = true
            } else {
                result.append(character)
            }
        }
        if isEscaping {
            result.append("\\")
        }
        return result
    }

    // --- Helpers ---

    private static func applyTrait(_ trait: UIFontDescriptor.SymbolicTraits, to font: UIFont) -> UIFont {
        if let descriptor = font.fontDescriptor.withSymbolicTraits(trait) {
            return UIFont(descriptor: descriptor, size: font.pointSize)
        }
        return font
    }

    static func makeCheckboxPrefix(
        checked: Bool,
        baseFont: UIFont,
        paragraphStyle: NSParagraphStyle
    ) -> NSAttributedString {
        let symbol = checked ? Config.checkboxCheckedSymbol : Config.checkboxUncheckedSymbol
        let symbolFont = UIFont.systemFont(
            ofSize: baseFont.pointSize + Config.checkboxSymbolFontSizeOffset,
            weight: checked ? .semibold : .regular
        )
        let result = NSMutableAttributedString(string: symbol, attributes: [
            .font: symbolFont,
            .foregroundColor: checked ? Config.checkboxCheckedColor : Config.checkboxUncheckedColor,
            .baselineOffset: Config.checkboxBaselineOffset,
            .paragraphStyle: paragraphStyle,
            Key.checkbox: checked
        ])
        result.append(NSAttributedString(string: " ", attributes: [
            .font: baseFont,
            .paragraphStyle: paragraphStyle
        ]))
        return result
    }

}
