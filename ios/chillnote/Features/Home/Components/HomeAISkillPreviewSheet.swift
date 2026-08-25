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
    @State private var showsCopyToast = false
    @State private var copyToastTask: Task<Void, Never>?

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

                        ActionableSkillResultView(
                            recipe: preview.recipe,
                            result: preview.result,
                            onBlockCopied: showCopyToast
                        )
                    }
                    .padding(16)
                }

                applyActions
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
            .overlay(alignment: .bottom) {
                if showsCopyToast {
                    SkillResultCopyToast(onDismiss: hideCopyToast)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 82)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .onDisappear { copyToastTask?.cancel() }
    }

    private var contextText: String {
        if preview.sourceNoteIDs.count == 1 {
            return L10n.text("home.ai_skills.preview.single_context", preview.sourceTitle)
        }
        return L10n.text("home.ai_skills.preview.multiple_context", preview.sourceNoteIDs.count)
    }

    @ViewBuilder
    private var applyActions: some View {
        if preview.availableApplyModes.count == 2 {
            HStack(spacing: 0) {
                ForEach(Array(preview.availableApplyModes.enumerated()), id: \.element.id) { index, mode in
                    applyButton(for: mode, usesSharedContainer: true)

                    if index == 0 {
                        Divider()
                            .frame(height: 28)
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
        } else {
            VStack(spacing: 10) {
                ForEach(preview.availableApplyModes) { mode in
                    applyButton(for: mode, usesSharedContainer: false)
                }
            }
        }
    }

    private func applyButton(
        for mode: HomeAISkillApplyMode,
        usesSharedContainer: Bool
    ) -> some View {
        Button {
            dismiss()
            onApply(mode)
        } label: {
            Label(mode.title, systemImage: mode.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(usesSharedContainer ? Color.clear : Color.white)
                .foregroundColor(.textMain)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    if !usesSharedContainer {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.05), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func showCopyToast() {
        copyToastTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            showsCopyToast = true
        }
        copyToastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            hideCopyToast()
        }
    }

    private func hideCopyToast() {
        withAnimation(.easeIn(duration: 0.2)) {
            showsCopyToast = false
        }
    }
}

#if DEBUG
struct SkillResultScreenshotHost: View {
    @State private var isPresented = false

    var body: some View {
        Color.bgPrimary
            .ignoresSafeArea()
            .onAppear { isPresented = true }
            .sheet(isPresented: $isPresented) {
                HomeAISkillPreviewSheet(preview: Self.preview) { _ in }
            }
    }

    private static let preview: HomeAISkillPreview = {
        let recipe = AgentRecipe.allRecipes.first { $0.id == "hook_generator" }
            ?? AgentRecipe.allRecipes[0]
        return HomeAISkillPreview(
            recipe: recipe,
            result: """
            **Pain point:** Tired of spending hours on work AI could finish in seconds?

            **Contrarian:** Stop doing everything yourself. These five tools changed my workflow.

            **Curiosity gap:** I tested five AI tools, and the last one changed how I create.

            **How-to:** Build a lean creator workflow with these five AI tools.

            **Mistake:** You are still wasting time on tasks these tools can handle.

            **Story:** I rebuilt my entire creator workflow around five simple AI tools.
            """,
            sourceNoteIDs: [UUID(), UUID()],
            sourceTitle: "Creator workflow",
            instruction: nil
        )
    }()
}
#endif
