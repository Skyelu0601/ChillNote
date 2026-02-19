import SwiftUI
import UIKit

/// A high-performance text view that renders Markdown content with an optional typewriter animation.
///
/// **Performance design**:
/// - Streaming mode: shows full text immediately as it arrives (no re-render per character).
/// - Typewriter mode: animates via `CADisplayLink` entirely in UIKit, zero SwiftUI re-renders during animation.
/// - SwiftUI `body` is only called when `content` or mode flags change.
struct TypewriterMarkdownText: View {
    let content: String
    var isStreaming: Bool = false
    let shouldAnimate: Bool
    var onAnimationComplete: (() -> Void)? = nil

    var body: some View {
        return _TypewriterUIView(
            content: content,
            isStreaming: isStreaming,
            shouldAnimate: shouldAnimate,
            onAnimationComplete: onAnimationComplete
        )
    }
}

// MARK: - UIViewRepresentable wrapper

private struct _TypewriterUIView: UIViewRepresentable {
    let content: String
    let isStreaming: Bool
    let shouldAnimate: Bool
    var onAnimationComplete: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> _TypewriterTextView {
        let view = _TypewriterTextView()
        view.onAnimationComplete = onAnimationComplete
        return view
    }

    func updateUIView(_ uiView: _TypewriterTextView, context: Context) {
        uiView.onAnimationComplete = onAnimationComplete
        uiView.update(content: content, isStreaming: isStreaming, shouldAnimate: shouldAnimate)
    }

    class Coordinator {}
}

// MARK: - The actual UIView

final class _TypewriterTextView: UIView {
    var onAnimationComplete: (() -> Void)?

    // MARK: Subviews
    private let textView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.setContentCompressionResistancePriority(.required, for: .vertical)
        return tv
    }()

    // MARK: Animation state
    private var fullContent: String = ""
    private var displayedCharCount: Int = 0
    private var displayLink: CADisplayLink?
    private var charDelay: TimeInterval = 1.0 / 60.0  // target ~60 chars/sec

    // Character-level cache so we don't recompute Array() every frame
    private var fullContentChars: [Character] = []

    // Track last rendered content to avoid redundant AttributedString work
    private var lastRenderedContent: String = ""
    private var lastRenderedLength: Int = -1

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        addSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    override var intrinsicContentSize: CGSize {
        let width = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width - 40
        let size = textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: UIView.noIntrinsicMetric, height: size.height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
    }

    // MARK: - Update from SwiftUI

    func update(content: String, isStreaming: Bool, shouldAnimate: Bool) {
        if isStreaming {
            // Streaming: show full received content immediately, no animation needed.
            stopTypewriter()
            renderText(content, charCount: content.count)
        } else if shouldAnimate && content != fullContent {
            // New content arrived & typewriter requested
            startTypewriter(for: content)
        } else if !shouldAnimate && !isStreaming {
            // Static display
            stopTypewriter()
            renderText(content, charCount: content.count)
        }
        // Always track the latest full content for streaming catch-up
        if content != fullContent {
            fullContent = content
            fullContentChars = Array(content)
        }
    }

    // MARK: - Typewriter

    private func startTypewriter(for newContent: String) {
        stopTypewriter()
        fullContent = newContent
        fullContentChars = Array(newContent)
        displayedCharCount = 0
        renderText("", charCount: 0)

        let link = CADisplayLink(target: self, selector: #selector(typewriterTick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopTypewriter() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func typewriterTick(_ link: CADisplayLink) {
        let targetCount = fullContentChars.count
        guard displayedCharCount < targetCount else {
            // Animation complete
            stopTypewriter()
            renderText(fullContent, charCount: targetCount)
            DispatchQueue.main.async { [weak self] in
                self?.onAnimationComplete?()
            }
            return
        }

        // Advance ~2 chars per frame for smooth feel (≈ 120 chars/sec at 60fps)
        let step = max(1, Int(Double(targetCount) / 30.0))  // finish in ~30 frames
        displayedCharCount = min(displayedCharCount + step, targetCount)
        let slice = String(fullContentChars.prefix(displayedCharCount))
        renderText(slice, charCount: displayedCharCount)
    }

    // MARK: - Render

    private func renderText(_ text: String, charCount: Int) {
        // Skip redundant re-renders
        guard charCount != lastRenderedLength || text != lastRenderedContent else { return }
        lastRenderedContent = text
        lastRenderedLength = charCount

        let font = UIFont.preferredFont(forTextStyle: .callout)
        let color = UIColor(Color.textMain)
        let attributed = NSMutableAttributedString(
            attributedString: RichTextConverter.markdownToAttributedString(text, baseFont: font, textColor: color)
        )
        attributed.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: attributed.length), options: []) { value, range, _ in
            if let style = value as? NSParagraphStyle {
                let mutableStyle = style.mutableCopy() as! NSMutableParagraphStyle
                mutableStyle.alignment = .natural
                attributed.addAttribute(.paragraphStyle, value: mutableStyle, range: range)
            }
        }

        if textView.attributedText != attributed {
            textView.attributedText = attributed
            invalidateIntrinsicContentSize()
        }
    }
}
