import SwiftUI
import UIKit

/// A rich text editor that renders markdown as formatted text (WYSIWYG)
/// Users see formatted rich text instead of raw markdown syntax
/// Checkboxes are interactive and can be toggled by tapping
struct RichTextEditorSelection: Equatable {
    var location: Int = 0
    var length: Int = 0
    var selectedText: String = ""

    var isCollapsed: Bool {
        length == 0
    }
}

@MainActor
private protocol RichTextEditorControlling: AnyObject {
    func flushPendingChanges()
    func endEditing()
}

/// Keeps persistence and external actions out of UITextView's per-keystroke path.
/// The note screen can explicitly flush before navigation, AI actions, exports,
/// or when the app moves to the background.
@MainActor
final class RichTextEditorController {
    private weak var editor: RichTextEditorControlling?

    fileprivate func connect(_ editor: RichTextEditorControlling) {
        self.editor = editor
    }

    fileprivate func disconnect(_ editor: RichTextEditorControlling) {
        guard self.editor === editor else { return }
        self.editor = nil
    }

    func flush() {
        editor?.flushPendingChanges()
    }

    func endEditing() {
        editor?.endEditing()
    }
}

struct RichTextEditorView: UIViewRepresentable {
    @Binding var text: String
    var selection: Binding<RichTextEditorSelection>?
    let controller: RichTextEditorController
    var isEditable: Bool = true
    var font: UIFont = .systemFont(ofSize: 17)
    var textColor: UIColor = .label
    var bottomInset: CGFloat = 8
    var isScrollEnabled: Bool = true
    var isEditing: Binding<Bool>?
    
    func makeUIView(context: Context) -> InteractiveTextView {
        let textView = InteractiveTextView(usingTextLayoutManager: true)
        // `usingTextLayoutManager` is backed by a UIKit class factory and can
        // bypass the subclass initializers where the gesture is normally set up.
        textView.installCheckboxTapHandling()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isEditable = isEditable
        textView.allowsEditingTextAttributes = true
        textView.setEditorScrollingEnabled(isScrollEnabled)
        textView.setContentHuggingPriority(.defaultLow, for: .vertical)

        // Remember the editor's configured base font/color so paste handling
        // doesn't have to rely on UITextView.font (which can return nil or a
        // small default once attributedText contains mixed fonts).
        textView.editorBaseFont = font
        textView.editorBaseTextColor = textColor
        textView.editorSession = context.coordinator.editorSession

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
        
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = UIEdgeInsets(top: 20, left: 24, bottom: bottomInset, right: 24)
        
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
        context.coordinator.textView = textView
        controller.connect(context.coordinator)

        return textView
    }
    
    func updateUIView(_ textView: InteractiveTextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.textView = textView
        controller.connect(context.coordinator)
        textView.isEditable = isEditable
        textView.setEditorScrollingEnabled(isScrollEnabled)
        textView.editorBaseFont = font
        textView.editorBaseTextColor = textColor
        context.coordinator.editorSession.updateTheme(baseFont: font, textColor: textColor)
        
        // Update styling if needed (though usually controlled by attributes)
        // We only do a full re-render if the text actually changed from the outside
        // to avoid clobbering the user's cursor while typing.
        if text != context.coordinator.lastKnownMarkdown {
            guard textView.markedTextRange == nil else { return }
            let snapshot = context.coordinator.editorSession.applyExternalMarkdown(
                text,
                to: textView,
                markdownSelection: selection?.wrappedValue
            )
            context.coordinator.acceptExternalMarkdown(text, snapshot: snapshot)
        }
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: InteractiveTextView,
        context: Context
    ) -> CGSize? {
        guard !isScrollEnabled,
              let width = proposal.width,
              width > 0 else {
            return nil
        }

        return CGSize(
            width: width,
            height: uiView.heightThatFitsAllContent(width: width)
        )
    }

