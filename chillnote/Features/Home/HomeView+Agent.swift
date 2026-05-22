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
            _ = try await recipe.execute(on: notesToProcess, context: modelContext, userInstruction: instruction)

            await MainActor.run {
                persistAndSync()
                isExecutingAction = false
                actionProgress = nil
                exitSelectionMode()
            }
        } catch {
            print("⚠️ Agent action failed: \(error)")
            await MainActor.run {
                isExecutingAction = false
                actionProgress = nil
                let message = error.localizedDescription
                if message.localizedCaseInsensitiveContains("daily free agent recipe limit reached") {
                    showSubscription = true
                }
            }
        }
    }
}
