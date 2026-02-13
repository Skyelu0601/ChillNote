import SwiftUI
import SwiftData

extension HomeView {
    func handleAgentActionRequest(_ action: AIAgentAction) {
        if action.type == .custom {
            pendingAgentAction = action
            isCustomActionInputPresented = true
        } else if action.type == .translate {
            pendingAgentAction = action
            isTranslateInputPresented = true
        } else {
            Task { await executeAgentAction(action) }
        }
    }

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
        switch recipe.id {
        case "merge_notes":
            let action = AIAgentAction(
                type: .merge,
                title: recipe.name,
                icon: recipe.systemIcon,
                description: recipe.description,
                requiresConfirmation: true
            )
            Task { await executeAgentAction(action) }
        case "translate":
            let action = AIAgentAction(
                type: .translate,
                title: recipe.name,
                icon: recipe.systemIcon,
                description: recipe.description,
                requiresConfirmation: false
            )
            pendingAgentAction = action
            isTranslateInputPresented = true
        default:
            let action = AIAgentAction(
                type: .custom,
                title: recipe.name,
                icon: recipe.systemIcon,
                description: recipe.description,
                requiresConfirmation: false
            )
            Task { await executeAgentAction(action, instruction: recipe.prompt) }
        }
    }

    func executeAgentAction(_ action: AIAgentAction, instruction: String? = nil) async {
        let notesToProcess = getSelectedNotes()
        guard !notesToProcess.isEmpty else { return }

        await MainActor.run {
            isExecutingAction = true
            actionProgress = "Executing \(action.title)..."
        }

        do {
            _ = try await action.execute(on: notesToProcess, context: modelContext, userInstruction: instruction)

            await MainActor.run {
                persistAndSync()
                isExecutingAction = false
                actionProgress = nil

                if action.type == .merge {
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
