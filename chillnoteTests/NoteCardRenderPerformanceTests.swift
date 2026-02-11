import XCTest
@testable import chillnote

final class NoteCardRenderPerformanceTests: XCTestCase {
    func testBuildListItemViewDataFromFiveThousandNotes() {
        let notes: [Note] = (0..<5_000).map { idx in
            let note = Note(content: "# Header \(idx)\n\n- [ ] item", userId: "u1")
            return note
        }

        measure {
            _ = notes.map { NoteListItemViewData(note: $0, usePlainPreview: true) }
        }
    }
}
