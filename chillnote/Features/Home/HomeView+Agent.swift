import SwiftUI
import SwiftData
import OSLog
import UIKit

private let homeAgentLogger = Logger(subsystem: "com.chillnote.app", category: "home-agent")

extension HomeView {
    func handleAgentActionRequest(_ recipe: AgentRecipe) {
        let selectedCount = selectedNotes.count
        guard selectedCount == 1 else { return }
        if selectedCount > recipeHardLimit {
            pendingRecipeForConfirmation = nil
            showRecipeHardLimitAlert = true
            return
        }
        if selectedCount > recipeSoftLimit {
            pendingRecipeForConfirmation = recipe
            showRecipeSoftLimitAlert = true
            return
        }
        performAgentRecipe(recipe)
    }

    func confirmPendingRecipeOverSoftLimit() {
        guard let recipe = pendingRecipeForConfirmation else { return }
        pendingRecipeForConfirmation = nil
        performAgentRecipe(recipe)
    }

    func performAgentRecipe(_ recipe: AgentRecipe) {
        if recipe.id == "translate" {
            pendingAgentAction = recipe
            isTranslateInputPresented = true
        } else {
            Task { await executeAgentAction(recipe) }
        }
    }

    func executeAgentAction(_ recipe: AgentRecipe, instruction: String? = nil) async {
        let notesToProcess = getSelectedNotes()
        guard !notesToProcess.isEmpty else { return }

        await MainActor.run {
            isExecutingAction = true
            actionProgress = L10n.text("home.agent.executing", recipe.localizedName)
        }

        do {
            let combinedContent = notesToProcess.map { $0.content }.joined(separator: "\n\n---\n\n")
            let result = try await recipe.generateResult(from: combinedContent, userInstruction: instruction)
            await StoreService.shared.fetchCreditBalance()

            await MainActor.run {
                homeAISkillPreview = HomeAISkillPreview(
                    recipe: recipe,
                    result: result,
                    sourceNoteIDs: notesToProcess.map(\.id),
                    sourceTitle: previewTitle(for: notesToProcess),
                    instruction: instruction
                )
                isExecutingAction = false
                actionProgress = nil
            }
        } catch {
            homeAgentLogger.error("Agent action failed: \(error.localizedDescription, privacy: .public)")
            await MainActor.run {
                isExecutingAction = false
                actionProgress = nil
                let message = error.localizedDescription
                if message.localizedCaseInsensitiveContains("daily free agent recipe limit reached")
                    || message.localizedCaseInsensitiveContains("insufficient credits") {
                    showSubscription = true
                }
            }
        }
    }

    func applyHomeAISkillPreview(_ preview: HomeAISkillPreview, mode: HomeAISkillApplyMode) {
        switch mode {
        case .replace:
            guard let note = noteForHomeAISkillPreview(preview) else { return }
            note.content = preview.result
            note.syncContentStructure(with: modelContext)
            note.updatedAt = Date()
            persistAndSync()
            exitSelectionMode()

        case .append:
            guard let note = noteForHomeAISkillPreview(preview) else { return }
            let separator = note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "\n\n"
            note.content = note.content + separator + preview.result
            note.syncContentStructure(with: modelContext)
            note.updatedAt = Date()
            persistAndSync()
            exitSelectionMode()

        case .saveAsDraft:
            guard let userId = AuthService.shared.currentUserId else { return }
            let note = Note(content: preview.result, userId: userId)
            note.section = .drafts
            applyCurrentTagContext(to: note)
            modelContext.insert(note)
            persistAndSync()
            exitSelectionMode()
            navigationPath.append(note)

        case .copy:
            UIPasteboard.general.string = preview.result
            exitSelectionMode()
        }

        homeAISkillPreview = nil
    }

    private func noteForHomeAISkillPreview(_ preview: HomeAISkillPreview) -> Note? {
        guard preview.sourceNoteIDs.count == 1,
              let sourceID = preview.sourceNoteIDs.first else { return nil }
        return note(with: sourceID)
    }

    private func note(with id: UUID) -> Note? {
        guard let userId = currentUserId else { return nil }
        var descriptor = FetchDescriptor<Note>()
        descriptor.predicate = #Predicate<Note> { note in
            note.userId == userId && note.id == id
        }
        return try? modelContext.fetch(descriptor).first
    }

    private func previewTitle(for notes: [Note]) -> String {
        guard let first = notes.first else {
            return L10n.text("home.recipe_picker.untitled_note")
        }
        let trimmed = first.displayText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? L10n.text("home.recipe_picker.untitled_note") : trimmed
    }
}
