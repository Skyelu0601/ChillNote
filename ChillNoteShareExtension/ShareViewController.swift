import SwiftUI
import UIKit
import UniformTypeIdentifiers

@MainActor
final class ShareViewModel: ObservableObject {
    @Published var sourceName = ShareL10n.text("share_extension.unknown_source")
    @Published var sourcePlatformID = "web"
    @Published var statusText = ShareL10n.text("share_extension.reading_content")
    @Published var stage: ShareImportStage = .readingContent
    @Published var progress = 0.05
    @Published var visualProgress = 0.05
    @Published var isCompleted = false
    @Published var errorMessage: String?

    private weak var extensionContext: NSExtensionContext?
    private var sharedURL: URL?
    private var visualProgressCeiling = 0.12
    private var visualProgressTask: Task<Void, Never>?
    private let service = ShareImportService()

    init(extensionContext: NSExtensionContext?) {
        self.extensionContext = extensionContext
    }

    deinit {
        visualProgressTask?.cancel()
    }

    func start() async {
        beginVisualProgress()

        do {
            let url = try await loadSharedURL()
            sharedURL = url
            let platform = SharePlatformResolver.platform(for: url)
            sourceName = platform.displayName
            sourcePlatformID = platform.id

            _ = try await service.importSharedURL(url) { [weak self] stage in
                self?.apply(stage)
            }

            statusText = ShareL10n.text("share_extension.saved")
            progress = 1.0
            visualProgress = 1.0
            isCompleted = true
            stopVisualProgress()

            try? await Task.sleep(for: .milliseconds(850))
            extensionContext?.completeRequest(returningItems: nil)
        } catch {
            stopVisualProgress()
            errorMessage = (error as? LocalizedError)?.errorDescription ?? ShareL10n.text("share_extension.failed")
            statusText = ShareL10n.text("share_extension.failed")
        }
    }

    private func apply(_ stage: ShareImportStage) {
        self.stage = stage
        progress = stage.progress
        visualProgress = max(visualProgress, stage.progress)
        visualProgressCeiling = stage.visualCeiling
        statusText = stage.message
        isCompleted = stage == .completed

        if stage == .completed {
            visualProgress = 1.0
            stopVisualProgress()
        }
    }

    private func beginVisualProgress() {
        visualProgressTask?.cancel()
        visualProgressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(220))
                guard let self else { return }

                if self.isCompleted {
                    return
                }

                let remaining = self.visualProgressCeiling - self.visualProgress
                guard remaining > 0.003 else { continue }

                self.visualProgress += min(max(remaining * 0.08, 0.004), 0.014)
            }
        }
    }

    private func stopVisualProgress() {
        visualProgressTask?.cancel()
        visualProgressTask = nil
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

        preferredContentSize = CGSize(width: 390, height: 320)
    }
}
