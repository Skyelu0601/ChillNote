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
        textView.allowsEditingTextAttributes = true
        textView.isScrollEnabled = isScrollEnabled
        
        // Set default font and text color - ensures cursor has correct height when empty
        textView.font = font
        textView.textColor = textColor
        
        // Set typing attributes for new text input
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: RichTextConverter.Config.baseStyle()
        ]
        
        // Layout configuration
        if !isScrollEnabled {
            textView.setContentCompressionResistancePriority(.required, for: .vertical)
            textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 12, bottom: bottomInset, right: 12)
        
        // Setup Toolbar
        let toolbar = EditorFormattingToolbar(textView: textView)
        toolbar.onAction = { action in
            context.coordinator.handleToolbarAction(action, in: textView)
        }
        toolbar.onSelectionChange = { action in
            context.coordinator.handleToolbarAction(action, in: textView)
        }
        textView.inputAccessoryView = toolbar
        
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
        private var pendingInputStyle: PendingInputStyle?

        private struct PendingInputStyle {
            let range: NSRange
            let replacementText: String
            let oldLength: Int
            let typingAttributes: [NSAttributedString.Key: Any]
        }

        private var checkboxParagraphStyle: NSParagraphStyle {
            RichTextConverter.Config.checkboxStyle()
        }

        private func headerParagraphStyle(level: Int) -> NSParagraphStyle {
            RichTextConverter.Config.headerStyle(level: level)
        }
        
        init(_ parent: RichTextEditorView) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            normalizeTypingAttributesForListPrefixIfNeeded(in: textView)
        }
        
        func textViewDidChange(_ textView: UITextView) {
            applyPendingInputStyleIfNeeded(in: textView)
            let markdown = RichTextConverter.attributedStringToMarkdown(textView.attributedText)
            lastKnownMarkdown = markdown
            parent.text = markdown
            if let toolbar = textView.inputAccessoryView as? EditorFormattingToolbar {
                updateToolbarState(in: textView, toolbar: toolbar)
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            normalizeTypingAttributesForListPrefixIfNeeded(in: textView)
            if let toolbar = textView.inputAccessoryView as? EditorFormattingToolbar {
                updateToolbarState(in: textView, toolbar: toolbar)
            }
        }
        
        // MARK: - Smart Enter Logic
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // Check for "Enter" key
            if text == "\n" {
                return handleReturnKey(textView, range: range)
            }
            
            // Check for "Space" key (Auto-format trigger)
            if text == " " {
                if handleAutoFormatting(textView, range: range) {
                    return false
                }
            }
            
            // Check for "Backspace" (Handle deleting list prefix)
            if text == "" && range.length == 1 {
                // Returning true from handleBackspace means we already mutated text manually.
                if handleBackspace(textView, range: range) {
                    return false
                }
            }

            // Keep a snapshot of typing attributes so IME commit text can inherit style reliably.
            if !text.isEmpty {
                pendingInputStyle = PendingInputStyle(
                    range: range,
                    replacementText: text,
                    oldLength: textView.textStorage.length,
                    typingAttributes: textView.typingAttributes
                )
            } else {
                pendingInputStyle = nil
            }
            
            return true
        }

        private func applyPendingInputStyleIfNeeded(in textView: UITextView) {
            guard let pending = pendingInputStyle else { return }
            guard textView.markedTextRange == nil else { return } // wait until IME composition commits

            defer { pendingInputStyle = nil }

            let insertLength = (pending.replacementText as NSString).length
            guard insertLength > 0 else { return }

            let expectedLength = pending.oldLength - pending.range.length + insertLength
            guard textView.textStorage.length == expectedLength else { return }

            let applyRange = NSRange(location: pending.range.location, length: insertLength)
            guard applyRange.location >= 0,
                  applyRange.upperBound <= textView.textStorage.length else { return }

            // Only enforce when typing style carries inline emphasis.
            let wantsBold = (pending.typingAttributes[.font] as? UIFont)?
                .fontDescriptor
                .symbolicTraits
                .contains(.traitBold) ?? false
            guard wantsBold else { return }

            textView.textStorage.addAttributes(pending.typingAttributes, range: applyRange)
        }
        
        private func handleBackspace(_ textView: UITextView, range: NSRange) -> Bool {
            // Check if we are deleting key characters of a list prefix
            let nsText = textView.text as NSString
            let lineRange = nsText.lineRange(for: NSRange(location: range.location, length: 0))
            let lineText = nsText.substring(with: lineRange) as String
            
            // Check prefixes
            let prefixes = [
                "- [ ] ",
                "- [x] ",
                RichTextConverter.Config.checkboxAttachmentPrefix,
                "\(RichTextConverter.Config.checkboxCheckedSymbol) ",
                "\(RichTextConverter.Config.checkboxUncheckedSymbol) ",
                "• ",
                "- "
            ]
            for prefix in prefixes {
                if lineText.hasPrefix(prefix) {
                    let prefixLen = prefix.count
                    // If cursor is at end of prefix (e.g. "|• ") and user hits backspace
                    // The range.location would be prefixLen - 1 (deleting the space) or anywhere in it?
                    // Actually, if iOS keyboard deletes one char, range.length = 1.
                    
                    // We want to detect if the user is messing with the prefix.
                    // If the deletion falls WITHIN the prefix range
                    let absolutePrefixRange = NSRange(location: lineRange.location, length: prefixLen)
                    if NSIntersectionRange(range, absolutePrefixRange).length > 0 {
                        // Nuke the whole prefix to turn it into a normal line
                        textView.textStorage.beginEditing()
                        textView.textStorage.replaceCharacters(in: absolutePrefixRange, with: "")
                        textView.textStorage.endEditing()
                        let remainingLength = max(0, lineRange.length - absolutePrefixRange.length)
                        if remainingLength > 0 {
                            textView.textStorage.addAttribute(
                                .paragraphStyle,
                                value: RichTextConverter.Config.baseStyle(),
                                range: NSRange(location: lineRange.location, length: remainingLength)
                            )
                        }
                        textView.selectedRange = NSRange(location: lineRange.location, length: 0)
                        applyDefaultTypingAttributes(to: textView)
                        textViewDidChange(textView)
                        return true // handled manually; block original mutation
                    }
                }
            }
            
            // Check Ordered List
            if let match = lineText.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                let prefixLen = lineText.distance(from: lineText.startIndex, to: match.upperBound)
                let absolutePrefixRange = NSRange(location: lineRange.location, length: prefixLen)
                
                if NSIntersectionRange(range, absolutePrefixRange).length > 0 {
                     textView.textStorage.beginEditing()
                     textView.textStorage.replaceCharacters(in: absolutePrefixRange, with: "")
                     textView.textStorage.endEditing()
                     let remainingLength = max(0, lineRange.length - absolutePrefixRange.length)
                     if remainingLength > 0 {
                         textView.textStorage.addAttribute(
                             .paragraphStyle,
                             value: RichTextConverter.Config.baseStyle(),
                             range: NSRange(location: lineRange.location, length: remainingLength)
                         )
                     }
                     textView.selectedRange = NSRange(location: lineRange.location, length: 0)
                     applyDefaultTypingAttributes(to: textView)
                     textViewDidChange(textView)
                     return true // handled manually; block original mutation
                }
            }
            
            return false // let UITextView handle normal deletion
        }
        
        private func handleAutoFormatting(_ textView: UITextView, range: NSRange) -> Bool {
            let nsText = textView.text as NSString
            let lineRange = nsText.lineRange(for: NSRange(location: range.location, length: 0))
            
            // Get text from start of line up to cursor
            let currentPrefixLength = range.location - lineRange.location
            guard currentPrefixLength > 0 else { return false }
            
            let currentLinePrefixRange = NSRange(location: lineRange.location, length: currentPrefixLength)
            let currentLinePrefix = nsText.substring(with: currentLinePrefixRange)
            
            let trimmed = currentLinePrefix.trimmingCharacters(in: .whitespaces)
            let leadingSpaces = currentLinePrefix.prefix(while: { $0.isWhitespace })
            
            var replacement: String?
            var isCheckbox = false
            var isOrdered = false
            var checkboxState: Bool? = nil
            
            // Detect Triggers
            if trimmed == "-" || trimmed == "*" {
                // Bullet
                replacement = String(leadingSpaces) + "• "
            } else if trimmed == "[]" || trimmed == "[ ]" || trimmed == "- [ ]" || trimmed == "* [ ]" {
                // Checkbox
                replacement = String(leadingSpaces) + "\(RichTextConverter.Config.checkboxUncheckedSymbol) "
                isCheckbox = true
                checkboxState = false
            } else if trimmed.lowercased() == "- [x]" || trimmed.lowercased() == "* [x]" {
                // Checked checkbox
                replacement = String(leadingSpaces) + RichTextConverter.Config.checkboxAttachmentPrefix
                isCheckbox = true
                checkboxState = true
            } else if let _ = trimmed.range(of: #"^\d+\.$"#, options: .regularExpression) {
                // Ordered List (e.g. "1.")
                replacement = String(leadingSpaces) + trimmed + " "
                isOrdered = true
            }
            
            guard let newText = replacement else { return false }
            
            // Apply Replacement
            textView.textStorage.beginEditing()
            textView.textStorage.replaceCharacters(in: currentLinePrefixRange, with: newText)
            
            // Range for styling (the whole prefix including bullet/number)
            let prefixLen = newText.count
            let stylingRange = NSRange(location: lineRange.location, length: prefixLen)
            
            // Apply Styles to the Prefix (Orange Zone)
            if isCheckbox {
                let symbolFont = UIFont.systemFont(
                    ofSize: parent.font.pointSize + RichTextConverter.Config.checkboxSymbolFontSizeOffset,
                    weight: .medium
                )
                let isChecked = checkboxState ?? false
                let symbolColor = isChecked ? RichTextConverter.Config.checkboxCheckedColor : RichTextConverter.Config.checkboxUncheckedColor
                let symbolRange = NSRange(location: stylingRange.location, length: min(1, stylingRange.length))
                let spacerRange = NSRange(location: stylingRange.location + symbolRange.length, length: max(0, stylingRange.length - symbolRange.length))
                if isChecked {
                    let prefix = RichTextConverter.makeCheckedCheckboxPrefix(
                        baseFont: parent.font,
                        paragraphStyle: checkboxParagraphStyle
                    )
                    textView.textStorage.replaceCharacters(in: stylingRange, with: prefix)
                } else {
                    textView.textStorage.addAttributes([
                        .foregroundColor: symbolColor,
                        .font: symbolFont,
                        .baselineOffset: RichTextConverter.Config.checkboxBaselineOffset,
                        .paragraphStyle: checkboxParagraphStyle,
                        RichTextConverter.Key.checkbox: isChecked
                    ], range: symbolRange)
                }
                
                // Ensure no strikethrough (safety)
                textView.textStorage.removeAttribute(.strikethroughStyle, range: symbolRange)
                if spacerRange.length > 0 {
                    textView.textStorage.setAttributes(checkboxTypingAttributes(), range: spacerRange)
                }
                applyCheckboxParagraphStyle(in: textView, at: NSRange(location: lineRange.location, length: max(newText.count, 1)))
                
            } else if isOrdered {
                textView.textStorage.addAttributes([
                    .foregroundColor: RichTextConverter.Config.listPrefixColor,
                    .font: UIFont.monospacedDigitSystemFont(ofSize: parent.font.pointSize, weight: .medium),
                    RichTextConverter.Key.orderedList: newText
                ], range: stylingRange)
            } else {
                // Bullet
                textView.textStorage.addAttributes([
                    .foregroundColor: RichTextConverter.Config.listPrefixColor,
                    .font: parent.font,
                    RichTextConverter.Key.bullet: true
                ], range: stylingRange)
            }
            
            textView.textStorage.endEditing()
            
            // Reset Typing Attributes for User Input (Black Zone)
            let newCursorPos = lineRange.location + prefixLen
            textView.selectedRange = NSRange(location: newCursorPos, length: 0)
            
            let cleanAttributes: [NSAttributedString.Key: Any] = [
                .font: parent.font,
                .foregroundColor: parent.textColor,
                .paragraphStyle: isCheckbox ? checkboxParagraphStyle : RichTextConverter.Config.baseStyle()
            ]
            textView.typingAttributes = cleanAttributes
            
            textViewDidChange(textView)
            return true
        }

        private func handleReturnKey(_ textView: UITextView, range: NSRange) -> Bool {
            let nsText = textView.text as NSString
            let lineRange = nsText.lineRange(for: NSRange(location: range.location, length: 0))
            let lineText = nsText.substring(with: lineRange)
            let leadingSpaces = lineText.prefix { $0 == " " || $0 == "\t" }
            let trimmedLine = String(lineText.dropFirst(leadingSpaces.count))
            
            // 1. Identify Prefix and List Type
            var detectedPrefix: String?
            var isCheckbox = false
            var isOrdered = false
            
            // Checkboxes (Visual or Markdown)
            if trimmedLine.hasPrefix("\(RichTextConverter.Config.checkboxCheckedSymbol) ")
                || trimmedLine.hasPrefix(RichTextConverter.Config.checkboxAttachmentPrefix)
                || trimmedLine.hasPrefix("\(RichTextConverter.Config.checkboxUncheckedSymbol) ")
                || trimmedLine.hasPrefix("- [ ] ")
                || trimmedLine.hasPrefix("- [x] ") {
                detectedPrefix = String(leadingSpaces) + "\(RichTextConverter.Config.checkboxUncheckedSymbol) " // Always reset to unchecked state for new line
                isCheckbox = true
            } 
            // Bullets
            else if trimmedLine.hasPrefix("• ") || trimmedLine.hasPrefix("- ") {
                detectedPrefix = String(leadingSpaces) + "• "
            } 
            // Ordered Lists
            else if let match = trimmedLine.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                detectedPrefix = String(leadingSpaces) + String(trimmedLine[match])
                isOrdered = true
            }
            
            guard let prefix = detectedPrefix else { return true }
            
            // 2. Check for "Empty" Line to Exit List
            // If the line contains ONLY the prefix (ignoring whitespace), we exit the list mode
            let currentVisual = (trimmedLine.hasPrefix(RichTextConverter.Config.checkboxAttachmentPrefix) ? RichTextConverter.Config.checkboxAttachmentPrefix : nil) ??
                                (trimmedLine.hasPrefix("\(RichTextConverter.Config.checkboxCheckedSymbol) ") ? "\(RichTextConverter.Config.checkboxCheckedSymbol) " : nil) ??
                                (trimmedLine.hasPrefix("\(RichTextConverter.Config.checkboxUncheckedSymbol) ") ? "\(RichTextConverter.Config.checkboxUncheckedSymbol) " : nil) ??
                                (trimmedLine.hasPrefix("• ") ? "• " : nil) ??
                                prefix.trimmingCharacters(in: .whitespaces) // fallback
            
            let current = currentVisual
            if trimmedLine.trimmingCharacters(in: .whitespacesAndNewlines) == current.trimmingCharacters(in: .whitespacesAndNewlines) {
                // Remove the list item from the current line, but keep a blank line
                textView.textStorage.beginEditing()
                textView.textStorage.replaceCharacters(in: lineRange, with: "\n")
                textView.textStorage.endEditing()
                textView.selectedRange = NSRange(location: lineRange.location + 1, length: 0)
                textViewDidChange(textView)
                return false
            }
            
            // 3. Determine Next Prefix (Increment numbers)
            var nextPrefix = prefix
            if isOrdered, let match = prefix.trimmingCharacters(in: .whitespaces).range(of: #"^(\d+)\."#, options: .regularExpression) {
                let trimmedPrefix = prefix.trimmingCharacters(in: .whitespaces)
                let numStr = String(trimmedPrefix[match].dropLast(1))
                if let num = Int(numStr) {
                    nextPrefix = String(leadingSpaces) + "\(num + 1). "
                }
            }
            
            // 4. Perform Insertion with Specific Attributes
            let insertion = "\n" + nextPrefix
            textView.textStorage.beginEditing()
            
            // Insert raw text first
            textView.textStorage.replaceCharacters(in: range, with: insertion)
            
            // Ranges for styling
            let newlineLen = 1
            let prefixLen = nextPrefix.count
            let insertStart = range.location
            let prefixRange = NSRange(location: insertStart + newlineLen, length: prefixLen)
            
            // Apply Styles to the Prefix (Orange Zone)
            if isCheckbox {
                let symbolFont = UIFont.systemFont(
                    ofSize: parent.font.pointSize + RichTextConverter.Config.checkboxSymbolFontSizeOffset,
                    weight: .medium
                )
                let symbolRange = NSRange(location: prefixRange.location, length: min(1, prefixRange.length))
                let spacerRange = NSRange(location: prefixRange.location + symbolRange.length, length: max(0, prefixRange.length - symbolRange.length))
                textView.textStorage.addAttributes([
                    .foregroundColor: RichTextConverter.Config.checkboxUncheckedColor,
                    .font: symbolFont,
                    .baselineOffset: RichTextConverter.Config.checkboxBaselineOffset,
                    .paragraphStyle: checkboxParagraphStyle,
                    RichTextConverter.Key.checkbox: false
                ], range: symbolRange)
                
                // Ensure no strikethrough on the checkbox itself (safety)
                textView.textStorage.removeAttribute(.strikethroughStyle, range: symbolRange)
                if spacerRange.length > 0 {
                    textView.textStorage.setAttributes(checkboxTypingAttributes(), range: spacerRange)
                }
                applyCheckboxParagraphStyle(in: textView, at: prefixRange)
                
            } else if isOrdered {
                textView.textStorage.addAttributes([
                    .foregroundColor: RichTextConverter.Config.listPrefixColor,
                    .font: UIFont.monospacedDigitSystemFont(ofSize: parent.font.pointSize, weight: .medium),
                    RichTextConverter.Key.orderedList: nextPrefix
                ], range: prefixRange)
            } else {
                // Bullet
                textView.textStorage.addAttributes([
                    .foregroundColor: RichTextConverter.Config.listPrefixColor,
                    .font: parent.font,
                    RichTextConverter.Key.bullet: true
                ], range: prefixRange)
            }
            
            textView.textStorage.endEditing()
            
            // 5. Reset Typing Attributes for User Input (Black Zone)
            // Move cursor to end of new prefix
            let newCursorPos = insertStart + insertion.count
            textView.selectedRange = NSRange(location: newCursorPos, length: 0)
            
            // Force reset typing attributes to Clean State (Black Text, No Strikethrough)
            // This ensures the next character typed by the user is clean
            if isCheckbox {
                textView.typingAttributes = checkboxTypingAttributes()
            } else {
                applyDefaultTypingAttributes(to: textView)
            }
            
            textViewDidChange(textView)
            return false
        }
        
        // MARK: - Toolbar Actions
        
        func handleToolbarAction(_ action: EditorAction, in textView: UITextView) {
            let selectedRange = textView.selectedRange
            
            switch action {
            case .bold:
                toggleTrait(.traitBold, in: textView, range: selectedRange)
            case .h1:
                applyBlockStyle(level: 1, in: textView, range: selectedRange)
            case .h2:
                applyBlockStyle(level: 2, in: textView, range: selectedRange)
            case .checklist:
                applyChecklist(in: textView, range: selectedRange)
            case .undo:
                textView.undoManager?.undo()
            case .redo:
                textView.undoManager?.redo()
            }
            
            textViewDidChange(textView)
        }

        private func updateToolbarState(in textView: UITextView, toolbar: EditorFormattingToolbar) {
            let selectedRange = textView.selectedRange
            let location = min(selectedRange.location, max(textView.textStorage.length - 1, 0))
            let contentAttrs = textView.textStorage.length > 0
                ? textView.textStorage.attributes(at: location, effectiveRange: nil)
                : [:]
            let inlineAttrs = selectedRange.length == 0 ? textView.typingAttributes : contentAttrs
            
            if let font = inlineAttrs[.font] as? UIFont {
                toolbar.setActive(.bold, isActive: font.fontDescriptor.symbolicTraits.contains(.traitBold))
            } else {
                toolbar.setActive(.bold, isActive: false)
            }
            
            if let level = contentAttrs[RichTextConverter.Key.headerLevel] as? Int {
                toolbar.setActive(.h1, isActive: level == 1)
                toolbar.setActive(.h2, isActive: level == 2)
            } else {
                toolbar.setActive(.h1, isActive: false)
                toolbar.setActive(.h2, isActive: false)
            }
            
            toolbar.setActive(.checklist, isActive: contentAttrs[RichTextConverter.Key.checkbox] != nil)
            
            let canUndo = textView.undoManager?.canUndo ?? false
            let canRedo = textView.undoManager?.canRedo ?? false
            toolbar.setEnabled(.undo, isEnabled: canUndo)
            toolbar.setEnabled(.redo, isEnabled: canRedo)
        }

        private func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits, in textView: UITextView, range: NSRange) {
            // No selection: toggle the typing attributes so upcoming characters inherit the style.
            if range.length == 0 {
                let typingAttrs = textView.typingAttributes
                let baseFont =
                    (typingAttrs[.font] as? UIFont)
                    ?? (textView.textStorage.length > 0
                        ? (textView.textStorage.attribute(.font, at: max(range.location - 1, 0), effectiveRange: nil) as? UIFont)
                        : nil)
                    ?? parent.font
                
                var traits = baseFont.fontDescriptor.symbolicTraits
                let shouldEnable = !traits.contains(trait)
                
                if shouldEnable {
                    traits.insert(trait)
                } else {
                    traits.remove(trait)
                }
                
                let newFont = resolvedFont(for: baseFont, traits: traits)
                var updatedTypingAttrs = typingAttrs
                updatedTypingAttrs[.font] = newFont
                updatedTypingAttrs[.foregroundColor] = updatedTypingAttrs[.foregroundColor] ?? parent.textColor
                updatedTypingAttrs[.paragraphStyle] = updatedTypingAttrs[.paragraphStyle] ?? RichTextConverter.Config.baseStyle()
                textView.typingAttributes = updatedTypingAttrs
                return
            }
            
            textView.textStorage.beginEditing()
            let fallbackFont = (textView.typingAttributes[.font] as? UIFont) ?? textView.font ?? parent.font
            
            // Use enumerate to handle multi-font selections
            textView.textStorage.enumerateAttributes(in: range, options: []) { (attrs, subRange, _) in
                let currentFont = (attrs[.font] as? UIFont) ?? fallbackFont
                
                var traits = currentFont.fontDescriptor.symbolicTraits
                let shouldEnable = !traits.contains(trait)
                
                if shouldEnable {
                    traits.insert(trait)
                } else {
                    traits.remove(trait)
                }
                
                let newFont = resolvedFont(for: currentFont, traits: traits)
                textView.textStorage.addAttribute(.font, value: newFont, range: subRange)
            }
            
            textView.textStorage.endEditing()
        }

        private func resolvedFont(for baseFont: UIFont, traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
            if let descriptor = baseFont.fontDescriptor.withSymbolicTraits(traits) {
                return UIFont(descriptor: descriptor, size: baseFont.pointSize)
            }
            let systemDescriptor = UIFont.systemFont(ofSize: baseFont.pointSize).fontDescriptor
            if let descriptor = systemDescriptor.withSymbolicTraits(traits) {
                return UIFont(descriptor: descriptor, size: baseFont.pointSize)
            }
            return baseFont
        }
        
        private func applyBlockStyle(level: Int, in textView: UITextView, range: NSRange) {
            // Find full lines covered by selection
            let nsText = textView.text as NSString
            let lineRange = nsText.lineRange(for: range)
            
            textView.textStorage.beginEditing()
            
            // Check if it's already a header of this level
            let currentLevel = textView.textStorage.attribute(RichTextConverter.Key.headerLevel, at: lineRange.location, effectiveRange: nil) as? Int
            
            if currentLevel == level {
                // Remove header style
                textView.textStorage.removeAttribute(RichTextConverter.Key.headerLevel, range: lineRange)
                // Reset font to base
                textView.textStorage.addAttribute(.font, value: parent.font, range: lineRange)
                textView.textStorage.addAttribute(.paragraphStyle, value: RichTextConverter.Config.baseStyle(), range: lineRange)
            } else {
                // Apply header style
                textView.textStorage.addAttribute(RichTextConverter.Key.headerLevel, value: level, range: lineRange)
                let fontSize: CGFloat = level == 1 ? 24 : 20
                let font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
                textView.textStorage.addAttribute(.font, value: font, range: lineRange)
                textView.textStorage.addAttribute(.paragraphStyle, value: headerParagraphStyle(level: level), range: lineRange)
            }
            
            textView.textStorage.endEditing()
        }
        
        private func applyChecklist(in textView: UITextView, range: NSRange) {
            let nsText = textView.text as NSString
            let lineRange = nsText.lineRange(for: range)
            let lineText = nsText.substring(with: lineRange)
            
            textView.textStorage.beginEditing()
            
            // Check if already a checkbox
            if lineText.hasPrefix(RichTextConverter.Config.checkboxAttachmentPrefix)
                || lineText.hasPrefix("\(RichTextConverter.Config.checkboxUncheckedSymbol) ")
                || lineText.hasPrefix("\(RichTextConverter.Config.checkboxCheckedSymbol) ") {
                // Remove checkbox
                textView.textStorage.replaceCharacters(in: NSRange(location: lineRange.location, length: 2), with: "")
                let newFullRange = NSRange(location: lineRange.location, length: lineRange.length - 2)
                textView.textStorage.removeAttribute(RichTextConverter.Key.checkbox, range: newFullRange)
                if newFullRange.length > 0 {
                    textView.textStorage.addAttribute(.paragraphStyle, value: RichTextConverter.Config.baseStyle(), range: newFullRange)
                }
                let shiftedLocation = max(lineRange.location, range.location - 2)
                textView.selectedRange = NSRange(location: shiftedLocation, length: 0)
            } else {
                // Add checkbox symbol at start of line
                let symbol = "\(RichTextConverter.Config.checkboxUncheckedSymbol) "
                textView.textStorage.replaceCharacters(in: NSRange(location: lineRange.location, length: 0), with: symbol)
                
                // Set Attributes
                let symbolRange = NSRange(location: lineRange.location, length: 1)
                let spacerRange = NSRange(location: lineRange.location + 1, length: 1)
                textView.textStorage.addAttribute(RichTextConverter.Key.checkbox, value: false, range: symbolRange)
                textView.textStorage.addAttribute(.foregroundColor, value: RichTextConverter.Config.checkboxUncheckedColor, range: symbolRange)
                textView.textStorage.addAttribute(.baselineOffset, value: RichTextConverter.Config.checkboxBaselineOffset, range: symbolRange)
                textView.textStorage.addAttribute(.paragraphStyle, value: checkboxParagraphStyle, range: symbolRange)
                textView.textStorage.addAttribute(
                    .font,
                    value: UIFont.systemFont(
                        ofSize: parent.font.pointSize + RichTextConverter.Config.checkboxSymbolFontSizeOffset,
                        weight: .medium
                    ),
                    range: symbolRange
                )
                textView.textStorage.setAttributes(checkboxTypingAttributes(), range: spacerRange)
                applyCheckboxParagraphStyle(in: textView, at: NSRange(location: lineRange.location, length: max(lineRange.length + 2, 1)))
                textView.selectedRange = NSRange(location: spacerRange.upperBound, length: 0)
            }
            
            textView.textStorage.endEditing()
            if textView.textStorage.length > 0,
               let lineRangeAfterEdit = currentLineRange(in: textView) {
                applyCheckboxParagraphStyle(in: textView, at: lineRangeAfterEdit)
            }
            if isCursorInCheckboxLine(in: textView) {
                textView.typingAttributes = checkboxTypingAttributes()
            } else {
                applyDefaultTypingAttributes(to: textView)
            }
        }
        
        // Existing toggleCheckbox from previous turn, updated for range
        func toggleCheckbox(at range: NSRange, in textView: InteractiveTextView) {
            guard let checkboxState = textView.textStorage.attribute(RichTextConverter.Key.checkbox, at: range.location, effectiveRange: nil) as? Bool else {
                return
            }
            
            let replacementRange = checkboxReplacementRange(for: range, in: textView)
            let newState = !checkboxState
            textView.textStorage.beginEditing()
            
            let newColor = newState ? RichTextConverter.Config.checkboxCheckedColor : RichTextConverter.Config.checkboxUncheckedColor

            let replacementLength: Int
            if newState {
                let replacement = RichTextConverter.makeCheckedCheckboxPrefix(
                    baseFont: parent.font,
                    paragraphStyle: checkboxParagraphStyle
                )
                replacementLength = replacement.length
                textView.textStorage.replaceCharacters(in: replacementRange, with: replacement)
            } else {
                let newSymbol = "\(RichTextConverter.Config.checkboxUncheckedSymbol) "
                replacementLength = (newSymbol as NSString).length
                textView.textStorage.replaceCharacters(in: replacementRange, with: newSymbol)
            }
            
            let newRange = NSRange(location: replacementRange.location, length: replacementLength)
            let symbolRange = NSRange(location: newRange.location, length: min(1, newRange.length))
            let spacerRange = NSRange(location: newRange.location + symbolRange.length, length: max(0, newRange.length - symbolRange.length))
            textView.textStorage.addAttribute(RichTextConverter.Key.checkbox, value: newState, range: symbolRange)
            if !newState {
                textView.textStorage.addAttribute(.foregroundColor, value: newColor, range: symbolRange)
                textView.textStorage.addAttribute(.baselineOffset, value: RichTextConverter.Config.checkboxBaselineOffset, range: symbolRange)
                textView.textStorage.addAttribute(.paragraphStyle, value: checkboxParagraphStyle, range: symbolRange)
                textView.textStorage.addAttribute(
                    .font,
                    value: UIFont.systemFont(
                        ofSize: parent.font.pointSize + RichTextConverter.Config.checkboxSymbolFontSizeOffset,
                        weight: .medium
                    ),
                    range: symbolRange
                )
            }
            if spacerRange.length > 0 {
                textView.textStorage.setAttributes(checkboxTypingAttributes(), range: spacerRange)
            }
            
            let lineRange = (textView.text as NSString).lineRange(for: newRange)
            applyCheckboxParagraphStyle(in: textView, at: lineRange)
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
            textView.selectedRange = NSRange(location: newRange.upperBound, length: 0)
            textView.typingAttributes = checkboxTypingAttributes()
            textViewDidChange(textView)
        }

        private func checkboxReplacementRange(for range: NSRange, in textView: UITextView) -> NSRange {
            let nsText = textView.text as NSString
            let safeLocation = min(max(range.location, 0), nsText.length)
            let safeLength = min(range.length, max(0, nsText.length - safeLocation))
            var replacementRange = NSRange(location: safeLocation, length: safeLength)

            let upperBound = replacementRange.location + replacementRange.length
            if upperBound < nsText.length, nsText.substring(with: NSRange(location: upperBound, length: 1)) == " " {
                replacementRange.length += 1
            }

            return replacementRange
        }

        private func defaultTypingAttributes() -> [NSAttributedString.Key: Any] {
            [
                .font: parent.font,
                .foregroundColor: parent.textColor,
                .paragraphStyle: RichTextConverter.Config.baseStyle()
            ]
        }

        private func checkboxTypingAttributes() -> [NSAttributedString.Key: Any] {
            [
                .font: parent.font,
                .foregroundColor: parent.textColor,
                .paragraphStyle: checkboxParagraphStyle
            ]
        }

        private func applyDefaultTypingAttributes(to textView: UITextView) {
            textView.typingAttributes = defaultTypingAttributes()
        }

        private func normalizeTypingAttributesForListPrefixIfNeeded(in textView: UITextView) {
            let selectedRange = textView.selectedRange
            guard selectedRange.length == 0 else { return }
            guard textView.textStorage.length > 0 else { return }

            var attrsToInspect: [[NSAttributedString.Key: Any]] = []
            if selectedRange.location > 0 {
                let prevIndex = min(selectedRange.location - 1, textView.textStorage.length - 1)
                attrsToInspect.append(textView.textStorage.attributes(at: prevIndex, effectiveRange: nil))
            }
            if selectedRange.location < textView.textStorage.length {
                attrsToInspect.append(textView.textStorage.attributes(at: selectedRange.location, effectiveRange: nil))
            }

            let isListPrefixChar = attrsToInspect.contains { attrs in
                attrs[RichTextConverter.Key.checkbox] != nil
                || attrs[RichTextConverter.Key.bullet] != nil
                || attrs[RichTextConverter.Key.orderedList] != nil
            }
            guard isListPrefixChar else { return }

            if isCursorInCheckboxLine(in: textView) {
                textView.typingAttributes = checkboxTypingAttributes()
            } else {
                applyDefaultTypingAttributes(to: textView)
            }
        }

        private func applyCheckboxParagraphStyle(in textView: UITextView, at range: NSRange) {
            guard let lineRange = lineRangeContaining(range, in: textView) else { return }
            textView.textStorage.addAttribute(.paragraphStyle, value: checkboxParagraphStyle, range: lineRange)
        }

        private func lineRangeContaining(_ range: NSRange, in textView: UITextView) -> NSRange? {
            let nsText = textView.text as NSString
            guard nsText.length > 0 else { return nil }
            let safeLocation = min(max(range.location, 0), max(nsText.length - 1, 0))
            return nsText.lineRange(for: NSRange(location: safeLocation, length: 0))
        }

        private func currentLineRange(in textView: UITextView) -> NSRange? {
            lineRangeContaining(textView.selectedRange, in: textView)
        }

        private func isCursorInCheckboxLine(in textView: UITextView) -> Bool {
            guard let lineRange = currentLineRange(in: textView) else { return false }
            guard lineRange.length > 0 else { return false }
            let nsText = textView.text as NSString
            let lineText = nsText.substring(with: lineRange)
            let trimmedLine = lineText.trimmingCharacters(in: .whitespacesAndNewlines)

            return trimmedLine.hasPrefix(RichTextConverter.Config.checkboxAttachmentPrefix)
                || trimmedLine.hasPrefix("\(RichTextConverter.Config.checkboxCheckedSymbol) ")
                || trimmedLine.hasPrefix("\(RichTextConverter.Config.checkboxUncheckedSymbol) ")
                || trimmedLine.hasPrefix("- [ ] ")
                || trimmedLine.hasPrefix("- [x] ")
                || trimmedLine.hasPrefix("- [X] ")
        }
    }
}

