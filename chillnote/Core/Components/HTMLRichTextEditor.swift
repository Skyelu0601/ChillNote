import SwiftUI
import UIKit

/// A true rich text editor that works with HTML content
/// Users edit actual formatted text, not markdown that gets rendered
/// This solves cursor position and editing issues
struct HTMLRichTextEditor: UIViewRepresentable {
    @Binding var htmlContent: String
    var isEditable: Bool = true
    var font: UIFont = .systemFont(ofSize: 17)
    var textColor: UIColor = .label
    var bottomInset: CGFloat = 8
    var isScrollEnabled: Bool = true
    var onCheckboxToggle: ((Int, Bool) -> Void)? = nil
    
    func makeUIView(context: Context) -> CheckboxTextView {
        let textView = CheckboxTextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isEditable = isEditable
        textView.isScrollEnabled = isScrollEnabled
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 12, bottom: bottomInset, right: 12)
        textView.font = font
        textView.textColor = textColor
        textView.allowsEditingTextAttributes = true
        
        // Set initial content
        if let attributedString = HTMLConverter.htmlToAttributedString(htmlContent, baseFont: font, textColor: textColor) {
            textView.attributedText = attributedString
        } else {
            // Fallback: treat as plain text
            textView.text = htmlContent
        }
        
        // Setup checkbox tap handler
        textView.onCheckboxTap = { lineIndex, newState in
            onCheckboxToggle?(lineIndex, newState)
        }
        
        if !isScrollEnabled {
            textView.setContentCompressionResistancePriority(.required, for: .vertical)
            textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        
        return textView
    }
    
    func updateUIView(_ textView: CheckboxTextView, context: Context) {
        textView.isEditable = isEditable
        textView.isScrollEnabled = isScrollEnabled
        
        // Only update if content changed externally and user is not editing
        if !context.coordinator.isEditing {
            let currentHTML = HTMLConverter.attributedStringToHTML(textView.attributedText) ?? ""
            
            // Compare and only update if actually different (avoid flicker)
            if normalizeHTML(currentHTML) != normalizeHTML(htmlContent) {
                let selectedRange = textView.selectedRange
                
                if let attributedString = HTMLConverter.htmlToAttributedString(htmlContent, baseFont: font, textColor: textColor) {
                    textView.attributedText = attributedString
                } else {
                    textView.text = htmlContent
                }
                
                // Restore cursor
                if selectedRange.location <= textView.text.count {
                    textView.selectedRange = selectedRange
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    /// Normalize HTML for comparison (remove whitespace differences)
    private func normalizeHTML(_ html: String) -> String {
        return html.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: HTMLRichTextEditor
        var isEditing = false
        
        init(_ parent: HTMLRichTextEditor) {
            self.parent = parent
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            isEditing = true
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            isEditing = false
            saveContent(from: textView)
        }
        
        func textViewDidChange(_ textView: UITextView) {
            saveContent(from: textView)
        }
        
        private func saveContent(from textView: UITextView) {
            if let html = HTMLConverter.attributedStringToHTML(textView.attributedText) {
                parent.htmlContent = html
            } else {
                // Fallback to plain text wrapped in HTML
                parent.htmlContent = "<p>\(textView.text ?? "")</p>"
            }
        }
    }
}

// MARK: - Checkbox-aware TextView

/// Custom UITextView that handles checkbox taps
class CheckboxTextView: UITextView {
    var onCheckboxTap: ((Int, Bool) -> Void)?
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupTapRecognizer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTapRecognizer()
    }
    
    private func setupTapRecognizer() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.delegate = self
        addGestureRecognizer(tap)
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        
        // Check if tapping on a checkbox character
        guard let position = closestPosition(to: location) else { return }
        let charIndex = offset(from: beginningOfDocument, to: position)
        
        let text = self.text ?? ""
        guard charIndex < text.count else { return }
        
        let index = text.index(text.startIndex, offsetBy: charIndex)
        let char = text[index]
        
        // Check if it's a checkbox character
        if char == "☐" || char == "☑" {
            let lineIndex = getLineIndex(for: charIndex)
            let newState = char == "☐" // Will become checked
            
            // Toggle the checkbox
            toggleCheckbox(at: charIndex, to: newState)
            onCheckboxTap?(lineIndex, newState)
        }
    }
    
    private func getLineIndex(for charIndex: Int) -> Int {
        let text = self.text ?? ""
        let prefix = String(text.prefix(charIndex))
        return prefix.components(separatedBy: "\n").count - 1
    }
    
    private func toggleCheckbox(at charIndex: Int, to checked: Bool) {
        guard let attributedText = self.attributedText?.mutableCopy() as? NSMutableAttributedString else { return }
        
        let range = NSRange(location: charIndex, length: 1)
        let newSymbol = checked ? "☑" : "☐"
        let newColor = checked ? UIColor.systemGreen : UIColor.systemOrange
        
        // Replace the checkbox symbol
        let attrs = attributedText.attributes(at: charIndex, effectiveRange: nil)
        var newAttrs = attrs
        newAttrs[.foregroundColor] = newColor
        
        let replacement = NSAttributedString(string: newSymbol, attributes: newAttrs)
        attributedText.replaceCharacters(in: range, with: replacement)
        
        // Update strikethrough for the rest of the line
        let text = self.text ?? ""
        let lineEnd = text.range(of: "\n", range: text.index(text.startIndex, offsetBy: charIndex)..<text.endIndex)?.lowerBound
            ?? text.endIndex
        let lineEndIndex = text.distance(from: text.startIndex, to: lineEnd)
        
        let contentRange = NSRange(location: charIndex + 2, length: lineEndIndex - charIndex - 2)
        if contentRange.length > 0 && contentRange.location + contentRange.length <= attributedText.length {
            if checked {
                attributedText.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: contentRange)
                attributedText.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: contentRange)
            } else {
                attributedText.removeAttribute(.strikethroughStyle, range: contentRange)
                attributedText.addAttribute(.foregroundColor, value: UIColor.label, range: contentRange)
            }
        }
        
        self.attributedText = attributedText
    }
}

extension CheckboxTextView: UIGestureRecognizerDelegate {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let tapGesture = gestureRecognizer as? UITapGestureRecognizer else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
        
        let location = tapGesture.location(in: self)
        guard let position = closestPosition(to: location) else { return false }
        let charIndex = offset(from: beginningOfDocument, to: position)
        
        let text = self.text ?? ""
        guard charIndex < text.count else { return false }
        
        let index = text.index(text.startIndex, offsetBy: charIndex)
        let char = text[index]
        
        // Only intercept if tapping a checkbox
        return char == "☐" || char == "☑"
    }
}

// MARK: - Preview

#if DEBUG
struct HTMLRichTextEditor_Previews: PreviewProvider {
    static var previews: some View {
        HTMLRichTextEditor(
            htmlContent: .constant("""
            <h1>Welcome</h1>
            <p>This is <strong>bold</strong> and <em>italic</em> text.</p>
            <ul>
                <li>First item</li>
                <li>Second item</li>
            </ul>
            <ul class="checklist">
                <li><span class="checkbox checkbox-unchecked">☐</span> Todo item</li>
                <li><span class="checkbox checkbox-checked">☑</span> Done item</li>
            </ul>
            """)
        )
        .padding()
    }
}
#endif
