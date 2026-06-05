import Foundation
import SwiftUI

@MainActor
extension NoteDetailViewModel {
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

    func startAISkill(_ recipe: AgentRecipe) {
        if recipe.id == "translate" {
            pendingAISkillRecipe = recipe
            showAISkillTranslateSheet = true
            return
        }

        Task { await generateAISkillPreview(recipe: recipe) }
    }

    func startPendingTranslateAISkill(targetLanguage: String) {
        guard let recipe = pendingAISkillRecipe else { return }
        pendingAISkillRecipe = nil
        showAISkillTranslateSheet = false
        Task { await generateAISkillPreview(recipe: recipe, instruction: targetLanguage) }
    }

    func cancelPendingTranslateAISkill() {
        pendingAISkillRecipe = nil
        showAISkillTranslateSheet = false
    }

    func generateAISkillPreview(recipe: AgentRecipe, instruction: String? = nil) async {
        let sourceContent = note.content
        let sourceSelection = normalizedSelection(editorSelection, in: sourceContent)
        let inputContent = sourceSelection.isCollapsed ? sourceContent : sourceSelection.selectedText

        showAISkillsSheet = false
        isProcessing = true
        aiSkillErrorMessage = nil

        do {
            let result = try await recipe.generateResult(from: inputContent, userInstruction: instruction)
            await StoreService.shared.fetchCreditBalance()
            aiSkillPreview = NoteAISkillPreview(
                recipe: recipe,
                result: result,
                sourceContent: sourceContent,
                sourceSelection: sourceSelection,
                instruction: instruction
            )
            isProcessing = false
        } catch {
            isProcessing = false
            let message = error.localizedDescription
            if message.localizedCaseInsensitiveContains("daily free agent recipe limit reached")
                || message.localizedCaseInsensitiveContains("insufficient credits") {
                showSubscription = true
            } else {
                aiSkillErrorMessage = message
            }
        }
    }

    func applyAISkillPreview(_ preview: NoteAISkillPreview, mode: NoteAISkillApplyMode) {
        if !showAIToolbar {
            aiOriginalContent = note.content
        }
        lastAITransformation = .aiSkill(preview, mode)

        isProgrammaticContentUpdate = true
        note.content = contentByApplying(preview.result, mode: mode, to: note.content, selection: preview.sourceSelection)
        if let modelContext {
            note.syncContentStructure(with: modelContext)
        }
        note.updatedAt = dependencies.now()
        persistAndSync()
        aiSkillPreview = nil

        withAnimation {
            showAIToolbar = true
        }

        DispatchQueue.main.async {
            self.isProgrammaticContentUpdate = false
        }
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

    func retryLastAITransformation() async {
        guard let transformation = lastAITransformation else { return }

        switch transformation {
        case .aiSkill(let preview, let mode):
            isProcessing = true
            isProgrammaticContentUpdate = true
            note.content = preview.sourceContent
            if let modelContext {
                note.syncContentStructure(with: modelContext)
            }
            persistAndSync()
            DispatchQueue.main.async {
                self.isProgrammaticContentUpdate = false
            }

            do {
                let result = try await preview.recipe.generateResult(
                    from: preview.inputContent,
                    userInstruction: preview.instruction
                )
                await StoreService.shared.fetchCreditBalance()
                let nextPreview = NoteAISkillPreview(
                    recipe: preview.recipe,
                    result: result,
                    sourceContent: preview.sourceContent,
                    sourceSelection: preview.sourceSelection,
                    instruction: preview.instruction
                )
                note.content = contentByApplying(result, mode: mode, to: preview.sourceContent, selection: preview.sourceSelection)
                if let modelContext {
                    note.syncContentStructure(with: modelContext)
                }
                note.updatedAt = dependencies.now()
                persistAndSync()
                lastAITransformation = .aiSkill(nextPreview, mode)
                isProcessing = false
            } catch {
                isProcessing = false
                aiSkillErrorMessage = error.localizedDescription
            }
        }
    }

    private func normalizedSelection(_ selection: RichTextEditorSelection, in content: String) -> RichTextEditorSelection {
        let location = max(0, min(selection.location, content.count))
        let length = max(0, min(selection.length, content.count - location))
        guard length > 0,
              let range = characterRange(location: location, length: length, in: content) else {
            return RichTextEditorSelection(location: location, length: 0, selectedText: "")
        }

        return RichTextEditorSelection(
            location: location,
            length: length,
            selectedText: String(content[range])
        )
    }

    private func contentByApplying(
        _ result: String,
        mode: NoteAISkillApplyMode,
        to content: String,
        selection: RichTextEditorSelection
    ) -> String {
        switch mode {
        case .replaceSelection:
            return replacingRange(
                location: selection.location,
                length: selection.length,
                in: content,
                with: result
            )
        case .insertAtCursor:
            return inserting(result, at: selection.location, in: content)
        case .insertBelowSelection:
            return inserting("\n\n\(result)", at: selection.location + selection.length, in: content)
        case .appendToEnd:
            let separator = content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "\n\n"
            return content + separator + result
        case .replaceAll:
            return result
        }
    }

    private func replacingRange(location: Int, length: Int, in content: String, with replacement: String) -> String {
        guard let range = characterRange(location: location, length: length, in: content) else {
            return content
        }
        var updated = content
        updated.replaceSubrange(range, with: replacement)
        return updated
    }

    private func inserting(_ insertion: String, at location: Int, in content: String) -> String {
        let boundedLocation = max(0, min(location, content.count))
        guard let index = content.index(content.startIndex, offsetBy: boundedLocation, limitedBy: content.endIndex) else {
            return content + insertion
        }
        var updated = content
        updated.insert(contentsOf: insertion, at: index)
        return updated
    }

    private func characterRange(location: Int, length: Int, in content: String) -> Range<String.Index>? {
        guard let start = content.index(content.startIndex, offsetBy: location, limitedBy: content.endIndex),
              let end = content.index(start, offsetBy: length, limitedBy: content.endIndex) else {
            return nil
        }
        return start..<end
    }
}
