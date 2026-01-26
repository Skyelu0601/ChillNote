import SwiftUI
import UIKit

struct JustifiedMarkdownText: UIViewRepresentable {
    let content: String
    var font: UIFont = .systemFont(ofSize: 17)
    var textColor: UIColor = .label
    
    func makeUIView(context: Context) -> DynamicTextView {
        let textView = DynamicTextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        
        // crucial for allowing the view to shrink horizontally to fit screen
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        
        return textView
    }
    
    func updateUIView(_ textView: DynamicTextView, context: Context) {
        // Convert Markdown to Attributed String
        let attributedText = NSMutableAttributedString(
            attributedString: RichTextConverter.markdownToAttributedString(content, baseFont: font, textColor: textColor)
        )
        
        // Apply Justified Alignment into paragraph styles
        attributedText.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: attributedText.length), options: []) { value, range, _ in
            if let style = value as? NSParagraphStyle {
                let mutableStyle = style.mutableCopy() as! NSMutableParagraphStyle
                mutableStyle.alignment = .justified
                attributedText.addAttribute(.paragraphStyle, value: mutableStyle, range: range)
            }
        }
        
        if textView.attributedText != attributedText {
             textView.attributedText = attributedText
             // Invalidate to force recalculation of height
             textView.invalidateIntrinsicContentSize()
        }
    }
    
    // MARK: - Dynamic Text View (Auto-Height)
    
    class DynamicTextView: UITextView {
        override var intrinsicContentSize: CGSize {
            // Calculate height based on available width
            // If bounds.width is 0 (first layout), use a reasonable default (screen width - padding)
            let width = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width - 40
            
            let size = sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
            return CGSize(width: UIView.noIntrinsicMetric, height: size.height)
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            invalidateIntrinsicContentSize()
        }
    }
}
