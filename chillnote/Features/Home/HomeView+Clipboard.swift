import SwiftUI
import UIKit

extension HomeView {
    @MainActor
    func checkForClipboardLinkImport() async {
        guard currentUserId != nil else { return }
        guard !isImportingClipboardLink else { return }
        guard !isSelectionMode, !isTrashSelected else { return }

        let pasteboard = UIPasteboard.general
        let changeCount = pasteboard.changeCount
        guard lastClipboardLinkPasteboardChangeCount != changeCount else { return }
        lastClipboardLinkPasteboardChangeCount = changeCount

        guard pasteboard.hasStrings || pasteboard.hasURLs else { return }
        guard await pasteboardContainsProbableWebURL(pasteboard) else { return }

        let url = clipboardCreatorMediaURL(from: pasteboard)
        guard let url else {
            return
        }

        // consumeCredits internally calls ensureSubscriptionStatusReadyForFeatureGate.
        let hasCredits = await StoreService.shared.consumeCredits(feature: .import)
        guard hasCredits else {
            showSubscription = true
            return
        }

        await importClipboardLink(url)
    }

    @MainActor
    private func importClipboardLink(_ url: URL) async {
        guard !isImportingClipboardLink else { return }
        isImportingClipboardLink = true

        defer {
            isImportingClipboardLink = false
        }

        createLinkImportNote(url)
    }

    @MainActor
    private func clipboardCreatorMediaURL(from pasteboard: UIPasteboard) -> URL? {
        if let pastedText = pasteboard.string?.trimmingCharacters(in: .whitespacesAndNewlines),
           let url = QuickCaptureLinkParser.extractCreatorMediaURL(from: pastedText) {
            return url
        }

        if let pastedURL = pasteboard.url,
           QuickCaptureLinkParser.isCreatorMediaURL(pastedURL),
           let url = QuickCaptureLinkParser.extractCreatorMediaURL(from: pastedURL.absoluteString) {
            return url
        }

        return nil
    }

    private func pasteboardContainsProbableWebURL(_ pasteboard: UIPasteboard) async -> Bool {
        do {
            let pattern: PartialKeyPath<UIPasteboard.DetectedValues> = \UIPasteboard.DetectedValues.probableWebURL
            let patterns = try await pasteboard.detectedPatterns(for: [pattern])
            return patterns.contains(pattern)
        } catch {
            return false
        }
    }

}
