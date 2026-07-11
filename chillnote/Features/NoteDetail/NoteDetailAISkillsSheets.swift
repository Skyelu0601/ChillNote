import SwiftUI

struct NoteDetailAISkillsSheet: View {
    let recipes: [AgentRecipe]
    let onSelect: (AgentRecipe) -> Void

    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.adaptive(minimum: 130), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                if recipes.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundColor(.accentSecondary)

                        Text(L10n.text("note_detail.ai_skills.empty.title"))
                            .font(.title3.bold())
                            .foregroundColor(.textMain)

                        Text(L10n.text("note_detail.ai_skills.empty.message"))
                            .font(.body)
                            .foregroundColor(.textSub)
                            .fixedSize(horizontal: false, vertical: true)

                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(recipes) { recipe in
                                Button {
                                    dismiss()
                                    onSelect(recipe)
                                } label: {
                                    VStack(alignment: .leading, spacing: 10) {
                                        CreatorSkillIcon(recipe: recipe, size: 18, container: 40)

                                        Text(recipe.localizedName)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.textMain)
                                            .lineLimit(2)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        Text(recipe.localizedDescription)
                                            .font(.caption)
                                            .foregroundColor(.textSub)
                                            .lineLimit(3)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(14)
                                    .frame(maxWidth: .infinity, minHeight: 142, alignment: .topLeading)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.black.opacity(0.04), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle(L10n.text("note_detail.ai_skills.sheet.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("common.cancel")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }
}

struct NoteDetailAISkillPreviewSheet: View {
    let preview: NoteAISkillPreview
    let onApply: (NoteAISkillApplyMode) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            CreatorSkillIcon(recipe: preview.recipe, size: 18, container: 40)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(preview.recipe.localizedName)
                                    .font(.headline)
                                    .foregroundColor(.textMain)

                                Text(preview.hasSelection ? L10n.text("note_detail.ai_skills.preview.selection_context") : L10n.text("note_detail.ai_skills.preview.note_context"))
                                    .font(.caption)
                                    .foregroundColor(.textSub)
                            }
                        }

                        if preview.recipe.id == "style_match",
                           !BrandVoicePreferences.current.isConfigured {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.accentSecondary)
                                Text(L10n.text("brand_voice.preview.no_sample_hint"))
                                    .font(.caption)
                                    .foregroundColor(.textSub)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.secondaryHighlight.opacity(0.75))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }

                        Text(preview.result)
                            .font(.body)
                            .foregroundColor(.textMain)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color.bgSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(16)
                }

                VStack(spacing: 10) {
                    ForEach(preview.availableApplyModes) { mode in
                        Button {
                            dismiss()
                            onApply(mode)
                        } label: {
                            Label(mode.title, systemImage: mode.systemImage)
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.white)
                                .foregroundColor(.textMain)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .background(Color.bgPrimary)
            }
            .background(Color.bgPrimary.ignoresSafeArea())
            .navigationTitle(L10n.text("note_detail.ai_skills.preview.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("common.cancel")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }
}
