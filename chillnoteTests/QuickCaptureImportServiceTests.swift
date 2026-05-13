import XCTest
@testable import chillnote

final class QuickCaptureImportServiceTests: XCTestCase {
    private var topicHeading: String { L10n.text("quick_capture.media_link.topic_heading") }
    private var descriptionHeading: String { L10n.text("quick_capture.media_link.description_heading") }
    private var authorHeading: String { L10n.text("quick_capture.media_link.author_label") }
    private var transcriptHeading: String { L10n.text("quick_capture.media_link.transcript_heading") }

    func testSanitizedTikTokTitleRemovesHashtagsAndCollapsesWhitespace() {
        let service = QuickCaptureImportService.shared

        let title = service.sanitizedTikTokTitle("学英语口语 #english #learnontiktok   每天10分钟")

        XCTAssertEqual(title, "学英语口语 每天10分钟")
    }

    func testMakeTikTokTranscriptNoteUsesTopicDescriptionAuthorTranscriptFormat() async {
        let service = QuickCaptureImportService.shared
        let metadata = QuickCaptureImportService.TikTokOEmbedResponse(
            title: "示例标题 #tag",
            authorName: "Creator",
            authorURL: nil,
            authorUniqueID: "creator"
        )

        let note = await service.makeTikTokTranscriptNote(
            title: service.sanitizedTikTokTitle(metadata.title ?? ""),
            metadata: metadata,
            transcript: "第一句转写",
            polishTranscript: false,
            summarizeTopic: false
        )

        XCTAssertTrue(note.hasPrefix("## \(topicHeading)\n\n第一句转写\n\n## \(descriptionHeading)\n\n示例标题\n\n## \(authorHeading)\n\nCreator\n\n## \(transcriptHeading)"))
        XCTAssertFalse(note.hasPrefix("# "))
        XCTAssertFalse(note.contains("**示例标题**"))
        XCTAssertFalse(note.contains("#tag"))
        XCTAssertFalse(note.contains("## \(L10n.text("quick_capture.media_link.source_heading"))"))
        XCTAssertFalse(note.contains(L10n.text("quick_capture.media_link.author_link_label")))
        XCTAssertFalse(note.contains("@creator"))
    }

    func testMakeCreatorMediaLinkNoteUsesSimplifiedYouTubeAuthorMetadata() {
        let service = QuickCaptureImportService.shared
        let metadata = QuickCaptureImportService.CreatorMediaMetadata(
            title: "Video Title",
            authorName: "Creator Name",
            authorURL: "https://youtube.com/@creator",
            authorHandle: nil
        )

        let note = service.makeCreatorMediaLinkNote(metadata: metadata)

        XCTAssertTrue(note.hasPrefix("## \(topicHeading)\n\nVideo Title\n\n## \(descriptionHeading)\n\nVideo Title\n\n## \(authorHeading)\n\nCreator Name"))
        XCTAssertTrue(note.contains("Creator Name"))
        XCTAssertFalse(note.contains("https://youtube.com/@creator"))
        XCTAssertFalse(note.contains(L10n.text("quick_capture.media_link.author_link_label")))
    }

    func testSanitizedInstagramTitleRemovesChromeText() {
        let service = QuickCaptureImportService.shared

        let title = service.sanitizedInstagramTitle(
            "someone on Instagram: \"Morning routine #reel\"",
            fallback: "Instagram"
        )

        XCTAssertEqual(title, "Morning routine")
    }

    func testInstagramTitleComponentsExtractsLocalizedAuthor() {
        let service = QuickCaptureImportService.shared

        let components = service.instagramTitleComponents(
            "Instagram 用户 Mayor Olivia Chow 🇨🇦 : \"Last year I introduced a food program for CampTO #reel\"",
            fallback: "Instagram"
        )

        XCTAssertEqual(components.title, "Last year I introduced a food program for CampTO")
        XCTAssertEqual(components.authorName, "Mayor Olivia Chow 🇨🇦")
    }

    func testMakeCreatorMediaLinkNoteUsesInstagramAuthorFromTitle() {
        let service = QuickCaptureImportService.shared
        let components = service.instagramTitleComponents(
            "Instagram 用户 Mayor Olivia Chow 🇨🇦 : \"Last year I introduced a food program for CampTO\"",
            fallback: "Instagram"
        )

        let note = service.makeCreatorMediaLinkNote(
            metadata: QuickCaptureImportService.CreatorMediaMetadata(
                title: components.title,
                authorName: components.authorName,
                authorURL: nil,
                authorHandle: nil
            )
        )

        XCTAssertTrue(note.hasPrefix("## \(topicHeading)\n\nLast year I introduced a food program for CampTO\n\n## \(descriptionHeading)"))
        XCTAssertTrue(note.contains("Mayor Olivia Chow 🇨🇦"))
        XCTAssertFalse(note.contains("未知作者"))
    }

    func testMakeCreatorMediaLinkNoteUsesHandleWithoutAtWhenNameMissing() {
        let service = QuickCaptureImportService.shared
        let metadata = QuickCaptureImportService.CreatorMediaMetadata(
            title: "Video Title",
            authorName: nil,
            authorURL: nil,
            authorHandle: "@creator"
        )

        let note = service.makeCreatorMediaLinkNote(metadata: metadata)

        XCTAssertTrue(note.contains("## \(authorHeading)\n\ncreator"))
        XCTAssertFalse(note.contains("@creator"))
    }
}
