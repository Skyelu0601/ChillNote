import SwiftUI
import RichTextKit

/// A wrapper around RichTextKit's RichTextEditor for use with Markdown-based notes
/// Handles bidirectional conversion between Markdown (storage) and AttributedString (display)
struct MarkdownRichTextEditor: View {
    @Binding var markdown: String
    var isEditable: Bool = true
    var font: UIFont = .systemFont(ofSize: 17)
    var onContentChange: (() -> Void)? = nil
    
    @StateObject private var context = RichTextContext()
    @State private var attributedText: NSAttributedString = NSAttributedString(string: " ")
    @State private var hasInitialized = false
    @State private var isUpdatingFromMarkdown = false
    @State private var isUpdatingFromEditor = false
    
    var body: some View {
        VStack(spacing: 0) {
            RichTextEditor(text: $attributedText, context: context)
                .focusedValue(\.richTextContext, context)
        }
        .disabled(!isEditable)
        .task {
            // Initialize from markdown on first load
            if !hasInitialized {
                isUpdatingFromMarkdown = true
                attributedText = RichTextConverter.markdownToAttributedString(markdown, baseFont: font)
                hasInitialized = true
                // Delay to prevent immediate feedback loop
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                isUpdatingFromMarkdown = false
            }
        }
        .onChange(of: markdown) { oldValue, newValue in
            // External markdown changed (e.g., from AI)
            guard !isUpdatingFromEditor else { return }
            guard hasInitialized else { return }
            guard oldValue != newValue else { return }
            
            isUpdatingFromMarkdown = true
            attributedText = RichTextConverter.markdownToAttributedString(newValue, baseFont: font)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isUpdatingFromMarkdown = false
            }
        }
        .onChange(of: attributedText) { oldValue, newValue in
            // User edited the rich text
            guard !isUpdatingFromMarkdown else { return }
            guard hasInitialized else { return }
            guard oldValue.string != newValue.string else { return }
            
            isUpdatingFromEditor = true
            let newMarkdown = RichTextConverter.attributedStringToMarkdown(newValue)
            if newMarkdown != markdown {
                markdown = newMarkdown
                onContentChange?()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isUpdatingFromEditor = false
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct MarkdownRichTextEditor_Previews: PreviewProvider {
    static var previews: some View {
        MarkdownRichTextEditor(
            markdown: .constant("""
            # Welcome to ChillNote
            
            This is **bold** and *italic* text.
            
            ## Features
            
            - First bullet point
            - Second bullet with **emphasis**
            
            ### Checklist
            
            - [ ] Unchecked item
            - [x] Completed task
            
            > This is a quote
            
            ---
            
            Regular paragraph text.
            """)
        )
        .padding()
    }
}
#endif
