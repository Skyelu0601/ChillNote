import XCTest
@testable import chillnote

final class NotesExportPerformanceTests: XCTestCase {

    func testPerformanceFrontMatterSerializationForFiveThousandNotes() {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        var notes: [Note] = []
        notes.reserveCapacity(5_000)
        for index in 0..<5_000 {
            let note = Note(content: "# Note \(index)\n\nSome markdown content \(index)", userId: "user-1")
            note.createdAt = Date(timeIntervalSince1970: TimeInterval(1_738_800_000 + index))
            note.updatedAt = note.createdAt
            notes.append(note)
        }

        measure {
            for note in notes {
                _ = NotesExportFormatter.makeMarkdownDocument(note: note, isoFormatter: iso)
            }
        }
    }
}
