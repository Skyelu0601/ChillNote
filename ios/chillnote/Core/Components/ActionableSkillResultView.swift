import SwiftUI
import UIKit

struct ActionableSkillResultBlock: Identifiable, Equatable {
    let id: Int
    let label: String
    let content: String
}

enum ActionableSkillResultParser {
    static func blocks(recipeID: String, markdown: String) -> [ActionableSkillResultBlock] {
        switch recipeID {
        case "hook_generator":
            return hookBlocks(from: markdown)
        case "caption_pack", "repurpose_pack":
            return sectionBlocks(from: markdown)
        default:
            return []
        }
    }

    static func hookBlocks(from markdown: String) -> [ActionableSkillResultBlock] {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        let paragraphs = normalized
            .components(separatedBy: "\n\n")
            .flatMap(splitHookParagraphIfNeeded)
            .map(trimmed)
            .filter { !$0.isEmpty }

        var blocks: [ActionableSkillResultBlock] = []

        for paragraph in paragraphs {
            let cleaned = paragraph.replacingOccurrences(
                of: #"^\s*(?:#{1,6}\s+|[-*•]\s+|\d+[.)]\s+)"#,
                with: "",
                options: .regularExpression
            )
            let plain = cleaned
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: "__", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !plain.isEmpty else { continue }

            if let parts = splitLabelAndContent(plain) {
                blocks.append(
                    ActionableSkillResultBlock(
                        id: blocks.count,
                        label: parts.label,
                        content: parts.content
                    )
                )
            } else {
                blocks.append(
                    ActionableSkillResultBlock(
                        id: blocks.count,
                        label: String(format: "%02d", blocks.count + 1),
                        content: plain
                    )
                )
            }
        }

        return blocks.count >= 2 ? blocks : []
    }

    static func sectionBlocks(from markdown: String) -> [ActionableSkillResultBlock] {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        var sections: [(label: String, lines: [String])] = []
        var currentLabel: String?
        var currentLines: [String] = []

        func appendCurrentSection() {
            guard let currentLabel else { return }
            sections.append((currentLabel, currentLines))
        }

        for line in lines {
            let lineWithoutLeadingSpace = line.drop(while: { $0 == " " || $0 == "\t" })
            if lineWithoutLeadingSpace.hasPrefix("## "),
               !lineWithoutLeadingSpace.hasPrefix("### ") {
                appendCurrentSection()
                currentLabel = String(lineWithoutLeadingSpace.dropFirst(3))
                    .replacingOccurrences(of: "**", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                currentLines = []
            } else if currentLabel != nil {
                currentLines.append(line)
            }
        }
        appendCurrentSection()

        return sections.enumerated().compactMap { index, section in
            let content = trimmed(section.lines.joined(separator: "\n"))
            guard !section.label.isEmpty, !content.isEmpty else { return nil }
            return ActionableSkillResultBlock(id: index, label: section.label, content: content)
        }
    }

    private static func splitHookParagraphIfNeeded(_ paragraph: String) -> [String] {
        let lines = paragraph
            .components(separatedBy: "\n")
            .map(trimmed)
            .filter { !$0.isEmpty }

        guard lines.count > 1 else { return [paragraph] }
        let distinctHookLines = lines.filter { line in
            line.range(of: #"^(?:[-*•]\s+|\d+[.)]\s+)"#, options: .regularExpression) != nil
                || splitLabelAndContent(
                    line.replacingOccurrences(of: "**", with: "")
                ) != nil
        }
        return distinctHookLines.count == lines.count ? lines : [paragraph]
    }

    private static func splitLabelAndContent(_ text: String) -> (label: String, content: String)? {
        let delimiters = [":", "：", " — ", " – "]

        for delimiter in delimiters {
            guard let range = text.range(of: delimiter) else { continue }
            let label = trimmed(String(text[..<range.lowerBound]))
            let content = trimmed(String(text[range.upperBound...]))
            guard !label.isEmpty, label.count <= 40, !content.isEmpty else { continue }
            return (label, content)
        }

        return nil
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ActionableSkillResultView: View {
    let recipe: AgentRecipe
    let result: String
    var onBlockCopied: (() -> Void)? = nil

    @State private var copiedBlockID: Int?
    @State private var copyResetTask: Task<Void, Never>?

    private var blocks: [ActionableSkillResultBlock] {
        ActionableSkillResultParser.blocks(recipeID: recipe.id, markdown: result)
    }

    var body: some View {
        if blocks.isEmpty {
            RichTextPreview(
                content: result,
                lineLimit: .max,
                font: .body,
                textColor: .textMain
            )
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            VStack(spacing: 0) {
                ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                    ActionableSkillResultRow(
                        block: block,
                        isCopied: copiedBlockID == block.id,
                        onCopy: { copy(block) }
                    )

                    if index < blocks.count - 1 {
                        Divider()
                            .overlay(Color.separator)
                            .padding(.leading, 16)
                    }
                }
            }
            .background(Color.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.borderSubtle, lineWidth: 1)
            }
            .onDisappear {
                copyResetTask?.cancel()
            }
        }
    }

    private func copy(_ block: ActionableSkillResultBlock) {
        UIPasteboard.general.string = block.content
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onBlockCopied?()

        withAnimation(.easeOut(duration: 0.16)) {
            copiedBlockID = block.id
        }

        copyResetTask?.cancel()
        copyResetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.16)) {
                copiedBlockID = nil
            }
        }
    }
}

struct SkillResultCopyToast: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.accentSecondaryText)

            Text(L10n.text("ai_skills.result.copy_success"))
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.accentSecondaryText)

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.accentSecondaryText)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.text("common.close"))
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Color.secondaryHighlight)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
    }
}

private struct ActionableSkillResultRow: View {
    let block: ActionableSkillResultBlock
    let isCopied: Bool
    let onCopy: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(block.label.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textSub)
                    .tracking(0.4)

                RichTextPreview(
                    content: block.content,
                    lineLimit: 12,
                    font: .bodyLarge,
                    textColor: .textMain
                )
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onCopy) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isCopied ? .white : .accentSecondaryText)
                    .frame(width: 44, height: 44)
                    .background(isCopied ? Color.accentSecondary : Color.bgPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        if !isCopied {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.borderSubtle, lineWidth: 1)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.text("ai_skills.result.action.copy_block"))
            .accessibilityValue(isCopied ? L10n.text("ai_skills.result.copy_success") : "")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .animation(.easeInOut(duration: 0.16), value: isCopied)
    }
}
