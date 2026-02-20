import Foundation
import SwiftUI

@MainActor
extension NoteDetailViewModel {
    func executeTidyAction() async {
        let contentToTransform = note.content

        if !showAIToolbar {
            aiOriginalContent = note.content
        }

        isProcessing = true

        do {
            let result = try await dependencies.executeTidy(contentToTransform)

            isProgrammaticContentUpdate = true
            note.content = result
            note.updatedAt = dependencies.now()
            persistAndSync()

            isProcessing = false
            withAnimation {
                showAIToolbar = true
            }

            DispatchQueue.main.async {
                self.isProgrammaticContentUpdate = false
            }
        } catch {
            isProcessing = false
            let message = error.localizedDescription
            if message.localizedCaseInsensitiveContains("daily free tidy limit reached") {
                upgradeTitle = String(localized: "Daily Tidy limit reached")
                showUpgradeSheet = true
            }
        }
    }

    func undoAIContent() {
        guard let aiOriginalContent else {
            dismissAIToolbar()
            return
        }

        withAnimation {
            isProgrammaticContentUpdate = true
            note.content = aiOriginalContent
            note.updatedAt = dependencies.now()
            persistAndSync()

            dismissAIToolbar()

            DispatchQueue.main.async {
                self.isProgrammaticContentUpdate = false
            }
        }
    }

    func saveAIContentAndDismissToolbar() {
        note.updatedAt = dependencies.now()
        persistAndSync()
        dismissAIToolbar()
    }

    func handleAIInput(voiceInput: String? = nil) async {
        let userInput = voiceInput ?? inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userInput.isEmpty else { return }

        inputText = ""
        isProcessing = true

        do {
            let response = try await dependencies.generateAIEdit(note.content, userInput)

            isProgrammaticContentUpdate = true
            note.content = response
            if let modelContext {
                note.syncContentStructure(with: modelContext)
            }
            note.updatedAt = dependencies.now()
            isProcessing = false
            persistAndSync()

            DispatchQueue.main.async {
                self.isProgrammaticContentUpdate = false
            }
        } catch {
            isProcessing = false
        }
    }
}
