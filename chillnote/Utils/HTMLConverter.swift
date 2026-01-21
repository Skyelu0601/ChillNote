import UIKit

/// Utility class for converting between HTML, Markdown, and NSAttributedString
/// HTML is used as the storage format for cross-platform compatibility
struct HTMLConverter {
    
    // MARK: - HTML to AttributedString
    
    /// Convert HTML string to NSAttributedString for display in UITextView
    static func htmlToAttributedString(_ html: String, baseFont: UIFont = .systemFont(ofSize: 17), textColor: UIColor = .label) -> NSAttributedString? {
        // Wrap HTML with base styling
        let styledHTML = """
        <!DOCTYPE html>
        <html>
        <head>
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                font-size: \(baseFont.pointSize)px;
                color: \(textColor.hexString);
                line-height: 1.5;
            }
            h1 { font-size: 24px; font-weight: bold; margin: 16px 0 8px 0; }
            h2 { font-size: 20px; font-weight: 600; margin: 12px 0 6px 0; }
            h3 { font-size: 17px; font-weight: 600; margin: 10px 0 4px 0; }
            ul, ol { margin: 8px 0; padding-left: 20px; }
            li { margin: 4px 0; }
            blockquote {
                border-left: 3px solid #FF9500;
                padding-left: 12px;
                margin: 8px 0;
                color: #8E8E93;
                font-style: italic;
            }
            code {
                font-family: Menlo, monospace;
                font-size: \(baseFont.pointSize - 1)px;
                background-color: #F2F2F7;
                padding: 2px 4px;
                border-radius: 4px;
            }
            hr {
                border: none;
                border-top: 1px solid #C7C7CC;
                margin: 12px 0;
            }
            .checkbox { font-size: \(baseFont.pointSize + 4)px; }
            .checkbox-checked { color: #34C759; }
            .checkbox-unchecked { color: #FF9500; }
            .strikethrough { text-decoration: line-through; color: #8E8E93; }
        </style>
        </head>
        <body>
        \(html)
        </body>
        </html>
        """
        
        guard let data = styledHTML.data(using: .utf8) else { return nil }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        return try? NSAttributedString(data: data, options: options, documentAttributes: nil)
    }
    
    // MARK: - AttributedString to HTML
    
