import SwiftUI

enum HomeAISkillApplyMode: String, CaseIterable, Identifiable {
    case replace
    case append
    case saveAsDraft
    case copy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .replace:
            return L10n.text("home.ai_skills.preview.action.replace")
        case .append:
            return L10n.text("home.ai_skills.preview.action.append")
        case .saveAsDraft:
            return L10n.text("home.ai_skills.preview.action.save_as_draft")
        case .copy:
            return L10n.text("home.ai_skills.preview.action.copy")
        }
    }

    var systemImage: String {
        switch self {
        case .replace:
            return "arrow.triangle.2.circlepath"
        case .append:
            return "text.append"
        case .saveAsDraft:
            return "square.and.pencil"
        case .copy:
            return "doc.on.doc"
        }
    }
}

struct HomeAISkillPreview: Identifiable {
    let id = UUID()
    let recipe: AgentRecipe
    let result: String
    let sourceNoteIDs: [UUID]
    let sourceTitle: String
    let instruction: String?

    var canModifySourceNote: Bool {
        sourceNoteIDs.count == 1
    }

    var availableApplyModes: [HomeAISkillApplyMode] {
        canModifySourceNote ? [.replace, .append, .saveAsDraft, .copy] : [.saveAsDraft, .copy]
    }
}

struct HomeAISkillPreviewSheet: View {
    let preview: HomeAISkillPreview
    let onApply: (HomeAISkillApplyMode) -> Void

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

                                Text(contextText)
                                    .font(.caption)
                                    .foregroundColor(.textSub)
                                    .lineLimit(2)
                            }
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
            .navigationTitle(L10n.text("home.ai_skills.preview.title"))
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

    private var contextText: String {
        if preview.sourceNoteIDs.count == 1 {
            return L10n.text("home.ai_skills.preview.single_context", preview.sourceTitle)
        }
        return L10n.text("home.ai_skills.preview.multiple_context", preview.sourceNoteIDs.count)
    }
}
