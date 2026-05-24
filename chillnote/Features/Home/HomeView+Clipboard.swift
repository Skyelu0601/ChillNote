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

        await StoreService.shared.ensureSubscriptionStatusReadyForFeatureGate()
        guard StoreService.shared.currentTier == .pro else {
            showSubscription = true
            return
        }

        let url = clipboardWebURL(from: pasteboard)
        guard let url else {
            return
        }

        await importClipboardLink(url)
    }

    @MainActor
    private func importClipboardLink(_ url: URL) async {
        guard !isImportingClipboardLink else { return }
        isImportingClipboardLink = true
        isExecutingAction = true
        actionProgress = clipboardLinkImportProgressText(for: .resolvingSource)

        defer {
            isImportingClipboardLink = false
            isExecutingAction = false
            actionProgress = nil
        }

        do {
            let result = try await QuickCaptureImportService.shared.importWebLink(url) { phase in
                await MainActor.run {
                    actionProgress = clipboardLinkImportProgressText(for: phase)
                }
            }
            savePastedLink(result)
        } catch {
            clipboardLinkImportErrorMessage = error.localizedDescription
            showClipboardLinkImportErrorAlert = true
        }
    }

    @MainActor
    private func clipboardWebURL(from pasteboard: UIPasteboard) -> URL? {
        if let pastedText = pasteboard.string?.trimmingCharacters(in: .whitespacesAndNewlines),
           let url = QuickCaptureLinkParser.extractWebURL(from: pastedText) {
            return url
        }

        if let pastedURL = pasteboard.url,
           let url = QuickCaptureLinkParser.extractWebURL(from: pastedURL.absoluteString) {
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

    private func clipboardLinkImportProgressText(for phase: QuickCaptureImportService.LinkImportPhase) -> String {
        [
            L10n.text("quick_capture.import.link.title"),
            L10n.text(clipboardLinkImportPhaseKey(for: phase))
        ].joined(separator: "\n")
    }

    private func clipboardLinkImportPhaseKey(for phase: QuickCaptureImportService.LinkImportPhase) -> String {
        switch phase {
        case .resolvingSource:
            return "quick_capture.import.link.phase.resolving"
        case .fetchingContent:
            return "quick_capture.import.link.phase.fetching"
        case .extractingContent:
            return "quick_capture.import.link.phase.extracting"
        case .organizingNote:
            return "quick_capture.import.link.phase.organizing"
        case .finalizing:
            return "quick_capture.import.link.phase.finalizing"
        }
    }
}
