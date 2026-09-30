import XCTest
import UIKit
import UniformTypeIdentifiers

@MainActor
final class ShareViewModelTests: XCTestCase {
    func testSavedSharePausesBeforeAutomaticDismissalAndStartsOnlyOnce() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let context = ShareTestExtensionContext()
        let item = NSExtensionItem()
        item.attachments = [NSItemProvider(
            item: "https://youtu.be/share-ui-test" as NSString,
            typeIdentifier: UTType.plainText.identifier
        )]
        context.sharedItems = [item]
        let service = ShareImportService(sharedDefaults: nil, containerURL: directory)
        let model = ShareViewModel(extensionContext: context, service: service, automaticDismissDelay: .milliseconds(20))

        await model.start()
        XCTAssertTrue(model.isCompleted)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(context.completionCount, 0, "Success must remain visible during its confirmation pause")

        await model.start()
        let files = try FileManager.default.contentsOfDirectory(
            at: directory.appendingPathComponent(ShareConstants.pendingImportsDirectoryName),
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(files.count, 1, "View lifecycle changes must not save the same share twice")

        let shouldClose = await model.waitForAutomaticDismissal(voiceOverRunning: false)
        XCTAssertTrue(shouldClose)
        XCTAssertEqual(context.completionCount, 0, "Let the view animate away before completing the request")
        model.dismiss()
        model.dismiss()
        XCTAssertEqual(context.completionCount, 1, "An automatic close or swipe completes the extension once")
        let shouldCloseAgain = await model.waitForAutomaticDismissal(voiceOverRunning: false)
        XCTAssertFalse(shouldCloseAgain)
    }

    func testFailureStaysOpenAndCanBeDismissedWithoutAButton() async {
        let context = ShareTestExtensionContext()
        let model = ShareViewModel(extensionContext: context)
        await model.start()
        XCTAssertNotNil(model.errorMessage)
        XCTAssertFalse(model.isCompleted)
        XCTAssertEqual(context.completionCount, 0)
        let shouldClose = await model.waitForAutomaticDismissal(voiceOverRunning: false)
        XCTAssertFalse(shouldClose, "Errors must remain readable")
        model.dismiss()
        XCTAssertEqual(context.completionCount, 1)
    }
    func testVoiceOverKeepsSuccessfulFeedbackVisible() async {
        let context = ShareTestExtensionContext()
        let model = ShareViewModel(extensionContext: context, automaticDismissDelay: .zero)
        model.isCompleted = true
        let shouldClose = await model.waitForAutomaticDismissal(voiceOverRunning: true)
        XCTAssertFalse(shouldClose)
        XCTAssertEqual(context.completionCount, 0)
    }

    func testCancelledConfirmationPauseDoesNotClose() async {
        let model = ShareViewModel(extensionContext: nil)
        model.isCompleted = true
        let pause = Task { await model.waitForAutomaticDismissal(voiceOverRunning: false) }
        pause.cancel()
        let shouldClose = await pause.value
        XCTAssertFalse(shouldClose)
    }
}

private final class ShareTestExtensionContext: NSExtensionContext {
    var sharedItems: [Any] = []
    var completionCount = 0

    override var inputItems: [Any] { sharedItems }

    override func completeRequest(returningItems items: [Any]?, completionHandler: ((Bool) -> Void)? = nil) {
        completionCount += 1
        completionHandler?(true)
    }
}
