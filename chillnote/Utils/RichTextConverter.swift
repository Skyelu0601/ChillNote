import UIKit

/// Utility for converting between Markdown and NSAttributedString
/// Supports bidirectional conversion for a WYSIWYG editing experience.
struct RichTextConverter {
    
    // MARK: - Constants & Configuration
    
    struct Config {
        static let baseFontSize: CGFloat = 17
        static let h1Size: CGFloat = 24
        static let h2Size: CGFloat = 20
        static let h3Size: CGFloat = 17 // Same as base but bold
        
        static let bulletColor = UIColor.systemOrange
        static let checkboxUncheckedColor = UIColor.systemOrange
        static let checkboxCheckedColor = UIColor.systemGreen
        static let quoteBarColor = UIColor.systemOrange
        static let codeColor = UIColor.systemPurple
        static let codeBgColor = UIColor.systemGray6
        
        // Paragraph Styles
        static func baseStyle() -> NSMutableParagraphStyle {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 6
            style.paragraphSpacing = 12
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
    }
    
    // MARK: - Markdown -> AttributedString
    
    static func markdownToAttributedString(_ markdown: String, baseFont: UIFont = .systemFont(ofSize: Config.baseFontSize), textColor: UIColor = .label) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: "\n")
        
        for (index, line) in lines.enumerated() {
            let parsedLine = parseLine(line, baseFont: baseFont, textColor: textColor)
            result.append(parsedLine)
            
            if index < lines.count - 1 {
                result.append(NSAttributedString(string: "\n"))
            }
        }
        
