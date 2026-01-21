import SwiftUI
import UIKit

/// A rich text editor that renders markdown as formatted text (WYSIWYG)
/// Users see formatted rich text instead of raw markdown syntax
/// Checkboxes are interactive and can be toggled by tapping
struct RichTextEditorView: UIViewRepresentable {
    @Binding var text: String
    var isEditable: Bool = true
    var font: UIFont = .systemFont(ofSize: 17)
    var textColor: UIColor = .label
    var bottomInset: CGFloat = 8
    var isScrollEnabled: Bool = true
    
    func makeUIView(context: Context) -> InteractiveTextView {
        let textView = InteractiveTextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isEditable = isEditable
        textView.isScrollEnabled = isScrollEnabled
        
        // Layout configuration
        if !isScrollEnabled {
            textView.setContentCompressionResistancePriority(.required, for: .vertical)
            textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 12, bottom: bottomInset, right: 12)
        
        // Tap handler for checkboxes
        textView.onCheckboxTap = { lineIndex, range in
            context.coordinator.toggleCheckbox(at: range, in: textView)
        }
        
        return textView
    }
    
    func updateUIView(_ textView: InteractiveTextView, context: Context) {
        textView.isEditable = isEditable
        textView.isScrollEnabled = isScrollEnabled
        
        // Update styling if needed (though usually controlled by attributes)
        // We only do a full re-render if the text actually changed from the outside
        // to avoid clobbering the user's cursor while typing.
        if text != context.coordinator.lastKnownMarkdown {
            let attributedText = RichTextConverter.markdownToAttributedString(text, baseFont: font, textColor: textColor)
            textView.attributedText = attributedText
            context.coordinator.lastKnownMarkdown = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditorView
        // Cache to prevent circular updates
        var lastKnownMarkdown: String = ""
        
        init(_ parent: RichTextEditorView) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            // Convert rich text back to markdown
            let markdown = RichTextConverter.attributedStringToMarkdown(textView.attributedText)
            
            // Update bindings
            lastKnownMarkdown = markdown
            parent.text = markdown
        }
        
        func toggleCheckbox(at range: NSRange, in textView: InteractiveTextView) {
            // 1. Get current state
            guard let checkboxState = textView.textStorage.attribute(RichTextConverter.Key.checkbox, at: range.location, effectiveRange: nil) as? Bool else {
                return
            }
            
            // 2. Toggle state
            let newState = !checkboxState
            
            // 3. Update the Attribute directly for instant feedback
            textView.textStorage.addAttribute(RichTextConverter.Key.checkbox, value: newState, range: range)
            
            // 4. Update the visual symbol (CheckBox) as well?
            // The attribute alone doesn't change the text "☑" to "☐".
            // We need to replace the characters in the text storage.
            
            let currentSymbol = (textView.text as NSString).substring(with: range)
            // Range usually covers the symbol e.g. "☑ " (length 2)
            
            let newSymbol = newState ? "☑ " : "☐ "
            let newColor = newState ? RichTextConverter.Config.checkboxCheckedColor : RichTextConverter.Config.checkboxUncheckedColor
            
            // Use replaceCharacters to swap the symbol while keeping attributes?
            // Actually, we must be careful. `textStorage.replaceCharacters` might shift ranges.
            
            textView.textStorage.beginEditing()
            
            // Update symbol string
            textView.textStorage.replaceCharacters(in: range, with: newSymbol)
            
            // Re-apply attributes for the new symbol
            let newRange = NSRange(location: range.location, length: newSymbol.count)
            textView.textStorage.addAttribute(RichTextConverter.Key.checkbox, value: newState, range: newRange)
            textView.textStorage.addAttribute(.foregroundColor, value: newColor, range: newRange)
            
            // Handle Strikethrough for the content
            // The content follows the checkbox. We need to find the extent of the line.
            let lineRange = (textView.text as NSString).lineRange(for: newRange)
            let contentRange = NSRange(location: newRange.upperBound, length: lineRange.upperBound - newRange.upperBound)
            
            if contentRange.length > 0 {
                if newState {
                    textView.textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: contentRange)
                    textView.textStorage.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: contentRange)
                } else {
                    textView.textStorage.removeAttribute(.strikethroughStyle, range: contentRange)
                    textView.textStorage.addAttribute(.foregroundColor, value: parent.textColor, range: contentRange)
                }
            }
            
            textView.textStorage.endEditing()
            
            // 5. Trigger update
            textViewDidChange(textView)
        }
    }
}

// MARK: - Interactive Text View

/// Custom UITextView that detects taps on checkbox attributes
class InteractiveTextView: UITextView {
    // Callback: Line Index is less useful now, we pass the Range of the checkbox itself
    var onCheckboxTap: ((Int, NSRange) -> Void)?
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupTapGesture()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTapGesture()
    }
    
    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGesture.delegate = self
        addGestureRecognizer(tapGesture)
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        
        // Find if we touched a character
        guard let position = closestPosition(to: location) else { return }
        let index = offset(from: beginningOfDocument, to: position)
        
        // Check if there's a checkbox attribute at this index
        if index < textStorage.length {
            // We explicitly look for the custom key we set in Converter
            if textStorage.attribute(RichTextConverter.Key.checkbox, at: index, effectiveRange: nil) != nil {
                
                // Find the full range of this checkbox symbol
                // effectiveRange will give us the range where this specific attribute value applies
                /*
                 Note: attribute(_:at:effectiveRange:) returns the range for that *specific value*.
                 So if we toggle it, the value changes.
                 Ideally we want the range of the symbol "☑ "
                 */
                var range = NSRange(location: 0, length: 0)
                _ = textStorage.attribute(RichTextConverter.Key.checkbox, at: index, effectiveRange: &range)
                
                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                
                // Trigger action
                // We pass 0 as dummy line index, logic is now range-based
                onCheckboxTap?(0, range)
            }
        }
    }
}

extension InteractiveTextView: UIGestureRecognizerDelegate {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let tapGesture = gestureRecognizer as? UITapGestureRecognizer {
            let location = tapGesture.location(in: self)
            
            // Hit test for checkbox
            if let position = closestPosition(to: location) {
                let index = offset(from: beginningOfDocument, to: position)
                if index < textStorage.length {
                    if textStorage.attribute(RichTextConverter.Key.checkbox, at: index, effectiveRange: nil) != nil {
                        return true // Consume tap
                    }
                }
            }
        }
        return false // Pass through to text view for editing cursor
    }
}
