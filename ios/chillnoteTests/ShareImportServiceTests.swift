import XCTest
import Foundation

@MainActor
final class ShareImportServiceTests: XCTestCase {
    private var directory: URL!
    private var defaults: UserDefaults!
    private var defaultsName: String!
    private var session: URLSession!

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defaultsName = "ShareImportServiceTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsName)
        defaults.set("token", forKey: ShareConstants.authTokenKey)
        defaults.set("owner", forKey: ShareConstants.authenticatedUserIdKey)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ShareImportURLProtocol.self]
        session = URLSession(configuration: configuration)
    }

    override func tearDown() async throws {
        session.invalidateAndCancel()
        ShareImportURLProtocol.handler = nil
        defaults.removePersistentDomain(forName: defaultsName)
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    func testMediaLinksSaveBeforeEnqueueWithoutFetchingMetadata() async throws {
        for rawURL in ["https://vm.tiktok.com/short", "https://youtu.be/video", "https://www.instagram.com/reel/video/"] {
            var requests = 0
            ShareImportURLProtocol.handler = { [directory = directory!] request in
                requests += 1
                XCTAssertEqual(request.url?.absoluteString, ShareConstants.backendBaseURL + "/link-import-jobs")
                XCTAssertEqual(request.httpMethod, "POST")
                let files = try FileManager.default.contentsOfDirectory(
                    at: directory.appendingPathComponent(ShareConstants.pendingImportsDirectoryName),
                    includingPropertiesForKeys: nil
                )
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let saved = try files.map { try decoder.decode(SharePendingImport.self, from: Data(contentsOf: $0)) }
                XCTAssertTrue(saved.contains { $0.source.url == rawURL && $0.importJobId == nil })
                return (202, Data(#"{"jobId":"job-1","status":"queued"}"#.utf8))
            }
            var stages: [ShareImportStage] = []
            let item = try await service.importSharedURL(URL(string: rawURL)!) { stages.append($0) }
            XCTAssertEqual(requests, 1, "The extension must only enqueue, never fetch metadata or poll a transcript")
            XCTAssertEqual(stages, [.readingContent, .saving, .completed])
            let saved = try readSaved(item)
            XCTAssertEqual(saved.source.url, rawURL)
            XCTAssertEqual(saved.userId, "owner")
            XCTAssertNil(saved.source.authorName)
            XCTAssertNil(saved.source.authorHandle)
            XCTAssertEqual(saved.importJobId, "job-1")
        }
    }

    func testNetworkFailureKeepsLinkForAppRecovery() async throws {
        ShareImportURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let item = try await service.importSharedURL(URL(string: "https://vm.tiktok.com/short")!) { _ in }
        let saved = try readSaved(item)
        XCTAssertEqual(saved.source.url, item.source.url)
        XCTAssertNil(saved.importJobId)
        XCTAssertEqual(saved.userId, "owner")
    }

    func testInsufficientCreditsKeepsLinkAndReportsBoundary() async throws {
        ShareImportURLProtocol.handler = { _ in (402, Data()) }
        do {
            _ = try await service.importSharedURL(URL(string: "https://youtu.be/video")!) { _ in }
            XCTFail("Expected insufficient credits")
        } catch ShareImportError.insufficientCredits {
            let files = try FileManager.default.contentsOfDirectory(
                at: directory.appendingPathComponent(ShareConstants.pendingImportsDirectoryName),
                includingPropertiesForKeys: nil
            )
            XCTAssertEqual(files.count, 1)
        }
    }

    func testFailedLocalSaveDoesNotEnqueue() async throws {
        ShareImportURLProtocol.handler = { _ in
            XCTFail("Cannot submit work before the link is durable")
            return (202, Data())
        }
        let unavailableService = ShareImportService(session: session, sharedDefaults: defaults, containerURL: nil)
        do {
            _ = try await unavailableService.importSharedURL(URL(string: "https://youtu.be/video")!) { _ in }
            XCTFail("Expected shared container error")
        } catch ShareImportError.sharedContainerUnavailable {}
    }

    private var service: ShareImportService {
        ShareImportService(session: session, sharedDefaults: defaults, containerURL: directory)
    }

    private func readSaved(_ item: SharePendingImport) throws -> SharePendingImport {
        let file = directory.appendingPathComponent(ShareConstants.pendingImportsDirectoryName)
            .appendingPathComponent("\(item.id.uuidString).json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SharePendingImport.self, from: Data(contentsOf: file))
    }
}

private final class ShareImportURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let (status, data) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
