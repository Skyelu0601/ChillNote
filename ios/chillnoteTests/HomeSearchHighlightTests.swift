import XCTest
import SwiftUI
@testable import chillnote

final class HomeSearchHighlightTests: XCTestCase {
    func testPreviewExcerptCentersAroundMatch() {
        let text = "这是第一句。这是第二句。真正命中的关键片段在这里。后面还有很多补充说明。"

        let excerpt = SearchHighlightFormatter.makePreviewText(
            content: text,
            query: "关键片段",
            radius: 6
        )

        XCTAssertTrue(excerpt.contains("关键片段"))
        XCTAssertTrue(excerpt.hasPrefix("…"))
    }

    func testHighlightIsAccentInsensitive() {
        let highlighted = SearchHighlightFormatter.makeHighlightedText(
            text: "Meet me at the cafe",
            query: "café",
            baseColor: .primary,
            highlightColor: .primary,
            highlightBackground: .yellow
        )

        let runs = highlighted.runs.filter { $0.backgroundColor != nil }
        XCTAssertEqual(runs.count, 1)
        XCTAssertEqual(String(highlighted[runs[0].range].characters), "cafe")
    }
}
