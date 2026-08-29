import XCTest
@testable import chillnote

final class QuickCaptureImportServiceTests: XCTestCase {
    private var descriptionHeading: String { L10n.text("quick_capture.media_link.description_heading") }
    private var authorHeading: String { L10n.text("quick_capture.media_link.author_label") }
    private var hookHeading: String { L10n.text("quick_capture.media_link.hook_heading") }
    private var transcriptHeading: String { L10n.text("quick_capture.media_link.transcript_heading") }

    func testSanitizedTikTokTitleRemovesHashtagsAndCollapsesWhitespace() {
        let service = QuickCaptureImportService.shared

        let title = service.sanitizedTikTokTitle("学英语口语 #english #learnontiktok   每天10分钟")

        XCTAssertEqual(title, "学英语口语 每天10分钟")
    }

    func testMakeTikTokTranscriptNoteGeneratesTranscriptOnly() async {
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
            preferences: .transcriptOnly
        )

        XCTAssertEqual(note, "## \(transcriptHeading)\n第一句转写")
        XCTAssertFalse(note.hasPrefix("# "))
        XCTAssertFalse(note.contains(descriptionHeading))
        XCTAssertFalse(note.contains(authorHeading))
        XCTAssertFalse(note.contains(hookHeading))
    }

    func testMakeCreatorMediaTranscriptNoteCanShowTranscriptOnly() async {
        let service = QuickCaptureImportService.shared
        let metadata = QuickCaptureImportService.CreatorMediaMetadata(
            title: "Video Title",
            authorName: "Creator Name",
            authorURL: nil,
            authorHandle: nil
        )
        let preferences = MediaLinkTranscriptSectionPreferences(
            showDescription: false,
            showAuthor: false,
            showHook: false,
            showTranscript: true
        )

        let note = await service.makeCreatorMediaTranscriptNote(
            metadata: metadata,
            transcript: "First paragraph.\n\nSecond paragraph.",
            polishTranscript: false,
            preferences: preferences
        )

        XCTAssertEqual(note, "## \(transcriptHeading)\nFirst paragraph.\nSecond paragraph.")
        XCTAssertFalse(note.contains(descriptionHeading))
        XCTAssertFalse(note.contains(authorHeading))
        XCTAssertFalse(note.contains(hookHeading))
    }

    func testMakeCreatorMediaLinkNoteKeepsMetadataOutOfBody() {
        let service = QuickCaptureImportService.shared
        let metadata = QuickCaptureImportService.CreatorMediaMetadata(
            title: "Video Title",
            authorName: "Creator Name",
            authorURL: "https://youtube.com/@creator",
            authorHandle: nil
        )

        let note = service.makeCreatorMediaLinkNote(metadata: metadata)

        XCTAssertEqual(
            note,
            "## \(transcriptHeading)\n\(L10n.text("quick_capture.media_link.unavailable"))"
        )
        XCTAssertFalse(note.contains("Video Title"))
        XCTAssertFalse(note.contains("Creator Name"))
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

    func testSourceMetadataUsesInstagramAuthorFromTitle() {
        let service = QuickCaptureImportService.shared
        let components = service.instagramTitleComponents(
            "Instagram 用户 Mayor Olivia Chow 🇨🇦 : \"Last year I introduced a food program for CampTO\"",
            fallback: "Instagram"
        )

        let source = NoteSourceMetadata(
            url: "https://www.instagram.com/reel/example",
            title: components.title,
            platformID: "instagram",
            platformName: "Instagram Reels",
            host: "instagram.com",
            authorName: components.authorName
        )

        XCTAssertEqual(source.authorDisplayName, "Mayor Olivia Chow 🇨🇦")
    }

    func testSourceMetadataUsesHandleWithAtWhenNameMissing() {
        let source = NoteSourceMetadata(
            url: "https://www.tiktok.com/@creator/video/123",
            title: "Video Title",
            platformID: "tiktok",
            platformName: "TikTok",
            host: "tiktok.com",
            authorHandle: "@creator"
        )

        XCTAssertEqual(source.authorDisplayName, "@creator")
    }

    func testNotePersistsSourceAuthorMetadata() {
        let note = Note(content: "## Transcript\nHello", userId: "user")
        note.applySourceMetadata(
            NoteSourceMetadata(
                url: "https://www.tiktok.com/@creator/video/123",
                title: "Video Title",
                platformID: "tiktok",
                platformName: "TikTok",
                host: "tiktok.com",
                authorName: "Creator Name",
                authorHandle: "creator"
            )
        )

        XCTAssertEqual(note.sourceAuthorName, "Creator Name")
        XCTAssertEqual(note.sourceAuthorHandle, "creator")
        XCTAssertEqual(note.sourceMetadata?.authorDisplayName, "Creator Name")
    }

    func testLegacyAuthorSectionAppearsInSourceMetadata() {
        let note = Note(
            content: """
            ## Description
            Video Title
            ## Author
            Legacy Creator
            ## Hook
            Opening line
            ## Transcript
            Opening line and the rest of the transcript.
            """,
            userId: "user"
        )
        note.applySourceMetadata(
            NoteSourceMetadata(
                url: "https://www.tiktok.com/@creator/video/123",
                title: "Video Title",
                platformID: "tiktok",
                platformName: "TikTok",
                host: "tiktok.com"
            )
        )

        XCTAssertEqual(note.sourceMetadata?.authorDisplayName, "Legacy Creator")
    }

    func testLegacyUnknownAuthorIsNotDisplayed() {
        let note = Note(
            content: "## Author\nUnknown author\n## Transcript\nHello",
            userId: "user"
        )
        note.applySourceMetadata(
            NoteSourceMetadata(
                url: "https://www.youtube.com/watch?v=123",
                title: "Video Title",
                platformID: "youtube",
                platformName: "YouTube",
                host: "youtube.com"
            )
        )

        XCTAssertNil(note.sourceMetadata?.authorDisplayName)
    }

    func testSyncKeepsLocallyResolvedAuthorWhenServerDoesNotYetProvideIt() {
        let sourceURL = "https://www.tiktok.com/@creator/video/123"
        let note = Note(content: "## Transcript\nHello", userId: "user")
        note.applySourceMetadata(
            NoteSourceMetadata(
                url: sourceURL,
                title: "Video Title",
                platformID: "tiktok",
                platformName: "TikTok",
                host: "tiktok.com",
                authorName: "Creator Name",
                authorHandle: "creator"
            )
        )
        let dto = NoteDTO(
            id: note.id.uuidString,
            content: note.content,
            createdAt: "2026-08-06T00:00:00.000Z",
            updatedAt: nil,
            deletedAt: nil,
            pinnedAt: nil,
            tagIds: nil,
            version: nil,
            baseVersion: nil,
            clientUpdatedAt: nil,
            lastModifiedByDeviceId: nil,
            sourceURL: sourceURL,
            sourceTitle: "Video Title",
            sourcePlatformID: "tiktok",
            sourcePlatformName: "TikTok",
            sourceHost: "tiktok.com"
        )

        SyncMapper().apply(dto, to: note)

        XCTAssertEqual(note.sourceAuthorName, "Creator Name")
        XCTAssertEqual(note.sourceAuthorHandle, "creator")
    }

    func testSyncClearsAuthorWhenSourceChangesAndServerHasNoAuthor() {
        let note = Note(content: "## Transcript\nHello", userId: "user")
        note.applySourceMetadata(
            NoteSourceMetadata(
                url: "https://www.tiktok.com/@old/video/123",
                title: "Old Video",
                platformID: "tiktok",
                platformName: "TikTok",
                host: "tiktok.com",
                authorName: "Old Creator"
            )
        )
        let dto = NoteDTO(
            id: note.id.uuidString,
            content: note.content,
            createdAt: "2026-08-06T00:00:00.000Z",
            updatedAt: nil,
            deletedAt: nil,
            pinnedAt: nil,
            tagIds: nil,
            version: nil,
            baseVersion: nil,
            clientUpdatedAt: nil,
            lastModifiedByDeviceId: nil,
            sourceURL: "https://www.youtube.com/watch?v=new",
            sourceTitle: "New Video",
            sourcePlatformID: "youtube",
            sourcePlatformName: "YouTube",
            sourceHost: "youtube.com"
        )

        SyncMapper().apply(dto, to: note)

        XCTAssertNil(note.sourceAuthorName)
        XCTAssertNil(note.sourceAuthorHandle)
    }

    func testSharedImportOwnershipIsolatedAcrossAccountSwitches() {
        let source = SharedImportQueue.PendingImport.Source(
            url: "https://example.com/video",
            title: "Video",
            platformID: "web",
            platformName: "Web",
            host: "example.com",
            authorName: nil,
            authorHandle: nil
        )
        let legacy = SharedImportQueue.PendingImport(
            id: UUID(),
            kind: .note,
            noteText: "legacy",
            source: source,
            importJobId: nil,
            importStatus: nil,
            createdAt: Date(),
            userId: nil
        )
        let owned = SharedImportQueue.PendingImport(
            id: UUID(),
            kind: .note,
            noteText: "owned",
            source: source,
            importJobId: nil,
            importStatus: nil,
            createdAt: Date(),
            userId: "USER-A"
        )

        XCTAssertFalse(legacy.belongs(to: "user-a"))
        XCTAssertFalse(legacy.belongs(to: "user-b"))
        XCTAssertTrue(owned.belongs(to: "user-a"))
        XCTAssertFalse(owned.belongs(to: "user-b"))
    }

    func testLegacySharedImportDecodesWithoutUserId() throws {
        let legacyJSON = #"{"id":"00000000-0000-0000-0000-000000000001","kind":"note","noteText":"legacy","source":{"url":"https://example.com/video","title":"Video","platformID":"web","platformName":"Web","host":"example.com","authorName":null,"authorHandle":null},"importJobId":null,"importStatus":null,"createdAt":"2026-08-27T12:00:00Z"}"#

        let decoded = try JSONDecoder.sharedImportDecoder.decode(
            SharedImportQueue.PendingImport.self,
            from: Data(legacyJSON.utf8)
        )

        XCTAssertNil(decoded.userId)
        XCTAssertFalse(decoded.belongs(to: "user-a"))
        XCTAssertFalse(decoded.belongs(to: "user-b"))
    }
}
