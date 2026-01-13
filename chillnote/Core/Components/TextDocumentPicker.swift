import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct TextDocumentPicker: UIViewControllerRepresentable {
    let onPick: (String) -> Void
    let onError: (String) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onError: onError)
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.plainText], asCopy: true)
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onPick: (String) -> Void
        private let onError: (String) -> Void
        
        init(onPick: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
            self.onPick = onPick
            self.onError = onError
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onError("No file selected.")
                return
            }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                onPick(text)
            } catch {
                onError("Failed to read file.")
            }
        }
    }
}
