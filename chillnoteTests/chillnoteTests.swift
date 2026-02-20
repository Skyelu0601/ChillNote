import XCTest
import SwiftData
@testable import chillnote

@MainActor
final class chillnoteTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([Note.self, Tag.self, ChecklistItem.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = modelContainer.mainContext
    }

    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
    }

    // MARK: - ChecklistMarkdown Tests

    func testChecklistMarkdownParsesEmptyItem() {
        let parsed = ChecklistMarkdown.parse("- [ ]")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.items.count, 1)
        XCTAssertEqual(parsed?.items.first?.isDone, false)
        XCTAssertEqual(parsed?.items.first?.text, "")
    }

    func testChecklistMarkdownParsesSingleUncheckedItem() {
        let parsed = ChecklistMarkdown.parse("- [ ] Buy groceries")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.items.count, 1)
        XCTAssertEqual(parsed?.items.first?.isDone, false)
        XCTAssertEqual(parsed?.items.first?.text, "Buy groceries")
    }

    func testChecklistMarkdownParsesSingleCheckedItem() {
        let parsed = ChecklistMarkdown.parse("- [x] Complete homework")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.items.count, 1)
        XCTAssertEqual(parsed?.items.first?.isDone, true)
        XCTAssertEqual(parsed?.items.first?.text, "Complete homework")
    }

    func testChecklistMarkdownParsesWithNotes() {
        let content = """
        Shopping List

        - [ ] Milk
        - [ ] Bread
        - [x] Eggs
        """
        let parsed = ChecklistMarkdown.parse(content)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.notes, "Shopping List")
        XCTAssertEqual(parsed?.items.count, 3)
    }

    func testChecklistMarkdownReturnsNilForPlainText() {
        let parsed = ChecklistMarkdown.parse("This is just plain text")
        XCTAssertNil(parsed)
    }

    // MARK: - Note Model Tests

    func testNoteInitializesWithPlainText() {
        let note = Note(content: "Hello World", userId: "u1")
        XCTAssertEqual(note.content, "Hello World")
        XCTAssertEqual(note.contentFormat, NoteContentFormat.text.rawValue)
        XCTAssertFalse(note.isChecklist)
        XCTAssertEqual(note.userId, "u1")
    }

    func testNoteInitializesWithChecklistContent() {
        let content = """
        - [ ] Task 1
        - [x] Task 2
        """
        let note = Note(content: content, userId: "u1")
        XCTAssertTrue(note.isChecklist)
        XCTAssertEqual(note.contentFormat, NoteContentFormat.checklist.rawValue)
        XCTAssertEqual(note.checklistItems.count, 2)
        XCTAssertEqual(note.checklistItems[0].text, "Task 1")
        XCTAssertEqual(note.checklistItems[0].isDone, false)
        XCTAssertEqual(note.checklistItems[1].text, "Task 2")
        XCTAssertEqual(note.checklistItems[1].isDone, true)
    }

    func testNoteDisplayTextTruncatesLongContent() {
        let longText = String(repeating: "a", count: 250)
        let note = Note(content: longText, userId: "u1")
        let displayText = note.displayText
        XCTAssertTrue(displayText.count <= 203)
        XCTAssertTrue(displayText.hasSuffix("..."))
    }

    func testNoteDisplayTextDoesNotTruncateShortContent() {
        let shortText = "Short note"
        let note = Note(content: shortText, userId: "u1")
        XCTAssertEqual(note.displayText, shortText)
    }

    func testNoteDisplayTextUsesLatestContentWhenPreviewCacheIsStale() {
        let note = Note(content: "- [x] Buy milk", userId: "u1")
        note.previewPlainText = "☐ Buy milk"

        XCTAssertEqual(note.displayText, "☑ Buy milk")
    }

    func testNoteMarkDeletedSetsDeletedAt() {
        let note = Note(content: "Test", userId: "u1")
        XCTAssertNil(note.deletedAt)

        note.markDeleted()

        XCTAssertNotNil(note.deletedAt)
        XCTAssertEqual(note.deletedAt, note.updatedAt)
    }

    // MARK: - Tag Model Tests

    func testTagInitializesWithDefaults() {
        let tag = Tag(name: "Work", userId: "u1")
        XCTAssertEqual(tag.name, "Work")
        XCTAssertEqual(tag.userId, "u1")
        XCTAssertEqual(tag.colorHex, "#E6A355")
        XCTAssertTrue(tag.isRoot)
        XCTAssertEqual(tag.children.count, 0)
        XCTAssertNil(tag.parent)
    }

    func testTagHierarchyHelpers() {
        let root = Tag(name: "Work", userId: "u1")
        let middle = Tag(name: "AI", userId: "u1")
        let leaf = Tag(name: "LLM", userId: "u1")

        middle.parent = root
        leaf.parent = middle
        root.children.append(middle)
        middle.children.append(leaf)

        XCTAssertEqual(leaf.fullPath, "Work > AI > LLM")
        XCTAssertTrue(root.isAncestor(of: leaf))
        XCTAssertEqual(root.allDescendants.count, 2)
        XCTAssertEqual(leaf.ancestors.map(\.name), ["Work", "AI"])
    }

    func testTagColorServiceAutoColorSkipsDeletedTagsInRotation() {
        let keep1 = Tag(name: "Keep 1", userId: "u1", colorHex: TagColorService.paletteHexes[0])
        let keep2 = Tag(name: "Keep 2", userId: "u1", colorHex: TagColorService.paletteHexes[1])
        let deleted = Tag(name: "Deleted", userId: "u1", colorHex: TagColorService.paletteHexes[8])
        deleted.deletedAt = Date()

        let existing = [keep1, keep2, deleted]
        let assigned = TagColorService.autoColorHex(for: "New Tag", existingTags: existing)

        XCTAssertEqual(assigned, TagColorService.paletteHexes[2])
    }

    func testTagColorServiceNormalizesHexInput() {
        XCTAssertEqual(TagColorService.normalizedHex("  e6a355 "), "#E6A355")
        XCTAssertEqual(TagColorService.normalizedHex("invalid"), TagColorService.defaultColorHex)
    }

    // MARK: - Date Extension Tests

    func testDateRelativeFormattedReturnsSomething() {
        let now = Date()
        let formatted = now.relativeFormatted()
        XCTAssertFalse(formatted.isEmpty)
    }

    func testDateRelativeFormattedForPastDate() {
        let oldDate = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        let formatted = oldDate.relativeFormatted()
        XCTAssertFalse(formatted.isEmpty)
    }

    // MARK: - Language Detection Tests

    func testLanguageDetectionReturnsChineseForChineseText() {
        let text = "今天天气很好，我们计划下午去公园散步，然后一起喝咖啡聊天。"
        let tag = LanguageDetection.dominantLanguageTag(for: text)
        XCTAssertNotNil(tag)
        XCTAssertTrue(tag?.hasPrefix("zh") == true)
    }

    func testLanguageDetectionReturnsEnglishForEnglishText() {
        let text = "This is a longer piece of English text used for language identification."
        let tag = LanguageDetection.dominantLanguageTag(for: text)
        XCTAssertNotNil(tag)
        XCTAssertTrue(tag?.hasPrefix("en") == true)
    }

    // MARK: - Performance Tests

    func testPerformanceChecklistParsing() {
        let content = (1...100).map { "- [ ] Task \($0)" }.joined(separator: "\n")

        measure {
            _ = ChecklistMarkdown.parse(content)
        }
    }

    func testPerformanceNormalizeContent() {
        let markdown = """
        # Heading 1
        ## Heading 2

        This is **bold** and *italic* text with `code`.

        - Item 1
        - Item 2
        - Item 3

        1. First
        2. Second
        3. Third
        """

        measure {
            _ = NoteTextNormalizer.normalizeContent(markdown)
        }
    }
}