// MARK: - Toolbar Component

enum EditorAction {
    case bold, h1, h2, checklist, undo, redo
}

class EditorFormattingToolbar: UIView {
    var onAction: ((EditorAction) -> Void)?
    var onSelectionChange: ((EditorAction) -> Void)?
    private let textView: UITextView
    private var buttons: [EditorAction: UIButton] = [:]
    private let activeTintColor = UIColor(Color.accentPrimary)
    private let inactiveTintColor = UIColor.secondaryLabel
    
    init(textView: UITextView) {
        self.textView = textView
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        self.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        self.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44)
        
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = self.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(blurView)
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .equalSpacing
        stackView.alignment = .center
        stackView.spacing = 16
        
        let buttons: [(String, EditorAction)] = [
            ("bold", .bold),
            ("h1.circle", .h1),
            ("h2.circle", .h2),
            ("checklist", .checklist),
            ("arrow.uturn.left", .undo),
            ("arrow.uturn.right", .redo)
        ]
        
        for (icon, action) in buttons {
            let btn = UIButton(type: .system)
            let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
            btn.setImage(UIImage(systemName: icon, withConfiguration: config), for: .normal)
            btn.tintColor = inactiveTintColor
            btn.addAction(UIAction { [weak self] _ in
                self?.onAction?(action)
                // Haptic feedback
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }, for: .touchUpInside)
            self.buttons[action] = btn
            stackView.addArrangedSubview(btn)
        }
        
