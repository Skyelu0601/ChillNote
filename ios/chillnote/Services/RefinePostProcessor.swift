import Foundation

enum RefinePostProcessor {
    private static let implicitStructuringKey = "useImplicitStructuringInVoiceRefine"
    private static let implicitChecklistKey = "useImplicitChecklistInVoiceRefine"

    static func process(refinedText: String, originalTranscript: String, isShortInput: Bool) -> String {
        let cleaned = refinedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return cleaned }
        guard !isShortInput else { return cleaned }

        // Respect user feature flags while keeping backward-compatible defaults.
        guard isEnabled(key: implicitStructuringKey), isEnabled(key: implicitChecklistKey) else {
            return cleaned
        }

        let lines = cleaned.components(separatedBy: .newlines)
        guard !lines.isEmpty else { return cleaned }

        var converted = lines
        var plainBulletIndexes: [Int] = []
        var plainBulletContents: [String] = []

        for (index, line) in lines.enumerated() {
            if isChecklistLine(line) {
                continue
            }
            if let bulletContent = plainBulletContent(from: line) {
                plainBulletIndexes.append(index)
                plainBulletContents.append(bulletContent)
            }
        }

        guard !plainBulletIndexes.isEmpty else { return cleaned }
        guard shouldConvertBullets(originalTranscript: originalTranscript, bulletContents: plainBulletContents) else {
            return cleaned
        }

        for index in plainBulletIndexes {
            guard let content = plainBulletContent(from: lines[index]) else { continue }
            converted[index] = "- [ ] \(content)"
        }

        return converted.joined(separator: "\n")
    }

    private static func isEnabled(key: String) -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: key) != nil else { return true }
        return defaults.bool(forKey: key)
    }

    private static func shouldConvertBullets(originalTranscript: String, bulletContents: [String]) -> Bool {
        if bulletContents.isEmpty {
            return false
        }

        let taskHints = (
            originalTranscript + "\n" + bulletContents.joined(separator: "\n")
        ).lowercased()

        let englishKeywords = [
            "todo", "task", "tasks", "action", "action item", "next step", "follow up",
            "need to", "should", "must", "review", "submit", "update", "fix", "plan"
        ]
        if englishKeywords.contains(where: { taskHints.contains($0) }) {
            return true
        }

        let chineseKeywords = [
            "待办", "任务", "需要", "要", "跟进", "提交", "安排", "处理", "修复",
            "更新", "确认", "联系", "完成", "上线", "复盘"
        ]
        if chineseKeywords.contains(where: { taskHints.contains($0) }) {
            return true
        }

        // Fallback: when there are multiple bullet lines, prefer checklist for better actionability.
        return bulletContents.count >= 2
    }

    private static func plainBulletContent(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") else { return nil }
        guard !isChecklistLine(trimmed) else { return nil }
        let content = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        return content.isEmpty ? nil : content
    }

    private static func isChecklistLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("- [") || trimmed.hasPrefix("* [") else { return false }
        guard trimmed.count >= 6 else { return false }
        let checkIndex = trimmed.index(trimmed.startIndex, offsetBy: 3)
        let marker = trimmed[checkIndex]
        if marker != " " && marker.lowercased() != "x" {
            return false
        }
        let closeIndex = trimmed.index(trimmed.startIndex, offsetBy: 4)
        return trimmed[closeIndex] == "]"
    }
}
