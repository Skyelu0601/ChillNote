import UIKit

/// Owns editor-only mutations so UITextView, paste handling and SwiftUI updates
/// use the same normalization and selection rules.
final class MarkdownEditorSession {
    private(set) var baseFont: UIFont
    private(set) var textColor: UIColor

    init(baseFont: UIFont, textColor: UIColor) {
        self.baseFont = baseFont
        self.textColor = textColor
    }

    func updateTheme(baseFont: UIFont, textColor: UIColor) {
        self.baseFont = baseFont
        self.textColor = textColor
    }

    func applyExternalMarkdown(
        _ markdown: String,
        to textView: UITextView,
        markdownSelection: RichTextEditorSelection?
    ) -> RichTextSerializationSnapshot {
        let rendered = RichTextConverter.markdownToAttributedString(
            markdown,
            baseFont: baseFont,
            textColor: textColor
        )
        textView.attributedText = rendered

        let snapshot = RichTextConverter.serializationSnapshot(from: rendered)
        if let markdownSelection {
            textView.selectedRange = snapshot.visualRange(
                forMarkdownLocation: markdownSelection.location,
                length: markdownSelection.length
            )
        } else {
            textView.selectedRange = NSRange(
                location: min(textView.selectedRange.location, rendered.length),
                length: 0
            )
        }

        normalizeTypingAttributes(in: textView)
        return snapshot
    }

    func pastePlainText(_ source: String, into textView: UITextView) {
        let normalized = Self.normalizePastedText(source)
        guard !normalized.isEmpty else { return }

        let selection = bounded(textView.selectedRange, upperBound: textView.textStorage.length)
        let insertion = attributedPaste(normalized, in: textView, at: selection.location)
        replace(
            selection,
            with: insertion,
            in: textView,
            selectionAfterEdit: NSRange(location: selection.location + insertion.length, length: 0)
        )
    }

    private func replace(
        _ range: NSRange,
        with replacement: NSAttributedString,
        in textView: UITextView,
        selectionAfterEdit: NSRange
    ) {
        let oldText = textView.textStorage.attributedSubstring(from: range)
        let inverseRange = NSRange(location: range.location, length: replacement.length)

        textView.undoManager?.registerUndo(withTarget: self) { [weak textView] session in
            guard let textView else { return }
            session.replace(
                inverseRange,
                with: oldText,
                in: textView,
                selectionAfterEdit: NSRange(location: range.location + oldText.length, length: 0)
            )
        }
        textView.textStorage.beginEditing()
        textView.textStorage.replaceCharacters(in: range, with: replacement)
        textView.textStorage.endEditing()
        textView.selectedRange = selectionAfterEdit
        normalizeTypingAttributes(in: textView)
        textView.delegate?.textViewDidChange?(textView)
    }

    func normalizeTypingAttributes(in textView: UITextView) {
        let location = min(textView.selectedRange.location, textView.textStorage.length)
        let paragraphStyle = paragraphStyle(at: location, in: textView)
        let font = inlineFont(at: location, in: textView) ?? baseFont
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
    }

    static func normalizePastedText(_ source: String) -> String {
        let normalizedLineEndings = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{2028}", with: "\n")
            .replacingOccurrences(of: "\u{2029}", with: "\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ")

        // External apps commonly separate every paragraph with one or more
        // literal blank lines. The editor already supplies natural paragraph
        // spacing, so those empty paragraphs make pasted text look enormous.
        // Normalize only the paste payload; user-created blank lines already
        // in the note remain untouched and round-trip through Markdown.
        let lines = normalizedLineEndings.components(separatedBy: "\n")
        let contentIndices = lines.indices.filter {
            !lines[$0].trimmingCharacters(in: .whitespaces).isEmpty
        }
        guard let firstContentIndex = contentIndices.first,
              let lastContentIndex = contentIndices.last else {
            return normalizedLineEndings.contains("\n") ? "\n" : ""
        }

        var compacted: [String] = []
        if firstContentIndex > lines.startIndex {
            compacted.append("")
        }
        compacted.append(contentsOf: contentIndices.map { lines[$0] })
        if lastContentIndex < lines.index(before: lines.endIndex) {
            compacted.append("")
        }
        return compacted.joined(separator: "\n")
    }

    private func attributedPaste(_ text: String, in textView: UITextView, at location: Int) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let firstParagraphStyle = paragraphStyle(at: location, in: textView)
        let firstFont = inlineFont(at: location, in: textView) ?? baseFont
        let lines = text.components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            let isFirstLine = index == 0
            let attributes: [NSAttributedString.Key: Any] = [
                .font: isFirstLine ? firstFont : baseFont,
                .foregroundColor: textColor,
                .paragraphStyle: isFirstLine ? firstParagraphStyle : RichTextConverter.Config.baseStyle()
            ]
            result.append(NSAttributedString(string: line, attributes: attributes))
            if index < lines.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: attributes))
            }
        }

        return result
    }

    private func inlineFont(at location: Int, in textView: UITextView) -> UIFont? {
        if let font = textView.typingAttributes[.font] as? UIFont {
            return normalizedFont(font)
        }
        guard textView.textStorage.length > 0 else { return nil }
        let index = min(max(location - 1, 0), textView.textStorage.length - 1)
        guard let font = textView.textStorage.attribute(.font, at: index, effectiveRange: nil) as? UIFont else {
            return nil
        }
        return normalizedFont(font)
    }

    private func normalizedFont(_ font: UIFont) -> UIFont {
        let traits = font.fontDescriptor.symbolicTraits
        guard traits.contains(.traitBold),
              let descriptor = baseFont.fontDescriptor.withSymbolicTraits(.traitBold) else {
            return baseFont
        }
        return UIFont(descriptor: descriptor, size: baseFont.pointSize)
    }

    private func paragraphStyle(at location: Int, in textView: UITextView) -> NSParagraphStyle {
        guard textView.textStorage.length > 0 else { return RichTextConverter.Config.baseStyle() }
        let index = min(max(location - 1, 0), textView.textStorage.length - 1)
        return (textView.textStorage.attribute(.paragraphStyle, at: index, effectiveRange: nil) as? NSParagraphStyle)
            ?? RichTextConverter.Config.baseStyle()
    }

    private func bounded(_ range: NSRange, upperBound: Int) -> NSRange {
        let location = min(max(range.location, 0), upperBound)
        let length = min(max(range.length, 0), upperBound - location)
        return NSRange(location: location, length: length)
    }
}