        // Add "Dismiss Keyboard" button
        let dismissBtn = UIButton(type: .system)
        dismissBtn.setImage(UIImage(systemName: "keyboard.chevron.compact.down"), for: .normal)
        dismissBtn.tintColor = .secondaryLabel
        dismissBtn.addAction(UIAction { [weak self] _ in
            self?.textView.resignFirstResponder()
        }, for: .touchUpInside)
        stackView.addArrangedSubview(dismissBtn)
        
        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func setActive(_ action: EditorAction, isActive: Bool) {
        guard let button = buttons[action] else { return }
        button.tintColor = isActive ? activeTintColor : inactiveTintColor
    }

    func setEnabled(_ action: EditorAction, isEnabled: Bool) {
        guard let button = buttons[action] else { return }
        button.isEnabled = isEnabled
        button.alpha = isEnabled ? 1.0 : 0.35
    }
}

// MARK: - Interactive Text View

class InteractiveTextView: UITextView {
    var onCheckboxTap: ((Int, NSRange) -> Void)?
    private let checkboxTapTargetWidth: CGFloat = 44
    private let checkboxTapVerticalPadding: CGFloat = 10
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupTapGesture()
        setupTextChangeObserver()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTapGesture()
        setupTextChangeObserver()
    }
    
    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGesture.delegate = self
        addGestureRecognizer(tapGesture)
    }
    
    private func setupTextChangeObserver() {
        // Observe text changes to invalidate intrinsic content size
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChangeNotification),
            name: UITextView.textDidChangeNotification,
            object: self
        )
    }
    
    @objc private func textDidChangeNotification() {
        // Force layout recalculation when text changes
        invalidateIntrinsicContentSize()
    }
    
    // MARK: - Paste Handling
    
    override func paste(_ sender: Any?) {
        // Intercept paste to normalize text AND apply markdown formatting immediately
        if let pasteboardString = UIPasteboard.general.string {
            // Use the Converter to parse the pasted text as Markdown
            // This ensures if I paste "• Hello", it becomes an Orange bullet, not black text.
            let fontToUse = self.font ?? .systemFont(ofSize: 17)
            let colorToUse = self.textColor ?? .label
            
            let formattedText = RichTextConverter.markdownToAttributedString(
                pasteboardString, 
                baseFont: fontToUse, 
                textColor: colorToUse
            )
            
            let len = formattedText.length
            
            // Insert at current selection
            let selectedRange = self.selectedRange
            textStorage.beginEditing()
            if selectedRange.length > 0 {
                textStorage.replaceCharacters(in: selectedRange, with: formattedText)
            } else {
                textStorage.insert(formattedText, at: selectedRange.location)
            }
            textStorage.endEditing()
            
            // Move cursor to end of pasted text
            self.selectedRange = NSRange(location: selectedRange.location + len, length: 0)
            
            // Notify Changes
            delegate?.textViewDidChange?(self)
            NotificationCenter.default.post(name: UITextView.textDidChangeNotification, object: self)
        } else {
            super.paste(sender)
        }
    }

    // MARK: - Intrinsic Content Size for ScrollView support
    
    override var intrinsicContentSize: CGSize {
        // When scrolling is disabled, calculate the size needed to show all content
        if !isScrollEnabled {
            let fixedWidth = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width - 32
            let size = sizeThatFits(CGSize(width: fixedWidth, height: .greatestFiniteMagnitude))
            return CGSize(width: UIView.noIntrinsicMetric, height: max(size.height, 100))
        }
        return super.intrinsicContentSize
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Ensure intrinsic size is updated after layout
        if !isScrollEnabled {
            invalidateIntrinsicContentSize()
        }
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        if let range = checkboxRangeForTap(at: location) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onCheckboxTap?(0, range)
        }
    }

    private func checkboxRangeForTap(at location: CGPoint) -> NSRange? {
        if let index = characterIndex(at: location),
           let range = checkboxRange(atCharacterIndex: index) {
            return range
        }

        guard let lineRange = lineCharacterRange(at: location),
              let checkboxRange = firstCheckboxRange(in: lineRange),
              isPointInsideExpandedCheckboxZone(location, checkboxRange: checkboxRange) else {
            return nil
        }

        return checkboxRange
    }

    private func characterIndex(at location: CGPoint) -> Int? {
        guard let position = closestPosition(to: location) else { return nil }
        let index = offset(from: beginningOfDocument, to: position)
        return index < textStorage.length ? index : nil
    }

    private func checkboxRange(atCharacterIndex index: Int) -> NSRange? {
        guard index >= 0, index < textStorage.length else { return nil }
        guard textStorage.attribute(RichTextConverter.Key.checkbox, at: index, effectiveRange: nil) != nil else {
            return nil
        }

        var range = NSRange(location: 0, length: 0)
        _ = textStorage.attribute(RichTextConverter.Key.checkbox, at: index, effectiveRange: &range)
        return range
    }

    private func lineCharacterRange(at location: CGPoint) -> NSRange? {
        guard textStorage.length > 0 else { return nil }

        let containerPoint = CGPoint(
            x: location.x - textContainerInset.left,
            y: location.y - textContainerInset.top
        )
        let glyphIndex = layoutManager.glyphIndex(
            for: containerPoint,
            in: textContainer,
            fractionOfDistanceThroughGlyph: nil
        )
        guard glyphIndex < layoutManager.numberOfGlyphs else { return nil }

        var lineGlyphRange = NSRange(location: 0, length: 0)
        _ = layoutManager.lineFragmentUsedRect(
            forGlyphAt: glyphIndex,
            effectiveRange: &lineGlyphRange,
            withoutAdditionalLayout: true
        )
        return layoutManager.characterRange(forGlyphRange: lineGlyphRange, actualGlyphRange: nil)
    }

    private func firstCheckboxRange(in lineRange: NSRange) -> NSRange? {
        guard lineRange.length > 0 else { return nil }

        let lineUpperBound = lineRange.location + lineRange.length
        var index = lineRange.location

        while index < lineUpperBound {
            var effectiveRange = NSRange(location: 0, length: 0)
            let value = textStorage.attribute(
                RichTextConverter.Key.checkbox,
                at: index,
                effectiveRange: &effectiveRange
            )

            if value != nil {
                return NSIntersectionRange(lineRange, effectiveRange)
            }

            index += 1
        }

        return nil
    }

    private func isPointInsideExpandedCheckboxZone(_ location: CGPoint, checkboxRange: NSRange) -> Bool {
        guard checkboxRange.location < textStorage.length else { return false }

        let containerPoint = CGPoint(
            x: location.x - textContainerInset.left,
            y: location.y - textContainerInset.top
        )
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: checkboxRange.location)

        var lineGlyphRange = NSRange(location: 0, length: 0)
        let lineRect = layoutManager.lineFragmentUsedRect(
            forGlyphAt: glyphIndex,
            effectiveRange: &lineGlyphRange,
            withoutAdditionalLayout: true
        )

        let tapZone = CGRect(
            x: 0,
            y: lineRect.minY - checkboxTapVerticalPadding,
            width: min(lineRect.minX + checkboxTapTargetWidth, textContainer.size.width),
            height: lineRect.height + (checkboxTapVerticalPadding * 2)
        )

        return tapZone.contains(containerPoint)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    
}

extension InteractiveTextView: UIGestureRecognizerDelegate {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let tapGesture = gestureRecognizer as? UITapGestureRecognizer {
            let location = tapGesture.location(in: self)
            return checkboxRangeForTap(at: location) != nil
        }
        return false
    }
}
