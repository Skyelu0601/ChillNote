import XCTest
@testable import chillnote

final class NotesExportFormatterTests: XCTestCase {

    func testSanitizeFileComponentRemovesIllegalCharacters() {
        let sanitized = NotesExportFormatter.sanitizeFileComponent("*:/\\?\"<>|  My   Note  ")
        XCTAssertEqual(sanitized, "--------- My Note")
    }

    func testMakeNoteFilenameHandlesDuplicates() {
        var used: Set<String> = []
        var counter: [String: Int] = [:]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let date = Date(timeIntervalSince1970: 1_738_800_000)
        let noteID = UUID(uuidString: "12345678-1234-1234-1234-1234567890AB")!

        let first = NotesExportFormatter.makeNoteFilename(
            content: "# Title",
            createdAt: date,
            noteId: noteID,
            usedNames: &used,
            collisionCounter: &counter,
            timestampFormatter: formatter
        )

        let second = NotesExportFormatter.makeNoteFilename(
            content: "# Title",
            createdAt: date,
            noteId: noteID,
            usedNames: &used,
            collisionCounter: &counter,
            timestampFormatter: formatter
        )

        XCTAssertEqual(first, "# Title-20250206-000000-123456.md")
        XCTAssertEqual(second, "# Title-20250206-000000-123456-2.md")
    }

    func testMakeMarkdownDocumentIncludesFrontMatterAndEscapesValues() {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        let note = Note(content: "Hello **world**", userId: "user\"A")
        note.createdAt = Date(timeIntervalSince1970: 1_738_800_000)

        let tagA = Tag(name: "Tag\"One", userId: "user")
        let tagB = Tag(name: "tag-two", userId: "user")
        note.tags = [tagA, tagB]

        let markdown = NotesExportFormatter.makeMarkdownDocument(note: note, isoFormatter: iso)

        XCTAssertTrue(markdown.contains("created_at: \"\(iso.string(from: note.createdAt))\""))
        XCTAssertTrue(markdown.contains("tags: [\"Tag\\\"One\", \"tag-two\"]"))
        XCTAssertFalse(markdown.contains("id:"))
        XCTAssertFalse(markdown.contains("user_id:"))
        XCTAssertFalse(markdown.contains("updated_at:"))
        XCTAssertFalse(markdown.contains("content_format:"))
        XCTAssertFalse(markdown.contains("source:"))
        XCTAssertTrue(markdown.contains("Hello **world**"))
    }
}
