import SwiftUI
import UIKit
import UniformTypeIdentifiers

private enum ShareAnalyticsQueue {
    private static let key = "analytics.posthog.shareEventQueue"
    private static let appGroupIdentifier = "group.com.sponteoai.chillnote"

    private struct Event: Codable {
        let name: String
        let properties: [String: String]
        let occurredAt: Date
    }

    static func capture(_ name: String, properties: [String: String]) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        let existing = defaults.data(forKey: key)
            .flatMap { try? JSONDecoder().decode([Event].self, from: $0) } ?? []
        let updated = Array((existing + [Event(name: name, properties: properties, occurredAt: Date())]).suffix(100))
        guard let data = try? JSONEncoder().encode(updated) else { return }
        defaults.set(data, forKey: key)
    }
}

@MainActor
final class ShareViewModel: ObservableObject {
    @Published var sourceName = ShareL10n.text("share_extension.unknown_source")
    @Published var sourcePlatformID = "web"
    @Published var statusText = ShareL10n.text("share_extension.reading_content")
    @Published var stage: ShareImportStage = .readingContent
    @Published var isCompleted = false
    @Published var errorMessage: String?
    @Published var isCreditsRequired = false

    private weak var extensionContext: NSExtensionContext?
    private var hasStarted = false
    private var hasDismissed = false
    private let service: ShareImportService
    private let automaticDismissDelay: Duration
    private let operationID = UUID().uuidString.lowercased()

    init(
        extensionContext: NSExtensionContext?,
        service: ShareImportService = ShareImportService(),
        automaticDismissDelay: Duration = .milliseconds(900)
    ) {
        self.extensionContext = extensionContext
        self.service = service
        self.automaticDismissDelay = automaticDismissDelay
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true

        do {
            let url = try await loadSharedURL()
            let platform = SharePlatformResolver.platform(for: url)
            sourceName = platform.displayName
            sourcePlatformID = platform.id
            ShareAnalyticsQueue.capture("share_import_opened", properties: [
                "operation_id": operationID,
                "source_platform": platform.id,
                "entry_point": "system_share_sheet"
            ])

            _ = try await service.importSharedURL(url) { [weak self] stage in
                self?.apply(stage)
            }

            ShareAnalyticsQueue.capture("share_import_accepted", properties: [
                "operation_id": operationID,
                "source_platform": platform.id,
                "entry_point": "system_share_sheet"
            ])

            statusText = ShareL10n.text("share_extension.saved")
            isCompleted = true
        } catch {
            isCreditsRequired = (error as? ShareImportError)?.analyticsCode == "insufficient_credits"
            ShareAnalyticsQueue.capture("share_import_blocked", properties: [
                "operation_id": operationID,
                "source_platform": sourcePlatformID,
                "entry_point": "system_share_sheet",
                "error_code": (error as? ShareImportError)?.analyticsCode ?? "unknown"
            ])
            errorMessage = (error as? LocalizedError)?.errorDescription ?? ShareL10n.text("share_extension.failed")
            statusText = ShareL10n.text("share_extension.failed")
        }
    }

    func dismiss() {
        guard !hasDismissed else { return }
        hasDismissed = true
        extensionContext?.completeRequest(returningItems: nil)
    }

    /// The view animates the panel away only after this pause finishes.
    /// Cancellation, errors and an earlier swipe must never trigger another close.
    func waitForAutomaticDismissal(voiceOverRunning: Bool) async -> Bool {
        guard isCompleted, errorMessage == nil, !hasDismissed, !voiceOverRunning else { return false }
        do {
            try await Task.sleep(for: automaticDismissDelay)
        } catch {
            return false
        }
        return isCompleted && errorMessage == nil && !hasDismissed && !Task.isCancelled
    }

    private func apply(_ stage: ShareImportStage) {
        self.stage = stage
        statusText = stage.message
        isCompleted = stage == .completed
    }

    private func loadSharedURL() async throws -> URL {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            throw ShareImportError.missingLink
        }

        for item in items {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let url = try await loadURL(from: provider) {
                    return url
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                   let text = try await loadText(from: provider),
                   let url = ShareLinkParser.extractWebURL(from: text) {
                    return url
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier),
                   let text = try await loadText(from: provider),
                   let url = ShareLinkParser.extractWebURL(from: text) {
                    return url
                }
            }
        }

        throw ShareImportError.missingLink
    }

    private func loadURL(from provider: NSItemProvider) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let text = item as? String {
                    continuation.resume(returning: ShareLinkParser.extractWebURL(from: text))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func loadText(from provider: NSItemProvider) async throws -> String? {
        let typeIdentifier = provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
            ? UTType.plainText.identifier
            : UTType.text.identifier

        return try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let text = item as? String {
                    continuation.resume(returning: text)
                } else if let data = item as? Data {
                    continuation.resume(returning: String(data: data, encoding: .utf8))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

final class ShareViewController: UIViewController {
    private var viewModel: ShareViewModel?

    override func viewDidLoad() {
        super.viewDidLoad()

        let viewModel = ShareViewModel(extensionContext: extensionContext)
        self.viewModel = viewModel

        let hostingController = UIHostingController(rootView: ShareView(viewModel: viewModel))
        hostingController.sizingOptions = [.preferredContentSize]
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.isOpaque = false
        hostingController.view.backgroundColor = .clear
        hostingController.view.isOpaque = false
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)

        preferredContentSize = CGSize(width: 390, height: 540)
    }
}
