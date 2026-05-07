import XCTest
@testable import chillnote

final class QuickCaptureLinkParserTests: XCTestCase {
    func testExtractsPlainHTTPURL() {
        let url = QuickCaptureLinkParser.extractWebURL(from: "https://example.com/article?id=42")

        XCTAssertEqual(url?.absoluteString, "https://example.com/article?id=42")
    }

    func testExtractsURLFromSharedText() {
        let text = """
        A useful article
        https://example.com/read-this?from=share
        """

        let url = QuickCaptureLinkParser.extractWebURL(from: text)

        XCTAssertEqual(url?.absoluteString, "https://example.com/read-this?from=share")
    }

    func testTrimsCommonTrailingPunctuation() {
        let url = QuickCaptureLinkParser.extractWebURL(from: "Read this: <https://example.com/path>.")

        XCTAssertEqual(url?.absoluteString, "https://example.com/path")
    }

    func testAddsHTTPSForBareDomain() {
        let url = QuickCaptureLinkParser.extractWebURL(from: "www.example.com/path")

        XCTAssertEqual(url?.absoluteString, "https://www.example.com/path")
    }

    func testUpgradesHTTPToHTTPS() {
        let url = QuickCaptureLinkParser.extractWebURL(from: "http://example.com/path")

        XCTAssertEqual(url?.absoluteString, "https://example.com/path")
    }

    func testRejectsNonWebLinks() {
        let url = QuickCaptureLinkParser.extractWebURL(from: "mailto:hello@example.com")

        XCTAssertNil(url)
    }

    func testRecognizesOverseasCreatorPlatforms() {
        let cases: [(String, String)] = [
            ("https://www.tiktok.com/@creator/video/123", "tiktok"),
            ("https://vt.tiktok.com/example", "tiktok"),
            ("https://www.youtube.com/watch?v=abc123", "youtube"),
            ("https://youtu.be/abc123", "youtube"),
            ("https://www.instagram.com/reel/C9abc123/", "instagram"),
            ("https://www.threads.net/@creator/post/123", "threads"),
            ("https://redd.it/abc123", "reddit"),
            ("https://pin.it/abc123", "pinterest"),
            ("https://www.linkedin.com/posts/example", "linkedin"),
            ("https://fb.watch/example", "facebook"),
            ("https://vimeo.com/123456", "vimeo"),
            ("https://www.twitch.tv/videos/123456", "twitch"),
            ("https://www.producthunt.com/posts/example", "product_hunt"),
            ("https://news.ycombinator.com/item?id=123", "hacker_news")
        ]

        for (urlString, platformID) in cases {
            let url = URL(string: urlString)!
            XCTAssertEqual(
                NoteSourcePlatformResolver.platform(for: url).id,
                platformID,
                "Expected \(urlString) to resolve to \(platformID)"
            )
        }
    }
}
