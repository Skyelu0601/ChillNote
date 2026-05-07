import XCTest
@testable import chillnote

final class QuickCaptureImportServiceTests: XCTestCase {
    func testSanitizedTikTokTitleRemovesHashtagsAndCollapsesWhitespace() {
        let service = QuickCaptureImportService.shared

        let title = service.sanitizedTikTokTitle("学英语口语 #english #learnontiktok   每天10分钟")

        XCTAssertEqual(title, "学英语口语 每天10分钟")
    }

    func testMakeTikTokTranscriptNoteKeepsTitleBoldWithoutMarkdownHeading() async {
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
            polishTranscript: false
        )

        XCTAssertTrue(note.hasPrefix("**示例标题**\n\n## "))
        XCTAssertFalse(note.hasPrefix("# "))
        XCTAssertFalse(note.contains("#tag"))
    }

    func testMakeCreatorMediaLinkNoteSupportsYouTubeAuthorMetadata() {
        let service = QuickCaptureImportService.shared
        let metadata = QuickCaptureImportService.CreatorMediaMetadata(
            title: "Video Title",
            authorName: "Creator Name",
            authorURL: "https://youtube.com/@creator",
            authorHandle: nil
        )

        let note = service.makeCreatorMediaLinkNote(metadata: metadata)

        XCTAssertTrue(note.hasPrefix("**Video Title**"))
        XCTAssertTrue(note.contains("Creator Name"))
        XCTAssertTrue(note.contains("https://youtube.com/@creator"))
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

        XCTAssertTrue(note.hasPrefix("**Last year I introduced a food program for CampTO**"))
        XCTAssertTrue(note.contains("Mayor Olivia Chow 🇨🇦"))
        XCTAssertFalse(note.contains("未知作者"))
    }
}
