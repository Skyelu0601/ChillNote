import SwiftUI
import SwiftData

extension HomeView {
    func handleAgentActionRequest(_ recipe: AgentRecipe) {
        let selectedCount = selectedNotes.count
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
            // For merge_notes and all other recipes (including custom ones),
            // we can execute directly. The instruction is handled inside AgentRecipe.execute
            // or passed as nil for custom recipes (though custom recipes uses self.prompt inside execute)
            Task { await executeAgentAction(recipe) }
        }
    }

    func executeAgentAction(_ recipe: AgentRecipe, instruction: String? = nil) async {
        let notesToProcess = getSelectedNotes()
        guard !notesToProcess.isEmpty else { return }

        await MainActor.run {
            isExecutingAction = true
            actionProgress = "Executing \(recipe.name)..."
        }

        do {
            _ = try await recipe.execute(on: notesToProcess, context: modelContext, userInstruction: instruction)

            await MainActor.run {
                persistAndSync()
                isExecutingAction = false
                actionProgress = nil

                if recipe.id == "merge_notes" {
                    notesToDeleteAfterMerge = notesToProcess
                    showMergeSuccessAlert = true
                } else {
                    exitSelectionMode()
                }
            }
        } catch {
            print("⚠️ Agent action failed: \(error)")
            await MainActor.run {
                isExecutingAction = false
                actionProgress = nil
                let message = error.localizedDescription
                if message.localizedCaseInsensitiveContains("daily free agent recipe limit reached") {
                    upgradeTitle = "Daily Agent Recipe limit reached"
                    showUpgradeSheet = true
                }
            }
        }
    }
}
