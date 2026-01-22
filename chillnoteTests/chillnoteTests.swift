//
//  chillnoteTests.swift
//  chillnoteTests
//
//  Created by 陆文婷 on 2026/1/5.
//

import XCTest
import SwiftData
@testable import chillnote

@MainActor
final class chillnoteTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUpWithError() throws {
        // Create in-memory container for testing
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
    
    func testChecklistMarkdownParsesEmptyItem() throws {
        let parsed = ChecklistMarkdown.parse("- [ ]")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.items.count, 1)
        XCTAssertEqual(parsed?.items.first?.isDone, false)
        XCTAssertEqual(parsed?.items.first?.text, "")
    }
    
    func testChecklistMarkdownParsesSingleUncheckedItem() throws {
        let parsed = ChecklistMarkdown.parse("- [ ] Buy groceries")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.items.count, 1)
        XCTAssertEqual(parsed?.items.first?.isDone, false)
        XCTAssertEqual(parsed?.items.first?.text, "Buy groceries")
    }
    
    func testChecklistMarkdownParsesSingleCheckedItem() throws {
        let parsed = ChecklistMarkdown.parse("- [x] Complete homework")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.items.count, 1)
        XCTAssertEqual(parsed?.items.first?.isDone, true)
        XCTAssertEqual(parsed?.items.first?.text, "Complete homework")
    }
    
    func testChecklistMarkdownParsesMultipleItems() throws {
        let content = """
        - [ ] Task 1
        - [x] Task 2
        - [ ] Task 3
        """
        let parsed = ChecklistMarkdown.parse(content)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.items.count, 3)
        XCTAssertEqual(parsed?.items[0].isDone, false)
        XCTAssertEqual(parsed?.items[0].text, "Task 1")
        XCTAssertEqual(parsed?.items[1].isDone, true)
        XCTAssertEqual(parsed?.items[1].text, "Task 2")
        XCTAssertEqual(parsed?.items[2].isDone, false)
        XCTAssertEqual(parsed?.items[2].text, "Task 3")
    }
    
    func testChecklistMarkdownParsesWithNotes() throws {
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
    
    func testChecklistMarkdownReturnsNilForPlainText() throws {
        let parsed = ChecklistMarkdown.parse("This is just plain text")
        XCTAssertNil(parsed)
    }
    
    func testChecklistMarkdownHandlesCapitalXAsChecked() throws {
        let parsed = ChecklistMarkdown.parse("- [X] Capital X")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.items.first?.isDone, true)
        XCTAssertEqual(parsed?.items.first?.text, "Capital X")
    }
    
    // MARK: - HTMLConverter Tests
    
    func testMarkdownToHTMLConvertsBoldText() throws {
        let markdown = "This is **bold** text"
        let html = HTMLConverter.markdownToHTML(markdown)
        XCTAssertTrue(html.contains("<strong>bold</strong>"))
    }
    
    func testMarkdownToHTMLConvertsItalicText() throws {
        let markdown = "This is *italic* text"
        let html = HTMLConverter.markdownToHTML(markdown)
        XCTAssertTrue(html.contains("<em>italic</em>"))
    }
    
    func testMarkdownToHTMLConvertsInlineCode() throws {
        let markdown = "Here is `code` snippet"
        let html = HTMLConverter.markdownToHTML(markdown)
        XCTAssertTrue(html.contains("<code>code</code>"))
    }
    
    func testMarkdownToHTMLConvertsHeading1() throws {
        let markdown = "# Heading 1"
        let html = HTMLConverter.markdownToHTML(markdown)
        XCTAssertTrue(html.contains("<h1>Heading 1</h1>"))
    }
    
    func testMarkdownToHTMLConvertsHeading2() throws {
        let markdown = "## Heading 2"
        let html = HTMLConverter.markdownToHTML(markdown)
        XCTAssertTrue(html.contains("<h2>Heading 2</h2>"))
    }
    
    func testMarkdownToHTMLConvertsHeading3() throws {
        let markdown = "### Heading 3"
        let html = HTMLConverter.markdownToHTML(markdown)
        XCTAssertTrue(html.contains("<h3>Heading 3</h3>"))
    }
    
    func testMarkdownToHTMLConvertsUnorderedList() throws {
        let markdown = """
        - Item 1
        - Item 2
        - Item 3
        """
        let html = HTMLConverter.markdownToHTML(markdown)
        XCTAssertTrue(html.contains("<ul>"))
        XCTAssertTrue(html.contains("<li>Item 1</li>"))
        XCTAssertTrue(html.contains("<li>Item 2</li>"))
        XCTAssertTrue(html.contains("<li>Item 3</li>"))
        XCTAssertTrue(html.contains("</ul>"))
    }
    
    func testMarkdownToHTMLConvertsOrderedList() throws {
        let markdown = """
        1. First
        2. Second
        3. Third
        """
        let html = HTMLConverter.markdownToHTML(markdown)
        XCTAssertTrue(html.contains("<ol>"))
        XCTAssertTrue(html.contains("<li>First</li>"))
        XCTAssertTrue(html.contains("<li>Second</li>"))
        XCTAssertTrue(html.contains("<li>Third</li>"))
        XCTAssertTrue(html.contains("</ol>"))
    }
    
    func testMarkdownToHTMLConvertsCheckboxUnchecked() throws {
        let markdown = "- [ ] Unchecked item"
        let html = HTMLConverter.markdownToHTML(markdown)
        XCTAssertTrue(html.contains("checkbox-unchecked"))
        XCTAssertTrue(html.contains("Unchecked item"))
    }
    
    func testMarkdownToHTMLConvertsCheckboxChecked() throws {
        let markdown = "- [x] Checked item"
        let html = HTMLConverter.markdownToHTML(markdown)
        XCTAssertTrue(html.contains("checkbox-checked"))
        XCTAssertTrue(html.contains("strikethrough"))
        XCTAssertTrue(html.contains("Checked item"))
    }
    
    func testMarkdownToHTMLConvertsBlockquote() throws {
        let markdown = "> This is a quote"
        let html = HTMLConverter.markdownToHTML(markdown)
        XCTAssertTrue(html.contains("<blockquote>This is a quote</blockquote>"))
    }
    
    func testMarkdownToHTMLConvertsHorizontalRule() throws {
        let markdown = "---"
        let html = HTMLConverter.markdownToHTML(markdown)
        XCTAssertTrue(html.contains("<hr>"))
    }
    
    func testMarkdownToHTMLEscapesHTMLEntities() throws {
        let markdown = "Text with <html> & special chars"
        let html = HTMLConverter.markdownToHTML(markdown)
        XCTAssertTrue(html.contains("&lt;html&gt;"))
        XCTAssertTrue(html.contains("&amp;"))
    }
    
    func testMarkdownToHTMLHandlesEmptyLines() throws {
        let markdown = """
        Paragraph 1
        
        Paragraph 2
        """
        let html = HTMLConverter.markdownToHTML(markdown)
        XCTAssertTrue(html.contains("<p>Paragraph 1</p>"))
        XCTAssertTrue(html.contains("<br>"))
        XCTAssertTrue(html.contains("<p>Paragraph 2</p>"))
    }
    
    func testHTMLToPlainTextExtractsText() throws {
        let html = "<p><strong>Bold</strong> and <em>italic</em> text</p>"
        let plainText = HTMLConverter.htmlToPlainText(html)
        XCTAssertTrue(plainText.contains("Bold"))
        XCTAssertTrue(plainText.contains("italic"))
        XCTAssertFalse(plainText.contains("<p>"))
        XCTAssertFalse(plainText.contains("<strong>"))
    }

    // MARK: - Note Model Tests
    
    func testNoteInitializesWithPlainText() throws {
        let note = Note(content: "Hello World")
        XCTAssertEqual(note.content, "Hello World")
        XCTAssertEqual(note.contentFormat, NoteContentFormat.text.rawValue)
        XCTAssertNil(note.contentHTML)
        XCTAssertFalse(note.isChecklist)
        XCTAssertFalse(note.isHTMLFormat)
    }
    
    func testNoteInitializesWithChecklistContent() throws {
        let content = """
        - [ ] Task 1
        - [x] Task 2
        """
        let note = Note(content: content)
        XCTAssertTrue(note.isChecklist)
        XCTAssertEqual(note.contentFormat, NoteContentFormat.checklist.rawValue)
        XCTAssertEqual(note.checklistItems.count, 2)
        XCTAssertEqual(note.checklistItems[0].text, "Task 1")
        XCTAssertEqual(note.checklistItems[0].isDone, false)
        XCTAssertEqual(note.checklistItems[1].text, "Task 2")
        XCTAssertEqual(note.checklistItems[1].isDone, true)
    }
    
    func testNoteInitializesWithHTMLContent() throws {
        let html = "<p>Hello <strong>World</strong></p>"
        let note = Note(htmlContent: html)
        XCTAssertEqual(note.contentHTML, html)
        XCTAssertEqual(note.contentFormat, NoteContentFormat.html.rawValue)
        XCTAssertTrue(note.isHTMLFormat)
        XCTAssertTrue(note.content.contains("Hello"))
        XCTAssertTrue(note.content.contains("World"))
    }
    
    func testNoteDisplayTextTruncatesLongContent() throws {
        let longText = String(repeating: "a", count: 250)
        let note = Note(content: longText)
        let displayText = note.displayText
        XCTAssertTrue(displayText.count <= 203) // 200 chars + "..."
        XCTAssertTrue(displayText.hasSuffix("..."))
    }
    
    func testNoteDisplayTextDoesNotTruncateShortContent() throws {
        let shortText = "Short note"
        let note = Note(content: shortText)
        XCTAssertEqual(note.displayText, shortText)
    }
    
    func testNoteMigrateToHTMLConvertsMarkdown() throws {
        let note = Note(content: "**Bold** text")
        XCTAssertFalse(note.isHTMLFormat)
        
        note.migrateToHTML()
        
        XCTAssertTrue(note.isHTMLFormat)
        XCTAssertNotNil(note.contentHTML)
        XCTAssertTrue(note.contentHTML?.contains("<strong>Bold</strong>") ?? false)
    }
    
    func testNoteMigrateToHTMLIsIdempotent() throws {
        let note = Note(content: "Test")
        note.migrateToHTML()
        let htmlAfterFirst = note.contentHTML
        
        note.migrateToHTML()
        
        XCTAssertEqual(note.contentHTML, htmlAfterFirst)
    }
    
    func testNoteMarkDeletedSetsDeletedAt() throws {
        let note = Note(content: "Test")
        XCTAssertNil(note.deletedAt)
        
        note.markDeleted()
        
        XCTAssertNotNil(note.deletedAt)
        XCTAssertEqual(note.deletedAt, note.updatedAt)
    }
    
    func testNoteEditableHTMLReturnsHTMLForHTMLFormat() throws {
        let html = "<p>Test HTML</p>"
        let note = Note(htmlContent: html)
        XCTAssertEqual(note.editableHTML, html)
    }
    
    func testNoteEditableHTMLConvertsMarkdownForTextFormat() throws {
        let note = Note(content: "**Bold** text")
        let editableHTML = note.editableHTML
        XCTAssertTrue(editableHTML.contains("<strong>Bold</strong>"))
    }

    // MARK: - Tag Model Tests
    
    func testTagInitializesWithDefaults() throws {
        let tag = Tag(name: "Work")
        XCTAssertEqual(tag.name, "Work")
        XCTAssertEqual(tag.colorHex, "#E6A355")
        XCTAssertTrue(tag.isRoot)
        XCTAssertEqual(tag.children.count, 0)
        XCTAssertNil(tag.parent)
    }
    
    func testTagIsRootReturnsTrueForRootTag() throws {
        let tag = Tag(name: "Root")
        XCTAssertTrue(tag.isRoot)
    }
    
    func testTagIsRootReturnsFalseForChildTag() throws {
        let parent = Tag(name: "Parent")
        let child = Tag(name: "Child")
        child.parent = parent
        parent.children.append(child)
        
        XCTAssertFalse(child.isRoot)
        XCTAssertTrue(parent.isRoot)
    }
    
    func testTagFullPathReturnsCorrectPath() throws {
        let root = Tag(name: "Work")
        let middle = Tag(name: "AI")
        let leaf = Tag(name: "LLM")
        
        middle.parent = root
        leaf.parent = middle
        root.children.append(middle)
        middle.children.append(leaf)
        
        XCTAssertEqual(leaf.fullPath, "Work > AI > LLM")
        XCTAssertEqual(middle.fullPath, "Work > AI")
        XCTAssertEqual(root.fullPath, "Work")
    }
    
    func testTagAncestorsReturnsCorrectOrder() throws {
        let root = Tag(name: "Work")
        let middle = Tag(name: "AI")
        let leaf = Tag(name: "LLM")
        
        middle.parent = root
        leaf.parent = middle
        
        let ancestors = leaf.ancestors
        XCTAssertEqual(ancestors.count, 2)
        XCTAssertEqual(ancestors[0].name, "Work")
        XCTAssertEqual(ancestors[1].name, "AI")
    }
    
    func testTagAllDescendantsReturnsAllChildren() throws {
        let root = Tag(name: "Work")
        let child1 = Tag(name: "AI")
        let child2 = Tag(name: "Product")
        let grandchild = Tag(name: "LLM")
        
        child1.parent = root
        child2.parent = root
        grandchild.parent = child1
        
        root.children.append(child1)
        root.children.append(child2)
        child1.children.append(grandchild)
        
        let descendants = root.allDescendants
        XCTAssertEqual(descendants.count, 3)
        XCTAssertTrue(descendants.contains { $0.name == "AI" })
        XCTAssertTrue(descendants.contains { $0.name == "Product" })
        XCTAssertTrue(descendants.contains { $0.name == "LLM" })
    }
    
    func testTagIsAncestorReturnsTrue() throws {
        let root = Tag(name: "Work")
        let middle = Tag(name: "AI")
        let leaf = Tag(name: "LLM")
        
        middle.parent = root
        leaf.parent = middle
        
        XCTAssertTrue(root.isAncestor(of: leaf))
        XCTAssertTrue(root.isAncestor(of: middle))
        XCTAssertTrue(middle.isAncestor(of: leaf))
    }
    
    func testTagIsAncestorReturnsFalse() throws {
        let tag1 = Tag(name: "Work")
        let tag2 = Tag(name: "Life")
        
        XCTAssertFalse(tag1.isAncestor(of: tag2))
        XCTAssertFalse(tag2.isAncestor(of: tag1))
    }

    // MARK: - Date Extension Tests
    
    func testDateRelativeFormattedReturnsTimeForToday() throws {
        let now = Date()
        let formatted = now.relativeFormatted()
        
        // Should contain time in HH:mm format
        let timePattern = #"^\d{2}:\d{2}$"#
        let regex = try NSRegularExpression(pattern: timePattern)
        let range = NSRange(formatted.startIndex..., in: formatted)
        XCTAssertNotNil(regex.firstMatch(in: formatted, range: range))
    }
    
    func testDateRelativeFormattedReturnsYesterdayForYesterday() throws {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let formatted = yesterday.relativeFormatted()
        XCTAssertTrue(formatted.starts(with: "Yesterday"))
    }
    
    func testDateRelativeFormattedReturnsWeekdayForThisWeek() throws {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let formatted = threeDaysAgo.relativeFormatted()
        
        // Should contain weekday name (e.g., "Monday 14:30")
        let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        XCTAssertTrue(weekdays.contains { formatted.starts(with: $0) })
    }
    
    func testDateRelativeFormattedReturnsMonthDayForThisYear() throws {
        let twoMonthsAgo = Calendar.current.date(byAdding: .month, value: -2, to: Date())!
        let formatted = twoMonthsAgo.relativeFormatted()
        
        // Should contain month abbreviation (e.g., "Jan 10 14:30")
        let monthAbbreviations = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        XCTAssertTrue(monthAbbreviations.contains { formatted.contains($0) })
    }
    
    func testDateRelativeFormattedReturnsFullDateForOverAYear() throws {
        let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        let formatted = twoYearsAgo.relativeFormatted()
        
        // Should be in yyyy/MM/dd format
        let datePattern = #"^\d{4}/\d{2}/\d{2}$"#
        let regex = try NSRegularExpression(pattern: datePattern)
        let range = NSRange(formatted.startIndex..., in: formatted)
        XCTAssertNotNil(regex.firstMatch(in: formatted, range: range))
    }
    
    // MARK: - Language Detection Tests
    
    func testLanguageDetectionReturnsChineseForChineseText() throws {
        let text = """
        今天天气很好，我们计划下午去公园散步，然后一起喝咖啡聊聊天。这是一段用于语言识别的较长中文文本。
        """
        let tag = LanguageDetection.dominantLanguageTag(for: text)
        XCTAssertNotNil(tag)
        XCTAssertTrue(tag?.hasPrefix("zh") == true)
    }

    func testLanguageDetectionReturnsEnglishForEnglishText() throws {
        let text = """
        This is a longer piece of English text used for language identification. It should be reliably detected as English by the language recognizer.
        """
        let tag = LanguageDetection.dominantLanguageTag(for: text)
        XCTAssertNotNil(tag)
        XCTAssertTrue(tag?.hasPrefix("en") == true)
    }
    
    func testLanguageDetectionReturnsNilForEmptyText() throws {
        let tag = LanguageDetection.dominantLanguageTag(for: "")
        XCTAssertNil(tag)
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceMarkdownToHTML() throws {
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
            _ = HTMLConverter.markdownToHTML(markdown)
        }
    }
    
    func testPerformanceChecklistParsing() throws {
        let content = (1...100).map { "- [ ] Task \($0)" }.joined(separator: "\n")
        
        measure {
            _ = ChecklistMarkdown.parse(content)
        }
    }
}
