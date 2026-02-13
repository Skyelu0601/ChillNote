import SwiftUI

struct NoteDetailAlertsAndSheets: ViewModifier {
    @ObservedObject var viewModel: NoteDetailViewModel

    func body(content: Content) -> some View {
        content
            .alert("Add Tag", isPresented: $viewModel.showAddTagAlert) {
                TextField("Tag name", text: $viewModel.newTagName)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button("Cancel", role: .cancel) { }
                Button("Add") {
                    viewModel.confirmNewTagFromAlert()
                }
            } message: {
                Text("Enter a name for your custom tag.")
            }
            .alert("Delete Note", isPresented: $viewModel.showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    viewModel.confirmDeleteNote()
                }
            } message: {
                Text("Are you sure you want to delete this note? This action cannot be undone.")
            }
            .alert("Delete Permanently", isPresented: $viewModel.showPermanentDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Permanently", role: .destructive) {
                    viewModel.confirmDeleteNotePermanently()
                }
            } message: {
                Text("This will permanently delete the note. This action cannot be undone.")
            }
            .alert("Export Failed", isPresented: $viewModel.showExportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.exportErrorMessage)
            }
            .sheet(isPresented: $viewModel.showExportSheet) {
                if let exportURL = viewModel.exportURL {
                    ShareSheet(activityItems: [exportURL])
                }
            }
            .sheet(isPresented: $viewModel.showUpgradeSheet) {
                UpgradeBottomSheet(
                    title: viewModel.upgradeTitle,
                    message: UpgradeBottomSheet.unifiedMessage,
                    primaryButtonTitle: "Upgrade to Pro",
                    onUpgrade: {
                        viewModel.showUpgradeSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            viewModel.showSubscription = true
                        }
                    },
                    onDismiss: {
                        viewModel.showUpgradeSheet = false
                    }
                )
                .presentationDetents([.height(350)])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $viewModel.showSubscription) {
                SubscriptionView()
            }
    }
}

extension View {
    func noteDetailAlertsAndSheets(viewModel: NoteDetailViewModel) -> some View {
        modifier(NoteDetailAlertsAndSheets(viewModel: viewModel))
    }
}