    static func dismantleUIView(_ uiView: InteractiveTextView, coordinator: Coordinator) {
        coordinator.flushPendingChanges()
        coordinator.parent.controller.disconnect(coordinator)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    @MainActor
    class Coordinator: NSObject, UITextViewDelegate, RichTextEditorControlling {
        var parent: RichTextEditorView
        let editorSession: MarkdownEditorSession
        weak var textView: UITextView?
        // Cache to prevent circular updates
        var lastKnownMarkdown: String = ""
        private var latestSnapshot: RichTextSerializationSnapshot?
        private var hasUncommittedText = false
        private var commitWorkItem: DispatchWorkItem?
        private var selectionWorkItem: DispatchWorkItem?
        private var pendingInputStyle: PendingInputStyle?

        private static let commitDelay: TimeInterval = 0.4
        private static let selectionDelay: TimeInterval = 0.12

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
            self.editorSession = MarkdownEditorSession(baseFont: parent.font, textColor: parent.textColor)
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isEditing?.wrappedValue = true
            normalizeTypingAttributesForListPrefixIfNeeded(in: textView)
            scheduleCaretVisibilityUpdate(in: textView)
        }
        
        func textViewDidChange(_ textView: UITextView) {
            applyPendingInputStyleIfNeeded(in: textView)
            guard textView.markedTextRange == nil else { return }
            textView.setNeedsLayout()
            hasUncommittedText = true
            scheduleCommit()
            scheduleCaretVisibilityUpdate(in: textView)
            if let toolbar = textView.inputAccessoryView as? EditorFormattingToolbar {
                updateToolbarState(in: textView, toolbar: toolbar)
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            normalizeTypingAttributesForListPrefixIfNeeded(in: textView)
            guard textView.markedTextRange == nil else { return }
            if !hasUncommittedText {
                scheduleSelectionPublish()
            }
            scheduleCaretVisibilityUpdate(in: textView)
            if let toolbar = textView.inputAccessoryView as? EditorFormattingToolbar {
                updateToolbarState(in: textView, toolbar: toolbar)
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isEditing?.wrappedValue = false
            flushPendingChanges()
        }

        func endEditing() {
            textView?.resignFirstResponder()
        }

        func acceptExternalMarkdown(
            _ markdown: String,
            snapshot: RichTextSerializationSnapshot
        ) {
            cancelScheduledWork()
            lastKnownMarkdown = markdown
            latestSnapshot = snapshot
            hasUncommittedText = false
            scheduleSelectionPublish()
        }

        func flushPendingChanges() {
            cancelScheduledWork()
            guard let textView, textView.markedTextRange == nil else { return }

            if hasUncommittedText || latestSnapshot == nil {
                let snapshot = RichTextConverter.serializationSnapshot(from: textView.attributedText)
                latestSnapshot = snapshot
                hasUncommittedText = false
                lastKnownMarkdown = snapshot.markdown
                if parent.text != snapshot.markdown {
                    parent.text = snapshot.markdown
                }
            }

            if let latestSnapshot {
                publishSelection(from: textView, snapshot: latestSnapshot)
            }
        }

        private func scheduleCommit() {
            commitWorkItem?.cancel()
            selectionWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.flushPendingChanges()
            }
            commitWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.commitDelay, execute: workItem)
        }

        private func scheduleSelectionPublish() {
            selectionWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                guard let self, let textView = self.textView else { return }
                if let latestSnapshot = self.latestSnapshot {
                    self.publishSelection(from: textView, snapshot: latestSnapshot)
                }
            }
            selectionWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.selectionDelay, execute: workItem)
        }

        private func cancelScheduledWork() {
            commitWorkItem?.cancel()
            selectionWorkItem?.cancel()
            commitWorkItem = nil
            selectionWorkItem = nil
        }

        private func scheduleCaretVisibilityUpdate(in textView: UITextView) {
            guard !parent.isScrollEnabled else { return }
            DispatchQueue.main.async { [weak textView] in
                (textView as? InteractiveTextView)?.scrollCaretToVisibleInEnclosingScrollView()
            }
        }

        func publishSelection(
            from textView: UITextView,
            snapshot: RichTextSerializationSnapshot? = nil
        ) {
            guard let selection = parent.selection else { return }
            let selectedRange = textView.selectedRange
            guard let currentSnapshot = snapshot ?? latestSnapshot else { return }
            let nextSelection = currentSnapshot.markdownSelection(for: selectedRange)

            guard selection.wrappedValue != nextSelection else { return }
            selection.wrappedValue = nextSelection
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
                        AppInteractionFeedback.impact(.soft, intensity: 0.62)
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
                     AppInteractionFeedback.impact(.soft, intensity: 0.62)
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
                let isChecked = checkboxState ?? false
                let prefix = RichTextConverter.makeCheckboxPrefix(
                    checked: isChecked,
                    baseFont: parent.font,
                    paragraphStyle: checkboxParagraphStyle
                )
                textView.textStorage.replaceCharacters(in: stylingRange, with: prefix)
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
            AppInteractionFeedback.impact(.soft, intensity: 0.68)
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
                textView.textStorage.replaceCharacters(
                    in: lineRange,
                    with: NSAttributedString(string: "\n", attributes: defaultTypingAttributes())
                )
                textView.textStorage.endEditing()
                textView.selectedRange = NSRange(location: lineRange.location + 1, length: 0)
                applyDefaultTypingAttributes(to: textView)
                textViewDidChange(textView)
                AppInteractionFeedback.selectionChanged()
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
                let checkboxPrefix = RichTextConverter.makeCheckboxPrefix(
                    checked: false,
                    baseFont: parent.font,
                    paragraphStyle: checkboxParagraphStyle
                )
                textView.textStorage.replaceCharacters(in: prefixRange, with: checkboxPrefix)
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
                // Checklist is a structural edit. Publish it immediately so a
                // SwiftUI refresh cannot restore the pre-action Markdown while
                // the normal debounced commit is still pending.
                textViewDidChange(textView)
                flushPendingChanges()
                return
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
            let safeRange = NSRange(
                location: min(max(range.location, 0), nsText.length),
                length: min(range.length, max(0, nsText.length - range.location))
            )
            let selectedLinesRange = nsText.lineRange(for: safeRange)
            let lineRanges = paragraphRanges(in: selectedLinesRange, text: nsText)
            let shouldRemove = !lineRanges.isEmpty && lineRanges.allSatisfy {
                checkboxState(atLineStart: $0.location, in: textView) != nil
            }

            textView.textStorage.beginEditing()

            for lineRange in lineRanges.reversed() {
                if shouldRemove {
                    guard let prefixRange = checkboxPrefixRange(atLineStart: lineRange.location, in: textView) else {
                        continue
                    }
                    textView.textStorage.replaceCharacters(in: prefixRange, with: "")
                    let contentLength = max(0, lineRange.length - prefixRange.length)
                    if contentLength > 0 {
                        let contentRange = NSRange(location: lineRange.location, length: contentLength)
                        textView.textStorage.removeAttribute(.strikethroughStyle, range: contentRange)
                        textView.textStorage.addAttributes([
                            .foregroundColor: parent.textColor,
                            .paragraphStyle: RichTextConverter.Config.baseStyle()
                        ], range: contentRange)
                    }
                } else if checkboxState(atLineStart: lineRange.location, in: textView) == nil {
                    let prefix = RichTextConverter.makeCheckboxPrefix(
                        checked: false,
                        baseFont: parent.font,
                        paragraphStyle: checkboxParagraphStyle
                    )
                    textView.textStorage.replaceCharacters(
                        in: NSRange(location: lineRange.location, length: 0),
                        with: prefix
                    )
                    let styledLength = max(1, lineRange.length + prefix.length)
                    textView.textStorage.addAttribute(
                        .paragraphStyle,
                        value: checkboxParagraphStyle,
                        range: NSRange(location: lineRange.location, length: styledLength)
                    )
                }
            }
            textView.textStorage.endEditing()

            let prefixLength = RichTextConverter.makeCheckboxPrefix(
                checked: false,
                baseFont: parent.font,
                paragraphStyle: checkboxParagraphStyle
            ).length
            if range.length == 0 {
                let caretLocation = shouldRemove
                    ? max(selectedLinesRange.location, range.location - prefixLength)
                    : range.location + (checkboxState(atLineStart: selectedLinesRange.location, in: textView) == nil ? 0 : prefixLength)
                textView.selectedRange = NSRange(
                    location: min(max(caretLocation, selectedLinesRange.location), textView.textStorage.length),
                    length: 0
                )
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
            
            let originalSelection = textView.selectedRange
            let replacement = RichTextConverter.makeCheckboxPrefix(
                checked: newState,
                baseFont: parent.font,
                paragraphStyle: checkboxParagraphStyle
            )
            let replacementLength = replacement.length
            textView.textStorage.replaceCharacters(in: replacementRange, with: replacement)
            
            let newRange = NSRange(location: replacementRange.location, length: replacementLength)
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
            let lengthDelta = replacementLength - replacementRange.length
            if originalSelection.location >= replacementRange.upperBound {
                textView.selectedRange = NSRange(
                    location: max(0, originalSelection.location + lengthDelta),
                    length: originalSelection.length
                )
            }
            textViewDidChange(textView)
            flushPendingChanges()
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

        private func paragraphRanges(in selectedRange: NSRange, text: NSString) -> [NSRange] {
            if selectedRange.length == 0 {
                return [selectedRange]
            }

            var ranges: [NSRange] = []
            var cursor = selectedRange.location
            while cursor < selectedRange.upperBound {
                let lineRange = text.lineRange(for: NSRange(location: cursor, length: 0))
                ranges.append(lineRange)
                guard lineRange.upperBound > cursor else { break }
                cursor = lineRange.upperBound
            }
            return ranges
        }

        private func checkboxState(atLineStart location: Int, in textView: UITextView) -> Bool? {
            guard location >= 0, location < textView.textStorage.length else { return nil }
            return textView.textStorage.attribute(
                RichTextConverter.Key.checkbox,
                at: location,
                effectiveRange: nil
            ) as? Bool
        }

        private func checkboxPrefixRange(atLineStart location: Int, in textView: UITextView) -> NSRange? {
            guard location >= 0, location < textView.textStorage.length else { return nil }
            var effectiveRange = NSRange(location: 0, length: 0)
            guard textView.textStorage.attribute(
                RichTextConverter.Key.checkbox,
                at: location,
                effectiveRange: &effectiveRange
            ) != nil else {
                return nil
            }
            return checkboxReplacementRange(for: effectiveRange, in: textView)
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
        self.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50)
        
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = self.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(blurView)
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .equalSpacing
        stackView.alignment = .center
        stackView.spacing = 8
        
        let buttons: [(String, EditorAction)] = [
            ("bold", .bold),
            ("checklist", .checklist),
            ("arrow.uturn.left", .undo),
            ("arrow.uturn.right", .redo)
        ]
        
        for (icon, action) in buttons {
            let btn = UIButton(type: .system)
            let config = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
            btn.setImage(UIImage(systemName: icon, withConfiguration: config), for: .normal)
            btn.tintColor = inactiveTintColor
            btn.layer.cornerRadius = 9
            btn.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                btn.widthAnchor.constraint(equalToConstant: 38),
                btn.heightAnchor.constraint(equalToConstant: 38)
            ])
            btn.addAction(UIAction { [weak self] _ in
                self?.onAction?(action)
                switch action {
                case .bold, .h1, .h2, .checklist:
                    AppInteractionFeedback.selectionChanged()
                case .undo, .redo:
                    AppInteractionFeedback.impact(.soft, intensity: 0.68)
                }
            }, for: .touchUpInside)
            self.buttons[action] = btn
            stackView.addArrangedSubview(btn)
        }
        
        // Add "Dismiss Keyboard" button
        let dismissBtn = UIButton(type: .system)
        dismissBtn.setImage(UIImage(systemName: "keyboard.chevron.compact.down"), for: .normal)
        dismissBtn.tintColor = .secondaryLabel
        dismissBtn.layer.cornerRadius = 9
        dismissBtn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dismissBtn.widthAnchor.constraint(equalToConstant: 38),
            dismissBtn.heightAnchor.constraint(equalToConstant: 38)
        ])
        dismissBtn.addAction(UIAction { [weak self] _ in
            self?.textView.resignFirstResponder()
            AppInteractionFeedback.impact(.soft, intensity: 0.6)
        }, for: .touchUpInside)
        stackView.addArrangedSubview(dismissBtn)
        
        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func setActive(_ action: EditorAction, isActive: Bool) {
        guard let button = buttons[action] else { return }
        button.tintColor = isActive ? activeTintColor : inactiveTintColor
        button.backgroundColor = isActive ? activeTintColor.withAlphaComponent(0.12) : .clear
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
    var editorBaseFont: UIFont = .systemFont(ofSize: 17)
    var editorBaseTextColor: UIColor = .label
    weak var editorSession: MarkdownEditorSession?
    private let checkboxTapTargetWidth: CGFloat = 44
    private let checkboxTapVerticalPadding: CGFloat = 10
    private weak var checkboxTapGesture: UITapGestureRecognizer?
    private var lastIntrinsicContentHeight: CGFloat = 0
    private var lastMeasuredWidth: CGFloat = 0

    override var contentSize: CGSize {
        didSet {
            guard !isScrollEnabled else { return }
            let nextHeight = max(contentSize.height, 100)
            guard abs(lastIntrinsicContentHeight - nextHeight) > 0.5 else { return }
            lastIntrinsicContentHeight = nextHeight
            invalidateIntrinsicContentSize()
        }
    }

    override var intrinsicContentSize: CGSize {
        guard !isScrollEnabled else { return super.intrinsicContentSize }
        return CGSize(
            width: UIView.noIntrinsicMetric,
            height: heightThatFitsAllContent(width: bounds.width)
        )
    }

    func heightThatFitsAllContent(width: CGFloat) -> CGFloat {
        let fittingWidth = width > 0 ? width : UIScreen.main.bounds.width - 32
        let fittingSize = sizeThatFits(
            CGSize(width: fittingWidth, height: .greatestFiniteMagnitude)
        )
        return max(fittingSize.height, 100)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !isScrollEnabled,
           bounds.width > 0,
           abs(lastMeasuredWidth - bounds.width) > 0.5 {
            lastMeasuredWidth = bounds.width
            invalidateIntrinsicContentSize()
        }
    }
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        installCheckboxTapHandling()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        installCheckboxTapHandling()
    }

    func installCheckboxTapHandling() {
        guard checkboxTapGesture == nil else { return }
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGesture.delegate = self
        tapGesture.cancelsTouchesInView = false
        addGestureRecognizer(tapGesture)
        checkboxTapGesture = tapGesture
    }

    var isCheckboxTapHandlingInstalled: Bool {
        checkboxTapGesture != nil
    }

    func setEditorScrollingEnabled(_ enabled: Bool) {
        isScrollEnabled = enabled
        panGestureRecognizer.isEnabled = enabled
        showsVerticalScrollIndicator = enabled
        alwaysBounceVertical = enabled
        keyboardDismissMode = enabled ? .interactive : .none
        invalidateIntrinsicContentSize()
    }

    func scrollCaretToVisibleInEnclosingScrollView() {
        guard !isScrollEnabled,
              let selectedTextRange,
              let enclosingScrollView else { return }

        layoutIfNeeded()
        let caretRect = caretRect(for: selectedTextRange.end)
            .insetBy(dx: -8, dy: -16)
        let targetRect = convert(caretRect, to: enclosingScrollView)
        enclosingScrollView.scrollRectToVisible(targetRect, animated: false)
    }

    private var enclosingScrollView: UIScrollView? {
        var ancestor = superview
        while let view = ancestor {
            if let scrollView = view as? UIScrollView {
                return scrollView
            }
            ancestor = view.superview
        }
        return nil
    }
    
    // MARK: - Paste Handling
    
    override func paste(_ sender: Any?) {
        // Pasted text is intentionally matched to the ChillNote editor theme.
        // Source-app fonts and accidental Markdown-looking prefixes must not
        // change the surrounding document style.
        if let pasteboardString = UIPasteboard.general.string,
           let editorSession {
            editorSession.pastePlainText(pasteboardString, into: self)
        } else {
            super.paste(sender)
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        if let range = checkboxRangeForTap(at: location) {
            AppInteractionFeedback.selectionChanged()
            onCheckboxTap?(0, range)
        }
    }

    func checkboxRangeForTap(at location: CGPoint) -> NSRange? {
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
        guard let position = closestPosition(to: location) else { return nil }
        let characterIndex = min(
            max(offset(from: beginningOfDocument, to: position), 0),
            textStorage.length - 1
        )
        return (text as NSString).lineRange(
            for: NSRange(location: characterIndex, length: 0)
        )
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
            index = NSMaxRange(effectiveRange)
        }
        return nil
    }

    private func isPointInsideExpandedCheckboxZone(_ location: CGPoint, checkboxRange: NSRange) -> Bool {
        guard checkboxRange.location >= 0,
              checkboxRange.upperBound <= textStorage.length,
              let start = position(from: beginningOfDocument, offset: checkboxRange.location),
              let end = position(from: start, offset: checkboxRange.length),
              let textRange = textRange(from: start, to: end) else {
            return false
        }

        let checkboxRect = firstRect(for: textRange)
        guard !checkboxRect.isNull, !checkboxRect.isInfinite else { return false }

        let tapZone = CGRect(
            x: max(0, checkboxRect.midX - (checkboxTapTargetWidth / 2)),
            y: checkboxRect.minY - checkboxTapVerticalPadding,
            width: checkboxTapTargetWidth,
            height: checkboxRect.height + (checkboxTapVerticalPadding * 2)
        )

        return tapZone.contains(location)
    }
}

extension InteractiveTextView: UIGestureRecognizerDelegate {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === panGestureRecognizer && !isScrollEnabled {
            return false
        }

        if let tapGesture = gestureRecognizer as? UITapGestureRecognizer,
           tapGesture === checkboxTapGesture {
            let location = tapGesture.location(in: self)
            return checkboxRangeForTap(at: location) != nil
        }

        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizer === checkboxTapGesture || otherGestureRecognizer === checkboxTapGesture
    }
}
