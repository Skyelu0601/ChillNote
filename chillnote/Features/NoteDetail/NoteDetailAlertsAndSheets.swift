import SwiftUI

struct NoteDetailAlertsAndSheets: ViewModifier {
    @ObservedObject var viewModel: NoteDetailViewModel
    @StateObject private var recipeManager = RecipeManager.shared

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $viewModel.showAddTagAlert) {
                AddTagSheetView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showAISkillsSheet) {
                NoteDetailAISkillsSheet(
                    recipes: recipeManager.savedRecipes,
                    onSelect: { viewModel.startAISkill($0) }
                )
            }
            .sheet(isPresented: $viewModel.showAISkillTranslateSheet) {
                TranslateSheetView(
                    translateLanguages: TranslateLanguage.defaultLanguages,
                    onSelect: { viewModel.startPendingTranslateAISkill(targetLanguage: $0) },
                    onCancel: { viewModel.cancelPendingTranslateAISkill() }
                )
            }
            .sheet(item: $viewModel.aiSkillPreview) { preview in
                NoteDetailAISkillPreviewSheet(
                    preview: preview,
                    onApply: { viewModel.applyAISkillPreview(preview, mode: $0) }
                )
            }
            .alert(L10n.text("note_detail.alert.delete.title"), isPresented: $viewModel.showDeleteConfirmation) {
                Button(L10n.text("common.cancel"), role: .cancel) { }
                Button(L10n.text("common.delete"), role: .destructive) {
                    viewModel.confirmDeleteNote()
                }
            } message: {
                Text(L10n.text("note_detail.alert.delete.message"))
            }
            .alert(L10n.text("note_detail.alert.permanent_delete.title"), isPresented: $viewModel.showPermanentDeleteConfirmation) {
                Button(L10n.text("common.cancel"), role: .cancel) { }
                Button(L10n.text("note_detail.alert.permanent_delete.action"), role: .destructive) {
                    viewModel.confirmDeleteNotePermanently()
                }
            } message: {
                Text(L10n.text("note_detail.alert.permanent_delete.message"))
            }
            .alert(L10n.text("note_detail.alert.export_failed.title"), isPresented: $viewModel.showExportError) {
                Button(L10n.text("common.ok"), role: .cancel) { }
            } message: {
                Text(viewModel.exportErrorMessage)
            }
            .alert(L10n.text("note_detail.ai_skills.error.title"), isPresented: Binding(
                get: { viewModel.aiSkillErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.aiSkillErrorMessage = nil
                    }
                }
            )) {
                Button(L10n.text("common.ok"), role: .cancel) { }
            } message: {
                Text(viewModel.aiSkillErrorMessage ?? "")
            }
            .sheet(isPresented: $viewModel.showExportSheet) {
                if let exportURL = viewModel.exportURL {
                    ShareSheet(activityItems: [exportURL])
                }
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
                TextField(L10n.text("note_detail.add_tag.name_placeholder"), text: $viewModel.newTagName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.bgSecondary)
                    )

                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.text("note_detail.add_tag.color_label"))
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
                            .accessibilityLabel(
                                L10n.text("tag.color.accessibility", normalized)
                            )
                        }
                    }
                }

                HStack(spacing: 8) {
                    Text(L10n.text("note_detail.add_tag.preview_label"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.textSub)

                    Text(trimmedName.isEmpty ? L10n.text("note_detail.add_tag.new_tag_label") : trimmedName)
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
            .navigationTitle(L10n.text("note_detail.add_tag.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("common.cancel")) {
                        viewModel.showAddTagAlert = false
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("common.add")) {
                        viewModel.confirmNewTagFromAlert()
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }
}
