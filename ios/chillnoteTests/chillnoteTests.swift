import XCTest
import SwiftData
import SwiftUI
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
        let longText = String(repeating: "a", count: 400)
        let note = Note(content: longText, userId: "u1")
        let displayText = note.displayText
        XCTAssertTrue(displayText.count < longText.count)
        XCTAssertTrue(displayText.hasSuffix("..."))
    }

    func testNoteDisplayTextDoesNotTruncateShortContent() {
        let shortText = "Short note"
        let note = Note(content: shortText, userId: "u1")
        XCTAssertEqual(note.displayText, shortText)
    }

    func testNoteUpdateContentRefreshesPersistedPreview() {
        let note = Note(content: "Old text", userId: "u1")

        note.updateContent("# New text")

        XCTAssertEqual(note.content, "# New text")
        XCTAssertEqual(note.previewPlainText, "New text")
    }

    func testNoteDisplayTextUsesLatestContentWhenPreviewCacheIsStale() {
        let note = Note(content: "- [x] Buy milk", userId: "u1")
        note.previewPlainText = "☐ Buy milk"

        XCTAssertEqual(note.displayText, "\(RichTextConverter.Config.checkboxCheckedSymbol) Buy milk")
    }

    func testNoteDisplayTextRemovesMarkdownMarkersFromEveryLine() {
        let note = Note(
            content: """
            # Main idea
            ## Supporting point
            - First detail
            • Second detail
            """,
            userId: "u1"
        )

        XCTAssertEqual(
            note.displayText,
            """
            Main idea
            Supporting point
            First detail
            Second detail
            """
        )
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
        XCTAssertEqual(tag.colorHex, TagColorService.defaultColorHex)
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

    // MARK: - Transcription Content Validation Tests

    func testTranscriptionValidatorRejectsProviderEmptyPrompt() {
        let raw = "This transcript appears to be empty or contains only timestamps. Please provide actual speech content for processing."
        let normalized = TranscriptionContentValidator.normalizedTranscriptOrNil(raw)
        XCTAssertNil(normalized)
    }

    func testTranscriptionValidatorRejectsTimestampOnlyLines() {
        let raw = """
        00:00
        [00:12]
        01:03:33
        """
        let normalized = TranscriptionContentValidator.normalizedTranscriptOrNil(raw)
        XCTAssertNil(normalized)
    }

    func testTranscriptionValidatorKeepsNormalTranscript() {
        let raw = "今天复盘一下上周项目，先看发布节奏，再看用户反馈。"
        let normalized = TranscriptionContentValidator.normalizedTranscriptOrNil(raw)
        XCTAssertEqual(normalized, raw)
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

    // MARK: - Rich Text Layout Tests

    func testRichTextConverterUsesConsistentParagraphSpacingForChecklistAndBullet() {
        let markdown = """
        - [ ] Task
        - Bullet
        """

        let attributed = RichTextConverter.markdownToAttributedString(markdown)
        let nsString = attributed.string as NSString

        let checklistAttrs = attributed.attributes(at: 0, effectiveRange: nil)
        let bulletLocation = nsString.range(of: "• ").location
        XCTAssertNotEqual(bulletLocation, NSNotFound)
        let bulletAttrs = attributed.attributes(at: bulletLocation, effectiveRange: nil)

        let checklistStyle = checklistAttrs[.paragraphStyle] as? NSParagraphStyle
        let bulletStyle = bulletAttrs[.paragraphStyle] as? NSParagraphStyle

        XCTAssertEqual(checklistStyle?.paragraphSpacing, RichTextConverter.Config.baseStyle().paragraphSpacing)
        XCTAssertEqual(bulletStyle?.paragraphSpacing, RichTextConverter.Config.baseStyle().paragraphSpacing)
        XCTAssertEqual(checklistStyle?.lineSpacing, bulletStyle?.lineSpacing)
    }

    func testRichTextConverterAppliesHeaderParagraphSpacingBefore() {
        let attributed = RichTextConverter.markdownToAttributedString("# Heading")
        let attrs = attributed.attributes(at: 0, effectiveRange: nil)
        let style = attrs[.paragraphStyle] as? NSParagraphStyle

        XCTAssertEqual(style?.paragraphSpacingBefore, RichTextConverter.Config.headerStyle(level: 1).paragraphSpacingBefore)
    }

    func testRichTextConverterRoundTripsMixedChecklistBulletAndHeaderMarkdown() {
        let markdown = """
        - [ ] Task 1
        - Bullet 1
        # Heading
        - [x] Done
        """

        let attributed = RichTextConverter.markdownToAttributedString(markdown)
        let roundTrip = RichTextConverter.attributedStringToMarkdown(attributed)

        XCTAssertEqual(roundTrip, markdown)
    }

    func testRichTextConverterRoundTripsLocalImageMarkdown() {
        let markdown = "![](file:///tmp/chillnote-test-image.jpg)"

        let attributed = RichTextConverter.markdownToAttributedString(markdown)
        let roundTrip = RichTextConverter.attributedStringToMarkdown(attributed)

        XCTAssertEqual(roundTrip, markdown)
    }

    func testRichTextConverterPreservesTrailingNewlines() {
        for markdown in ["Line\n", "Line\n\n", "\n", "First\n\nLast\n"] {
            let attributed = RichTextConverter.markdownToAttributedString(markdown)
            XCTAssertEqual(RichTextConverter.attributedStringToMarkdown(attributed), markdown)
        }
    }

    func testRichTextConverterPreservesIntentionalInteriorBlankLineAndNaturalSpacing() {
        let markdown = "First paragraph.\n\nSecond paragraph."
        let rendered = RichTextConverter.markdownToAttributedString(markdown)

        XCTAssertEqual(rendered.string, markdown)
        XCTAssertEqual(RichTextConverter.attributedStringToMarkdown(rendered), markdown)

        let secondParagraphLocation = (rendered.string as NSString).range(of: "Second paragraph.").location
        let style = rendered.attribute(
            .paragraphStyle,
            at: secondParagraphLocation,
            effectiveRange: nil
        ) as? NSParagraphStyle
        XCTAssertEqual(style?.paragraphSpacing, RichTextConverter.Config.baseStyle().paragraphSpacing)
        XCTAssertEqual(style?.lineSpacing, RichTextConverter.Config.baseStyle().lineSpacing)
    }

    func testRichTextConverterPreservesIntentionalBlankLinesAroundHeadings() {
        let markdown = "## Description\n\nTitle\n\n## Author\n\nCreator"
        let rendered = RichTextConverter.markdownToAttributedString(markdown)

        XCTAssertEqual(rendered.string, "Description\n\nTitle\n\nAuthor\n\nCreator")
        XCTAssertEqual(RichTextConverter.attributedStringToMarkdown(rendered), markdown)
    }

    func testRichTextConverterKeepsBlockquoteAndInlineCodeSemanticsSeparate() {
        let markdown = "> Quote\n\nPlain `code` text"
        let attributed = RichTextConverter.markdownToAttributedString(markdown)

        XCTAssertEqual(RichTextConverter.attributedStringToMarkdown(attributed), markdown)
    }

    func testRichTextConverterEscapesMarkdownLookingPlainText() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17),
            .foregroundColor: UIColor.label,
            .paragraphStyle: RichTextConverter.Config.baseStyle()
        ]
        let pastedText = NSAttributedString(string: "# Copied heading", attributes: attributes)

        let markdown = RichTextConverter.attributedStringToMarkdown(pastedText)
        let renderedAgain = RichTextConverter.markdownToAttributedString(markdown)

        XCTAssertEqual(markdown, "\\# Copied heading")
        XCTAssertEqual(renderedAgain.string, "# Copied heading")
        XCTAssertEqual((renderedAgain.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)?.pointSize, 17)
        XCTAssertNil(renderedAgain.attribute(RichTextConverter.Key.headerLevel, at: 0, effectiveRange: nil))
    }

    func testRichTextSelectionMappingHandlesEmojiInsideBoldText() {
        let attributed = RichTextConverter.markdownToAttributedString("A **😀B** C")
        let snapshot = RichTextConverter.serializationSnapshot(from: attributed)
        let visualEmojiAndB = (attributed.string as NSString).range(of: "😀B")

        let selection = snapshot.markdownSelection(for: visualEmojiAndB)

        XCTAssertEqual(selection.location, 4)
        XCTAssertEqual(selection.length, 2)
        XCTAssertEqual(selection.selectedText, "😀B")
        XCTAssertEqual(
            snapshot.visualRange(forMarkdownLocation: selection.location, length: selection.length),
            visualEmojiAndB
        )
    }

    func testRichTextSelectionAfterTodoDoesNotIncludeCheckbox() {
        for markdown in ["- [ ] Buy milk", "- [x] Buy milk"] {
            let attributed = RichTextConverter.markdownToAttributedString(markdown)
            let contentRange = (attributed.string as NSString).range(of: "Buy milk")
            let snapshot = RichTextConverter.serializationSnapshot(from: attributed)
            let markdownSelection = snapshot.markdownSelection(for: contentRange)

            XCTAssertNil(attributed.attribute(.attachment, at: 0, effectiveRange: nil))
            XCTAssertEqual(
                snapshot.visualRange(
                    forMarkdownLocation: markdownSelection.location,
                    length: markdownSelection.length
                ),
                contentRange
            )
        }
    }

    func testMarkdownEditorSessionNormalizesPasteAndMatchesBaseFont() {
        let textView = UITextView()
        let session = MarkdownEditorSession(baseFont: .systemFont(ofSize: 17), textColor: .label)

        session.pastePlainText("# Large\r\n\r\n  \r\nNormal\u{00A0}text", into: textView)

        XCTAssertEqual(textView.text, "# Large\nNormal text")
        let secondLineLocation = (textView.text as NSString).range(of: "Normal").location
        XCTAssertEqual((textView.textStorage.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)?.pointSize, 17)
        XCTAssertEqual((textView.textStorage.attribute(.font, at: secondLineLocation, effectiveRange: nil) as? UIFont)?.pointSize, 17)
        XCTAssertEqual(RichTextConverter.attributedStringToMarkdown(textView.attributedText), "\\# Large\nNormal text")
        XCTAssertEqual(MarkdownEditorSession.normalizePastedText("\n\nFirst\n\nLast\n\n"), "\nFirst\nLast\n")
    }

    func testRichTextEditorDefersMarkdownCommitUntilExplicitFlush() {
        var markdown = "Original"
        var selection = RichTextEditorSelection()
        let controller = RichTextEditorController()
        let editor = RichTextEditorView(
            text: Binding(get: { markdown }, set: { markdown = $0 }),
            selection: Binding(get: { selection }, set: { selection = $0 }),
            controller: controller
        )
        let coordinator = editor.makeCoordinator()
        let textView = InteractiveTextView(usingTextLayoutManager: true)
        textView.delegate = coordinator
        coordinator.textView = textView

        let initialSnapshot = coordinator.editorSession.applyExternalMarkdown(
            markdown,
            to: textView,
            markdownSelection: selection
        )
        coordinator.acceptExternalMarkdown(markdown, snapshot: initialSnapshot)
        textView.attributedText = RichTextConverter.markdownToAttributedString("Changed")

        coordinator.textViewDidChange(textView)
        XCTAssertEqual(markdown, "Original")

        coordinator.flushPendingChanges()
        XCTAssertEqual(markdown, "Changed")
        XCTAssertNotNil(textView.textLayoutManager)
    }

    func testRichTextEditorCheckboxTapTogglesAndPersistsImmediately() {
        var markdown = "- [ ] Buy milk"
        var selection = RichTextEditorSelection()
        let controller = RichTextEditorController()
        let editor = RichTextEditorView(
            text: Binding(get: { markdown }, set: { markdown = $0 }),
            selection: Binding(get: { selection }, set: { selection = $0 }),
            controller: controller
        )
        let coordinator = editor.makeCoordinator()
        let textView = InteractiveTextView(usingTextLayoutManager: true)
        textView.delegate = coordinator
        coordinator.textView = textView
        let snapshot = coordinator.editorSession.applyExternalMarkdown(
            markdown,
            to: textView,
            markdownSelection: selection
        )
        coordinator.acceptExternalMarkdown(markdown, snapshot: snapshot)

        var checkboxRange = NSRange(location: 0, length: 0)
        _ = textView.textStorage.attribute(
            RichTextConverter.Key.checkbox,
            at: 0,
            effectiveRange: &checkboxRange
        )
        coordinator.toggleCheckbox(at: checkboxRange, in: textView)

        XCTAssertEqual(markdown, "- [x] Buy milk")
        XCTAssertTrue(textView.text.hasPrefix("☑ "))
        XCTAssertNotNil(textView.textStorage.attribute(.strikethroughStyle, at: 2, effectiveRange: nil))
    }

    func testRichTextEditorChecklistToolbarActionPersistsImmediately() {
        var markdown = "Buy milk"
        var selection = RichTextEditorSelection()
        let controller = RichTextEditorController()
        let editor = RichTextEditorView(
            text: Binding(get: { markdown }, set: { markdown = $0 }),
            selection: Binding(get: { selection }, set: { selection = $0 }),
            controller: controller
        )
        let coordinator = editor.makeCoordinator()
        let textView = InteractiveTextView(usingTextLayoutManager: true)
        textView.delegate = coordinator
        coordinator.textView = textView
        let snapshot = coordinator.editorSession.applyExternalMarkdown(
            markdown,
            to: textView,
            markdownSelection: selection
        )
        coordinator.acceptExternalMarkdown(markdown, snapshot: snapshot)
        textView.selectedRange = NSRange(location: 0, length: 0)

        coordinator.handleToolbarAction(.checklist, in: textView)

        XCTAssertEqual(markdown, "- [ ] Buy milk")
        XCTAssertTrue(textView.text.hasPrefix("☐ "))
    }

    func testRichTextEditorCheckboxTapHitTestingWorksWithTextKit2() {
        let textView = InteractiveTextView(usingTextLayoutManager: true)
        textView.installCheckboxTapHandling()
        textView.frame = CGRect(x: 0, y: 0, width: 320, height: 120)
        textView.attributedText = RichTextConverter.markdownToAttributedString("- [ ] Buy milk")
        textView.layoutIfNeeded()

        let start = textView.position(from: textView.beginningOfDocument, offset: 0)!
        let end = textView.position(from: start, offset: 1)!
        let checkboxTextRange = textView.textRange(from: start, to: end)!
        let checkboxRect = textView.firstRect(for: checkboxTextRange)
        let detectedRange = textView.checkboxRangeForTap(
            at: CGPoint(x: checkboxRect.midX, y: checkboxRect.midY)
        )

        XCTAssertEqual(detectedRange?.location, 0)
        XCTAssertEqual(detectedRange?.length, 1)
        XCTAssertTrue(textView.isCheckboxTapHandlingInstalled)
        XCTAssertNotNil(textView.textLayoutManager)
    }

    func testRichTextEditorReturnContinuesChecklistWithUncheckedItem() {
        var markdown = "- [x] Done"
        var selection = RichTextEditorSelection()
        let controller = RichTextEditorController()
        let editor = RichTextEditorView(
            text: Binding(get: { markdown }, set: { markdown = $0 }),
            selection: Binding(get: { selection }, set: { selection = $0 }),
            controller: controller
        )
        let coordinator = editor.makeCoordinator()
        let textView = InteractiveTextView(usingTextLayoutManager: true)
        textView.delegate = coordinator
        coordinator.textView = textView
        let snapshot = coordinator.editorSession.applyExternalMarkdown(
            markdown,
            to: textView,
            markdownSelection: selection
        )
        coordinator.acceptExternalMarkdown(markdown, snapshot: snapshot)
        textView.selectedRange = NSRange(location: textView.textStorage.length, length: 0)

        let shouldInsertDefaultNewline = coordinator.textView(
            textView,
            shouldChangeTextIn: textView.selectedRange,
            replacementText: "\n"
        )
        coordinator.flushPendingChanges()

        XCTAssertFalse(shouldInsertDefaultNewline)
        XCTAssertEqual(markdown, "- [x] Done\n- [ ] ")
        XCTAssertTrue(textView.text.hasSuffix("\n☐ "))
    }

    func testRichTextEditorReturnOnEmptyChecklistItemExitsChecklist() {
        var markdown = "- [ ] "
        var selection = RichTextEditorSelection()
        let controller = RichTextEditorController()
        let editor = RichTextEditorView(
            text: Binding(get: { markdown }, set: { markdown = $0 }),
            selection: Binding(get: { selection }, set: { selection = $0 }),
            controller: controller
        )
        let coordinator = editor.makeCoordinator()
        let textView = InteractiveTextView(usingTextLayoutManager: true)
        textView.delegate = coordinator
        coordinator.textView = textView
        let snapshot = coordinator.editorSession.applyExternalMarkdown(
            markdown,
            to: textView,
            markdownSelection: selection
        )
        coordinator.acceptExternalMarkdown(markdown, snapshot: snapshot)
        textView.selectedRange = NSRange(location: textView.textStorage.length, length: 0)

        _ = coordinator.textView(
            textView,
            shouldChangeTextIn: textView.selectedRange,
            replacementText: "\n"
        )
        coordinator.flushPendingChanges()

        XCTAssertEqual(markdown, "\n")
        XCTAssertNil(textView.typingAttributes[RichTextConverter.Key.checkbox])
    }

    func testRichTextEditorExpandsToContentHeightWhenInnerScrollingIsDisabled() {
        let textView = InteractiveTextView(usingTextLayoutManager: true)
        textView.setEditorScrollingEnabled(false)
        textView.bounds = CGRect(x: 0, y: 0, width: 320, height: 100)
        textView.attributedText = RichTextConverter.markdownToAttributedString(
            Array(repeating: "This is a long transcript line that must remain reachable.", count: 40)
                .joined(separator: "\n")
        )

        // Simulate TextKit reporting only the currently laid-out viewport.
        // The editor must measure the full document instead of trusting this value.
        textView.contentSize = CGSize(width: 320, height: 100)
        let expandedHeight = textView.intrinsicContentSize.height

        XCTAssertFalse(textView.isScrollEnabled)
        XCTAssertFalse(textView.panGestureRecognizer.isEnabled)
        XCTAssertGreaterThan(expandedHeight, 1_000)

        textView.setEditorScrollingEnabled(true)

        XCTAssertTrue(textView.isScrollEnabled)
        XCTAssertTrue(textView.panGestureRecognizer.isEnabled)
        XCTAssertEqual(textView.keyboardDismissMode, .interactive)
    }

    func testNoteDisplayTextOmitsMarkdownImages() {
        let note = Note(content: """
        ![](file:///tmp/chillnote-test-image.jpg)

        Captured text
        """, userId: "u1")

        XCTAssertEqual(note.displayText.trimmingCharacters(in: .whitespacesAndNewlines), "Captured text")
    }

    // MARK: - Sync Checkpoint Tests

    func testSyncCheckpointBootstrapsEmptyAccountOnlyOnce() {
        let checkpoint = SyncManager.resolveCheckpoint(
            lastSyncAt: Date(timeIntervalSince1970: 1_700_000_000),
            cursor: "123",
            hasUploadedLocal: true,
            hasCompletedBootstrap: false,
            lastKnownLocalEntityCount: nil,
            localEntityCount: 0
        )

        XCTAssertNil(checkpoint.since)
        XCTAssertNil(checkpoint.cursor)
        XCTAssertTrue(checkpoint.shouldMarkUploadedLocalAfterSuccess)
        XCTAssertTrue(checkpoint.shouldMarkBootstrapCompletedAfterSuccess)
    }

    func testSyncCheckpointFallsBackToFullSyncWhenLocalNotesExistButNeverUploaded() {
        let checkpoint = SyncManager.resolveCheckpoint(
            lastSyncAt: Date(timeIntervalSince1970: 1_700_000_000),
            cursor: "123",
            hasUploadedLocal: false,
            hasCompletedBootstrap: true,
            lastKnownLocalEntityCount: nil,
            localEntityCount: 2
        )

        XCTAssertNil(checkpoint.since)
        XCTAssertNil(checkpoint.cursor)
        XCTAssertTrue(checkpoint.shouldMarkUploadedLocalAfterSuccess)
        XCTAssertTrue(checkpoint.shouldMarkBootstrapCompletedAfterSuccess)
    }

    func testSyncCheckpointKeepsIncrementalStateWhenLocalSnapshotExists() {
        let lastSyncAt = Date(timeIntervalSince1970: 1_700_000_000)
        let checkpoint = SyncManager.resolveCheckpoint(
            lastSyncAt: lastSyncAt,
            cursor: "123",
            hasUploadedLocal: true,
            hasCompletedBootstrap: true,
            lastKnownLocalEntityCount: 2,
            localEntityCount: 2
        )

        XCTAssertEqual(checkpoint.since, lastSyncAt)
        XCTAssertEqual(checkpoint.cursor, "123")
        XCTAssertTrue(checkpoint.shouldMarkUploadedLocalAfterSuccess)
        XCTAssertFalse(checkpoint.shouldMarkBootstrapCompletedAfterSuccess)
    }

    func testSyncCheckpointKeepsCursorForEmptyAccountAfterBootstrap() {
        let lastSyncAt = Date(timeIntervalSince1970: 1_700_000_000)
        let checkpoint = SyncManager.resolveCheckpoint(
            lastSyncAt: lastSyncAt,
            cursor: "456",
            hasUploadedLocal: true,
            hasCompletedBootstrap: true,
            lastKnownLocalEntityCount: 0,
            localEntityCount: 0
        )

        XCTAssertEqual(checkpoint.since, lastSyncAt)
        XCTAssertEqual(checkpoint.cursor, "456")
        XCTAssertFalse(checkpoint.shouldMarkBootstrapCompletedAfterSuccess)
    }

    func testSyncCheckpointFullPullsWhenPreviouslyPopulatedLocalStoreIsEmpty() {
        let checkpoint = SyncManager.resolveCheckpoint(
            lastSyncAt: Date(timeIntervalSince1970: 1_700_000_000),
            cursor: "456",
            hasUploadedLocal: true,
            hasCompletedBootstrap: true,
            lastKnownLocalEntityCount: 4,
            localEntityCount: 0
        )

        XCTAssertNil(checkpoint.since)
        XCTAssertNil(checkpoint.cursor)
        XCTAssertTrue(checkpoint.shouldMarkBootstrapCompletedAfterSuccess)
    }

    func testSyncCheckpointStoreKeepsAccountsIndependent() {
        let suiteName = "sync-checkpoint-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        UserSyncCheckpointStore.save(
            UserSyncCheckpointState(
                lastSyncAtTimestamp: 100,
                cursor: "cursor-a",
                hasUploadedLocal: true,
                hasCompletedBootstrap: true,
                lastKnownLocalEntityCount: 4
            ),
            for: "user-a",
            defaults: defaults
        )
        UserSyncCheckpointStore.save(
            UserSyncCheckpointState(
                lastSyncAtTimestamp: 200,
                cursor: "cursor-b",
                hasUploadedLocal: false,
                hasCompletedBootstrap: false,
                lastKnownLocalEntityCount: 0
            ),
            for: "user-b",
            defaults: defaults
        )

        XCTAssertEqual(UserSyncCheckpointStore.state(for: "user-a", defaults: defaults).cursor, "cursor-a")
        XCTAssertEqual(UserSyncCheckpointStore.state(for: "user-a", defaults: defaults).lastSyncAtTimestamp, 100)
        XCTAssertEqual(UserSyncCheckpointStore.state(for: "user-b", defaults: defaults).cursor, "cursor-b")
        XCTAssertEqual(UserSyncCheckpointStore.state(for: "user-b", defaults: defaults).lastSyncAtTimestamp, 200)
        XCTAssertEqual(UserSyncCheckpointStore.state(for: "user-a", defaults: defaults).lastKnownLocalEntityCount, 4)
        XCTAssertEqual(UserSyncCheckpointStore.state(for: "user-b", defaults: defaults).lastKnownLocalEntityCount, 0)
    }
}
