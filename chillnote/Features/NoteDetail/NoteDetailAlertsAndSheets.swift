import SwiftUI

struct NoteDetailAlertsAndSheets: ViewModifier {
    @ObservedObject var viewModel: NoteDetailViewModel

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $viewModel.showAddTagAlert) {
                AddTagSheetView(viewModel: viewModel)
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

private struct AddTagSheetView: View {
    @ObservedObject var viewModel: NoteDetailViewModel
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 42), spacing: 12)]

    private var trimmedName: String {
        viewModel.newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                TextField("Tag name", text: $viewModel.newTagName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.bgSecondary)
                    )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Color")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.textSub)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(TagColorService.paletteHexes, id: \.self) { hex in
                            let normalized = TagColorService.normalizedHex(hex)
                            let isSelected = viewModel.newTagColorHex == normalized
                            Button {
                                viewModel.newTagColorHex = normalized
                            } label: {
                                Circle()
                                    .fill(TagColorService.color(for: normalized))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                                            .padding(4)
                                    )
                                    .padding(4)
                                    .background(
                                        Circle()
                                            .stroke(isSelected ? Color.textMain : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Tag color \(normalized)")
                        }
                    }
                }

                HStack(spacing: 8) {
                    Text("Preview")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.textSub)

                    Text(trimmedName.isEmpty ? "New Tag" : trimmedName)
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(TagColorService.color(for: viewModel.newTagColorHex).opacity(TagColorService.tagBackgroundOpacity))
                        )
                        .foregroundColor(TagColorService.textColor(for: viewModel.newTagColorHex))
                }

                Spacer()
            }
            .padding(16)
            .navigationTitle("Add Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.showAddTagAlert = false
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        viewModel.confirmNewTagFromAlert()
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }
}