    /// Convert NSAttributedString to HTML for storage
    static func attributedStringToHTML(_ attributedString: NSAttributedString) -> String? {
        let documentAttributes: [NSAttributedString.DocumentAttributeKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        guard let htmlData = try? attributedString.data(
            from: NSRange(location: 0, length: attributedString.length),
            documentAttributes: documentAttributes
        ) else { return nil }
        
        var html = String(data: htmlData, encoding: .utf8)
        
        // Clean up the HTML - remove unnecessary elements added by iOS
        html = html?.replacingOccurrences(of: "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01//EN\" \"http://www.w3.org/TR/html4/strict.dtd\">", with: "")
        
        return html
    }
    
    // MARK: - Markdown to HTML
    
    /// Convert Markdown to HTML (for AI-generated content)
    static func markdownToHTML(_ markdown: String) -> String {
        var html = ""
        let lines = markdown.components(separatedBy: "\n")
        var inList = false
        var listType: ListType? = nil
        
        enum ListType {
            case unordered, ordered, checkbox
        }
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Close previous list if needed
            let isListItem = trimmed.hasPrefix("- ") || trimmed.hasPrefix("• ") || 
                             trimmed.hasPrefix("- [ ] ") || trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") ||
                             trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil
            
            if inList && !isListItem {
                html += listType == .ordered ? "</ol>\n" : "</ul>\n"
                inList = false
                listType = nil
            }
            
            // Headers
            if trimmed.hasPrefix("### ") {
                let content = parseInlineMarkdown(String(trimmed.dropFirst(4)))
                html += "<h3>\(content)</h3>\n"
            }
            else if trimmed.hasPrefix("## ") {
                let content = parseInlineMarkdown(String(trimmed.dropFirst(3)))
                html += "<h2>\(content)</h2>\n"
            }
            else if trimmed.hasPrefix("# ") {
                let content = parseInlineMarkdown(String(trimmed.dropFirst(2)))
                html += "<h1>\(content)</h1>\n"
            }
            // Checkbox items
            else if trimmed.hasPrefix("- [ ] ") {
                if !inList || listType != .checkbox {
                    if inList { html += "</ul>\n" }
                    html += "<ul class=\"checklist\">\n"
                    inList = true
                    listType = .checkbox
                }
                let content = parseInlineMarkdown(String(trimmed.dropFirst(6)))
                html += "<li><span class=\"checkbox checkbox-unchecked\" data-checked=\"false\">☐</span> \(content)</li>\n"
            }
            else if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
                if !inList || listType != .checkbox {
                    if inList { html += "</ul>\n" }
                    html += "<ul class=\"checklist\">\n"
                    inList = true
                    listType = .checkbox
                }
                let content = parseInlineMarkdown(String(trimmed.dropFirst(6)))
                html += "<li><span class=\"checkbox checkbox-checked\" data-checked=\"true\">☑</span> <span class=\"strikethrough\">\(content)</span></li>\n"
            }
            // Unordered list
            else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("• ") {
                if !inList || listType != .unordered {
                    if inList { html += "</ul>\n" }
                    html += "<ul>\n"
                    inList = true
                    listType = .unordered
                }
                let content = parseInlineMarkdown(String(trimmed.dropFirst(2)))
                html += "<li>\(content)</li>\n"
            }
            // Ordered list
            else if let match = trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                if !inList || listType != .ordered {
                    if inList { html += listType == .ordered ? "</ol>\n" : "</ul>\n" }
                    html += "<ol>\n"
                    inList = true
                    listType = .ordered
                }
                let content = parseInlineMarkdown(String(trimmed[match.upperBound...]))
                html += "<li>\(content)</li>\n"
            }
            // Blockquote
            else if trimmed.hasPrefix("> ") {
                let content = parseInlineMarkdown(String(trimmed.dropFirst(2)))
                html += "<blockquote>\(content)</blockquote>\n"
            }
            // Divider
            else if trimmed == "---" || trimmed == "═══" || trimmed.hasPrefix("═") {
                html += "<hr>\n"
            }
            // Empty line
            else if trimmed.isEmpty {
                html += "<br>\n"
            }
            // Regular paragraph
            else {
                let content = parseInlineMarkdown(line)
                html += "<p>\(content)</p>\n"
            }
        }
        
        // Close any open list
        if inList {
            html += listType == .ordered ? "</ol>\n" : "</ul>\n"
        }
        
        return html
    }
    
    /// Parse inline Markdown formatting (bold, italic, code)
    private static func parseInlineMarkdown(_ text: String) -> String {
        var result = text
        
        // Escape HTML entities first
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        
        // Bold (**text**)
        result = result.replacingOccurrences(
            of: #"\*\*(.+?)\*\*"#,
            with: "<strong>$1</strong>",
            options: .regularExpression
        )
        
        // Italic (*text*) - but not after **
        result = result.replacingOccurrences(
            of: #"(?<!\*)\*([^\*]+?)\*(?!\*)"#,
            with: "<em>$1</em>",
            options: .regularExpression
        )
        
        // Inline code (`code`)
        result = result.replacingOccurrences(
            of: #"`(.+?)`"#,
            with: "<code>$1</code>",
            options: .regularExpression
        )
        
        return result
    }
    
    // MARK: - AttributedString to Markdown
    
    /// Convert NSAttributedString back to Markdown (for AI interaction)
    static func attributedStringToMarkdown(_ attributedString: NSAttributedString) -> String {
        // For now, just extract plain text
        // A more sophisticated version could analyze attributes and reconstruct markdown
        return attributedString.string
    }
    
    // MARK: - Plain Text Extraction
    
    /// Get plain text from HTML
    static func htmlToPlainText(_ html: String) -> String {
        guard let attributedString = htmlToAttributedString(html) else {
            return html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        }
        return attributedString.string
    }
}

// MARK: - UIColor Extension for Hex String

extension UIColor {
    var hexString: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
    }
}
