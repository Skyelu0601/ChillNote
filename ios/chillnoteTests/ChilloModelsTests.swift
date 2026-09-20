import XCTest
@testable import chillnote

final class ChilloModelsTests: XCTestCase {
    func testTurnDecodesDurableJobAndSourceMetadata() throws {
        let data = Data(#"{"id":"turn","request":"Write a script","answer":"A fact [1]","status":"completed","sources":[{"number":1,"noteId":"note","availability":"active","title":"Source","excerpt":"Original text","platform":null}],"sourcesChanged":false,"draftNoteId":null,"errorCode":null}"#.utf8)
        let turn = try JSONDecoder().decode(ChilloTurn.self, from: data)
        XCTAssertFalse(turn.isActive)
        XCTAssertEqual(turn.sources.first?.noteId, "note")
        XCTAssertNil(turn.draftNoteId)
    }

    func testQueuedAndRunningAreTheOnlyActiveStatuses() throws {
        for status in ["queued", "running", "completed", "failed", "cancelled"] {
            let json = #"{"id":"turn","request":"Hi","answer":"","status":"STATUS","sources":[],"sourcesChanged":false}"#.replacingOccurrences(of: "STATUS", with: status)
            let turn = try JSONDecoder().decode(ChilloTurn.self, from: Data(json.utf8))
            XCTAssertEqual(turn.isActive, status == "queued" || status == "running")
        }
    }

    func testCitationsAreRemovedFromRenderedAnswer() {
        let rendered = ChilloCitationRenderer.render(
            answer: "**Bold heading:** supporting text [4](chillo-source://4)."
        )

        XCTAssertEqual(rendered.string, "Bold heading: supporting text.")
    }

    func testGroupedCitationsAreRemovedFromRenderedAnswer() {
        let rendered = ChilloCitationRenderer.render(
            answer: "Supported [4, 8]. Orphaned [9]."
        )

        XCTAssertEqual(rendered.string, "Supported. Orphaned.")
    }

    func testNotesUsedAreDeduplicatedByNote() {
        let first = ChilloSource(number: 1, noteId: "note", availability: "active", title: "Source", excerpt: "First", platform: nil)
        let second = ChilloSource(number: 4, noteId: "note", availability: "active", title: "Source", excerpt: "Second", platform: nil)
        let third = ChilloSource(number: 8, noteId: "other", availability: "active", title: "Other", excerpt: "Third", platform: nil)

        XCTAssertEqual(uniqueChilloSources([first, second, third]).map(\.noteId), ["note", "other"])
    }
}
