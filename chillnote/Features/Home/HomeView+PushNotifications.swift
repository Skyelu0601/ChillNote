import SwiftUI

extension HomeView {
    private var importNotificationPermissionPromptKey: String {
        "notification.import_permission_prompt_seen.\(currentUserId ?? "signed_out")"
    }

    func evaluateImportNotificationPermissionPrompt() async {
        guard currentUserId != nil,
              !UserDefaults.standard.bool(forKey: importNotificationPermissionPromptKey),
              homeViewModel.items.contains(where: {
                  $0.sourceURL != nil
                      && Date().timeIntervalSince($0.createdAt) <= 24 * 60 * 60
              }),
              await PushNotificationManager.shared.shouldOfferImportCompletionAlerts() else {
            return
        }
        showImportNotificationPermissionPrompt = true
    }

    func markImportNotificationPermissionPromptSeen() {
        UserDefaults.standard.set(true, forKey: importNotificationPermissionPromptKey)
    }

    func handlePendingPushNotificationDestination() {
        guard let destination = PushNotificationManager.shared.consumePendingDestination() else {
            return
        }

        Task { @MainActor in
            switch destination {
            case .home:
                navigationPath = NavigationPath()

            case .note(let noteID):
                _ = await syncManager.syncNow(context: modelContext)
                await homeViewModel.reload(keepItemsWhileLoading: true)
                guard let note = resolveNote(noteID) else { return }
                navigationPath.append(note)
            }
        }
    }
}