        return result
    }
    
    private static func parseLine(_ line: String, baseFont: UIFont, textColor: UIColor) -> NSAttributedString {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let paragraphStyle = Config.baseStyle()
        
        // --- Headers ---
        if trimmed.hasPrefix("### ") {
            return parseHeader(String(trimmed.dropFirst(4)), level: 3, textColor: textColor, paragraphStyle: paragraphStyle)
        } else if trimmed.hasPrefix("## ") {
            return parseHeader(String(trimmed.dropFirst(3)), level: 2, textColor: textColor, paragraphStyle: paragraphStyle)
        } else if trimmed.hasPrefix("# ") {
            return parseHeader(String(trimmed.dropFirst(2)), level: 1, textColor: textColor, paragraphStyle: paragraphStyle)
        }
        
        // --- Checkboxes ---
        if trimmed.hasPrefix("- [ ] ") {
            return parseCheckbox(String(trimmed.dropFirst(6)), checked: false, baseFont: baseFont, textColor: textColor, paragraphStyle: paragraphStyle)
        } else if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
            return parseCheckbox(String(trimmed.dropFirst(6)), checked: true, baseFont: baseFont, textColor: textColor, paragraphStyle: paragraphStyle)
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
        
        switch level {
        case 1:
            fontSize = Config.h1Size
            fontWeight = .bold
            paragraphStyle.paragraphSpacingBefore = 16
        case 2:
            fontSize = Config.h2Size
            fontWeight = .semibold
            paragraphStyle.paragraphSpacingBefore = 12
        default:
            fontSize = Config.h3Size
            fontWeight = .semibold
            paragraphStyle.paragraphSpacingBefore = 12
        }
        
        let font = UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
        let attrText = parseInlineFormatting(text, baseFont: font, textColor: textColor, paragraphStyle: paragraphStyle)
        let result = NSMutableAttributedString(attributedString: attrText)
        
        result.addAttribute(Key.headerLevel, value: level, range: NSRange(location: 0, length: result.length))
        
        return result
    }
    
    private static func parseCheckbox(_ text: String, checked: Bool, baseFont: UIFont, textColor: UIColor, paragraphStyle: NSMutableParagraphStyle) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        // Symbol
        let symbol = checked ? "☑ " : "☐ "
        let symbolFont = UIFont.systemFont(ofSize: baseFont.pointSize + 8, weight: .medium)
        let symbolColor = checked ? Config.checkboxCheckedColor : Config.checkboxUncheckedColor
        paragraphStyle.headIndent = 24
        paragraphStyle.firstLineHeadIndent = 0
        
        let symbolAttrs: [NSAttributedString.Key: Any] = [
            .font: symbolFont,
            .foregroundColor: symbolColor,
            .paragraphStyle: paragraphStyle,
            Key.checkbox: checked
        ]
        result.append(NSAttributedString(string: symbol, attributes: symbolAttrs))
        
        // Content
        let contentColor = checked ? UIColor.secondaryLabel : textColor
        let contentText = parseInlineFormatting(text, baseFont: baseFont, textColor: contentColor, paragraphStyle: paragraphStyle)
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
            .foregroundColor: Config.bulletColor,
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
            .foregroundColor: Config.bulletColor,
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
        let quoteFont = UIFont.italicSystemFont(ofSize: baseFont.pointSize)
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
            
            // Bold **
            if remaining.hasPrefix("**"), let end = text.range(of: "**", range: text.index(currentIndex, offsetBy: 2)..<text.endIndex)?.lowerBound {
                let content = String(text[text.index(currentIndex, offsetBy: 2)..<end])
                let boldFont = applyTrait(.traitBold, to: baseFont)
                var attrs = baseAttrs
                attrs[.font] = boldFont
                result.append(NSAttributedString(string: content, attributes: attrs))
                currentIndex = text.index(end, offsetBy: 2)
                continue
            }
            
            // Italic *
            if remaining.hasPrefix("*"), !remaining.hasPrefix("**"), let end = text.range(of: "*", range: text.index(currentIndex, offsetBy: 1)..<text.endIndex)?.lowerBound {
                let content = String(text[text.index(currentIndex, offsetBy: 1)..<end])
                let italicFont = applyTrait(.traitItalic, to: baseFont)
                var attrs = baseAttrs
                attrs[.font] = italicFont
                result.append(NSAttributedString(string: content, attributes: attrs))
                currentIndex = text.index(end, offsetBy: 1)
                continue
            }
            
            // Code `
            if remaining.hasPrefix("`"), let end = text.range(of: "`", range: text.index(currentIndex, offsetBy: 1)..<text.endIndex)?.lowerBound {
                let content = String(text[text.index(currentIndex, offsetBy: 1)..<end])
                let codeFont = UIFont.monospacedSystemFont(ofSize: baseFont.pointSize - 1, weight: .regular)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: codeFont,
                    .foregroundColor: Config.codeColor,
                    .backgroundColor: Config.codeBgColor,
                    .paragraphStyle: paragraphStyle
                ]
                result.append(NSAttributedString(string: " \(content) ", attributes: attrs))
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
        var lines: [String] = []
        let string = attr.string
        
        // Split by newline AND enumerate attributes line by line
        // We use enumerateSubstrings to handle line splitting safely
        string.enumerateSubstrings(in: string.startIndex..<string.endIndex, options: .byLines) { (substring, subRange, enclosingRange, stop) in
            guard let lineText = substring else { return }
            
            // Convert String position to NSRange
            let lineNSRange = NSRange(subRange, in: string)
            
            // We look at the attributes of the first effective character of the line to determine block type
            // (Use safe check in case line is empty)
            if lineNSRange.length > 0 {
                let firstCharAttrs = attr.attributes(at: lineNSRange.location, effectiveRange: nil)
                let markdownLine = processLineToMarkdown(lineText, attributes: firstCharAttrs, fullAttributedLine: attr.attributedSubstring(from: lineNSRange))
                lines.append(markdownLine)
            } else {
                lines.append("") // Empty line
            }
        }
        
        return lines.joined(separator: "\n")
    }
    
    private static func processLineToMarkdown(_ text: String, attributes: [NSAttributedString.Key: Any], fullAttributedLine: NSAttributedString) -> String {
        // 1. Header
        if let level = attributes[Key.headerLevel] as? Int {
            let prefix = String(repeating: "#", count: level)
            let content = inlineToMarkdown(fullAttributedLine, ignoreBold: true) // Headers are bold by default, so don't add **
            return "\(prefix) \(content)"
        }
        
        // 2. Checkbox
        if let isChecked = attributes[Key.checkbox] as? Bool {
            let prefix = isChecked ? "- [x] " : "- [ ] "
            // The text usually contains "☑ " or "☐ " at start, we should strip it
            let contentStr = stripPrefixTokens(text, tokens: ["☑ ", "☐ "])
            let contentAttr = stripPrefixTokenLen(fullAttributedLine, length: text.count - contentStr.count)
            return "\(prefix)\(inlineToMarkdown(contentAttr))"
        }
        
        // 3. Bullet
        if attributes[Key.bullet] != nil {
            let contentStr = stripPrefixTokens(text, tokens: ["• "])
            let contentAttr = stripPrefixTokenLen(fullAttributedLine, length: text.count - contentStr.count)
            return "- \(inlineToMarkdown(contentAttr))"
        }
        
        // 4. Numbered List
        if let prefix = attributes[Key.orderedList] as? String {
             // prefix is like "1. "
             // We need to strip it from the text logic
            let contentStr = stripPrefixTokens(text, tokens: [prefix])
            let contentAttr = stripPrefixTokenLen(fullAttributedLine, length: text.count - contentStr.count)
            return "\(prefix)\(inlineToMarkdown(contentAttr))"
        }
        
        // 5. Blockquote
        if attributes[Key.blockquote] != nil {
            let contentStr = stripPrefixTokens(text, tokens: ["│ "])
            let contentAttr = stripPrefixTokenLen(fullAttributedLine, length: text.count - contentStr.count)
            return "> \(inlineToMarkdown(contentAttr))"
        }
        
        // 6. Divider
        if attributes[Key.divider] != nil {
            return "---"
        }
        
        // 7. Regular Text
        return inlineToMarkdown(fullAttributedLine)
    }
    
    private static func inlineToMarkdown(_ attrStr: NSAttributedString, ignoreBold: Bool = false) -> String {
        var result = ""
        
        attrStr.enumerateAttributes(in: NSRange(location: 0, length: attrStr.length), options: []) { (attrs, range, stop) in
            let rawText = (attrStr.string as NSString).substring(with: range)

            // Check for Code (Purple background/color)
            if let bgColor = attrs[.backgroundColor] as? UIColor, 
               bgColor == Config.codeBgColor { // Basic check
                let codeContent = trimSinglePaddingSpace(rawText)
                result += "`\(codeContent)`"
                return
            }
            
            // Detect Code based on font?
            if let font = attrs[.font] as? UIFont, font.fontName.contains("Mono") {
                 // It's likely code.
                 // The parser added spaces around it: " content "
                 // We trim one space from ends?
                 let codeContent = trimSinglePaddingSpace(rawText)
                 result += "`\(codeContent)`"
                 return
            }
            
            var chunk = rawText
            
            if let font = attrs[.font] as? UIFont {
                let isBold = font.fontDescriptor.symbolicTraits.contains(.traitBold)
                let isItalic = font.fontDescriptor.symbolicTraits.contains(.traitItalic)
                
                if isBold && isItalic && !ignoreBold {
                    chunk = "***\(chunk)***"
                } else if isBold && !ignoreBold {
                     chunk = "**\(chunk)**"
                } else if isItalic {
                     chunk = "*\(chunk)*"
                }
            }
            
            result += chunk
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
    
    private static func stripPrefixTokens(_ text: String, tokens: [String]) -> String {
        for token in tokens {
            if text.hasPrefix(token) {
                return String(text.dropFirst(token.count))
            }
        }
        return text
    }
    
    private static func stripPrefixTokenLen(_ attr: NSAttributedString, length: Int) -> NSAttributedString {
        if length <= 0 { return attr }
        if length >= attr.length { return NSAttributedString() }
        return attr.attributedSubstring(from: NSRange(location: length, length: attr.length - length))
    }

    

    private static func trimSinglePaddingSpace(_ text: String) -> String {
        var result = text
        if result.hasPrefix(" ") {
            result.removeFirst()
        }
        if result.hasSuffix(" ") {
            result.removeLast()
        }
        return result
    }
}
