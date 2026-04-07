import Foundation

enum RecordingGhostPromptStore {
    static let keys = [
        "recording.ghost_prompt.item_1",
        "recording.ghost_prompt.item_2",
        "recording.ghost_prompt.item_3",
        "recording.ghost_prompt.item_4",
        "recording.ghost_prompt.item_5",
        "recording.ghost_prompt.item_6"
    ]

    static let displayDuration: TimeInterval = 3.0

    static func randomIndex() -> Int {
        Int.random(in: 0..<keys.count)
    }

    static func text(at index: Int) -> String {
        guard !keys.isEmpty else { return "" }
        let normalizedIndex = index % keys.count
        return L10n.text(keys[normalizedIndex])
    }
}
