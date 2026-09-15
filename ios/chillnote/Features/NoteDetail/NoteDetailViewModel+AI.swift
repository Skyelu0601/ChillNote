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
            note.updateContent(aiOriginalContent)
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
        guard isAISkillsEnabled else { return }
        ProductAnalytics.shared.capture("skill_selected", properties: recipe.analyticsProperties)
        if recipe.id == "translate" {
            pendingAISkillRecipe = recipe
            if showAISkillsSheet {
                showAISkillsSheet = false
            } else {
                showAISkillTranslateSheet = true
            }
            return
        }
        if showAISkillsSheet {
            queuedAISkill = (recipe, nil)
            showAISkillsSheet = false
        } else {
            Task { await generateAISkillPreview(recipe: recipe) }
        }
    }

    func aiSkillsSheetDidDismiss() {
        if pendingAISkillRecipe != nil {
            showAISkillTranslateSheet = true
        } else {
            runQueuedAISkill()
        }
    }

    func runQueuedAISkill() {
        guard let request = queuedAISkill else { return }
        queuedAISkill = nil
        Task { await generateAISkillPreview(recipe: request.recipe, instruction: request.instruction) }
    }

    func aiSkillTranslateSheetDidDismiss() {
        // Swiping the language sheet away does not call its Cancel button.
        pendingAISkillRecipe = nil
        runQueuedAISkill()
    }

    func startPendingTranslateAISkill(targetLanguage: String) {
        guard let recipe = pendingAISkillRecipe else { return }
        pendingAISkillRecipe = nil
        queuedAISkill = (recipe, targetLanguage)
        showAISkillTranslateSheet = false
    }

    func cancelPendingTranslateAISkill() {
        pendingAISkillRecipe = nil
        queuedAISkill = nil
        showAISkillTranslateSheet = false
    }

    func generateAISkillPreview(recipe: AgentRecipe, instruction: String? = nil) async {
        let sourceContent = note.content
        let sourceSelection = normalizedSelection(editorSelection, in: sourceContent)
        if let preview = await requestAISkillPreview(
            recipe: recipe, sourceContent: sourceContent,
            sourceSelection: sourceSelection, instruction: instruction
        ) {
            aiSkillPreview = preview
        }
    }

    private func requestAISkillPreview(
        recipe: AgentRecipe, sourceContent: String,
        sourceSelection: RichTextEditorSelection, instruction: String?
    ) async -> NoteAISkillPreview? {
        guard isAISkillsEnabled, !Task.isCancelled else { return nil }
        aiSkillErrorMessage = nil
        isAwaitingAIConsent = true
        let accepted = await dependencies.ensureAIConsent()
        isAwaitingAIConsent = false
        // Refusal is a consent decision, not an attempted generation or an error.
        guard accepted, !Task.isCancelled, !isDeleted else { return nil }
        isProcessing = true
        defer { isProcessing = false }
        let runID = UUID().uuidString.lowercased()
        let startedAt = dependencies.now()
        let properties = recipe.analyticsProperties.merging([
            "run_id": runID, "diagnostic_schema": 2
        ]) { current, _ in current }
        dependencies.capture("skill_run_started", properties)
        let inputContent = sourceSelection.isCollapsed ? sourceContent : sourceSelection.selectedText

        do {
            let result = try await dependencies.generateAISkill(recipe, inputContent, instruction)
            try Task.checkCancellation()
            guard !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw GeminiError.invalidResponse
            }
            await dependencies.refreshCredits()
            try Task.checkCancellation()
            dependencies.capture(
                "skill_run_completed",
                properties.merging([
                    "latency_ms": Int(dependencies.now().timeIntervalSince(startedAt) * 1_000)
                ]) { current, _ in current }
            )
            return NoteAISkillPreview(
                analyticsRunID: runID,
                recipe: recipe,
                result: result,
                sourceContent: sourceContent,
                sourceSelection: sourceSelection,
                instruction: instruction
            )
        } catch {
            let failure = ClientFailureAnalytics.ai(error)
            dependencies.capture(
                "skill_run_\(failure.outcome)",
                properties.merging(failure.properties) { _, new in new }.merging([
                    "latency_ms": Int(dependencies.now().timeIntervalSince(startedAt) * 1_000)
                ]) { _, new in new }
            )
            if (error as? GeminiError)?.isInsufficientCredits == true {
                showSubscription = true
            } else if failure.outcome != "cancelled" && failure.code != "ai_consent_required" {
                aiSkillErrorMessage = error.localizedDescription
            }
            return nil
        }
    }

    func applyAISkillPreview(_ preview: NoteAISkillPreview, mode: NoteAISkillApplyMode) {
        if !showAIToolbar {
            aiOriginalContent = note.content
        }
        lastAITransformation = .aiSkill(preview, mode)

        isProgrammaticContentUpdate = true
        note.updateContent(contentByApplying(preview.result, mode: mode, to: note.content))
        if let modelContext {
            note.syncContentStructure(with: modelContext)
        }
        note.updatedAt = dependencies.now()
        persistAndSync()
        ProductAnalytics.shared.capture(
            "skill_result_used",
            properties: preview.recipe.analyticsProperties.merging([
                "run_id": preview.analyticsRunID,
                "action": mode.rawValue
            ]) { current, _ in current }
        )
        ProductAnalytics.shared.captureCreationCompleted(
            operationID: preview.analyticsRunID,
            type: "ai_applied",
            entryPoint: "note_detail",
            properties: preview.recipe.analyticsProperties
        )
        aiSkillPreview = nil

        withAnimation {
            showAIToolbar = true
        }

        DispatchQueue.main.async {
            self.isProgrammaticContentUpdate = false
        }
    }

    func retryLastAITransformation() async {
        guard let transformation = lastAITransformation else { return }

        switch transformation {
        case .aiSkill(let preview, let mode):
            guard let nextPreview = await requestAISkillPreview(
                recipe: preview.recipe, sourceContent: preview.sourceContent,
                sourceSelection: preview.sourceSelection, instruction: preview.instruction
            ) else { return }
            isProgrammaticContentUpdate = true
            note.updateContent(contentByApplying(nextPreview.result, mode: mode, to: preview.sourceContent))
            if let modelContext {
                note.syncContentStructure(with: modelContext)
            }
            note.updatedAt = dependencies.now()
            persistAndSync()
            lastAITransformation = .aiSkill(nextPreview, mode)
            DispatchQueue.main.async {
                self.isProgrammaticContentUpdate = false
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
        to content: String
    ) -> String {
        switch mode {
        case .appendToEnd:
            let separator = content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "\n\n"
            return content + separator + result
        case .replaceAll:
            return result
        }
    }

    private func characterRange(location: Int, length: Int, in content: String) -> Range<String.Index>? {
        guard let start = content.index(content.startIndex, offsetBy: location, limitedBy: content.endIndex),
              let end = content.index(start, offsetBy: length, limitedBy: content.endIndex) else {
            return nil
        }
        return start..<end
    }
}

private extension AgentRecipe {
    var analyticsProperties: [String: Any] {
        [
            "skill_key": isCustom ? "custom" : id,
            "skill_origin": isCustom ? "custom" : "built_in"
        ]
    }
}
