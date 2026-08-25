import SwiftUI

enum NoteDetailWorkspacePage: String, CaseIterable, Identifiable {
    case script
    case create
    case record

    var id: String { rawValue }

    var title: String {
        switch self {
        case .script:
            return L10n.text("note_detail.workspace.tab.note")
        case .create:
            return L10n.text("note_detail.workspace.tab.create")
        case .record:
            return L10n.text("note_detail.workspace.tab.record")
        }
    }
}

struct NoteDetailWorkspacePicker: View {
    let selection: NoteDetailWorkspacePage
    let isCreateEnabled: Bool
    let guideRequiredPage: NoteDetailWorkspacePage?
    let guideTarget: FirstActionGuideTarget?
    let onSelect: (NoteDetailWorkspacePage) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(NoteDetailWorkspacePage.allCases) { page in
                Button {
                    onSelect(page)
                } label: {
                    HStack(spacing: 6) {
                        Text(page.title)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                    .font(.headline)
                    .foregroundColor(selection == page ? .brandBlueText : .textMain)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 56)
                    .overlay(alignment: .bottom) {
                        if selection == page {
                            Capsule()
                                .fill(Color.brandBlue)
                                .frame(width: 96, height: 3)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isDisabled(page))
                .opacity(isDisabled(page) ? 0.45 : 1)
                .accessibilityAddTraits(selection == page ? .isSelected : [])
                .firstActionGuideTarget(target(for: page))
            }
        }
        .background(Color.bgSecondary)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)
        }
    }

    private func isDisabled(_ page: NoteDetailWorkspacePage) -> Bool {
        if page == .create && !isCreateEnabled {
            return true
        }
        if let guideRequiredPage, page != guideRequiredPage {
            return true
        }
        return false
    }

    private func target(for page: NoteDetailWorkspacePage) -> FirstActionGuideTarget? {
        switch (guideTarget, page) {
        case (.createTab, .create):
            return .createTab
        case (.recordTab, .record):
            return .recordTab
        default:
            return nil
        }
    }
}

struct NoteDetailCreatePageView: View {
    let recipes: [AgentRecipe]
    let isEnabled: Bool
    let minimumHeight: CGFloat
    let onSelect: (AgentRecipe) -> Void
    let onManageSkills: () -> Void

    var body: some View {
        Group {
            if recipes.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.accentSecondary)

                    Text(L10n.text("note_detail.ai_skills.empty.title"))
                        .font(.headline)
                        .foregroundColor(.textMain)

                    Text(L10n.text("note_detail.ai_skills.empty.message"))
                        .font(.body)
                        .foregroundColor(.textSub)
                        .fixedSize(horizontal: false, vertical: true)

                    manageSkillsButton
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(recipes) { recipe in
                        skillButton(recipe)
                    }

                    manageSkillsButton
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .top)
    }

    private var manageSkillsButton: some View {
        Button(action: onManageSkills) {
            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.brandBlueText)
                    .frame(width: 24, height: 24)

                Text(L10n.text("note_detail.ai_skills.manage"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.brandBlueText)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.brandBlueText.opacity(0.72))
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Color.brandBlueSoft)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.brandBlue.opacity(0.22), lineWidth: 1)
            }
        }
        .buttonStyle(.bouncy)
    }

    private func skillButton(_ recipe: AgentRecipe) -> some View {
        Button {
            onSelect(recipe)
        } label: {
            HStack(spacing: 14) {
                CreatorSkillIcon(recipe: recipe, size: 19, container: 44)

                Text(recipe.localizedName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textMain)
                    .lineLimit(2)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.textSub)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 64)
            .background(Color.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.borderSubtle, lineWidth: 1)
            }
            .shadow(color: Color.shadowColor, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.bouncy)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .firstActionGuideTarget(recipe.id == recipes.first?.id ? .aiSkills : nil)
    }
}

struct NoteDetailRecordPageView: View {
    let script: String
    let isEnabled: Bool
    let minimumHeight: CGFloat
    let onStartRecording: () -> Void

    @State private var selectedPreviewPage = 0

    private var previewPages: [String] {
        Self.makePreviewPages(from: script)
    }

    var body: some View {
        VStack(spacing: 0) {
            scriptPreview
                .padding(.top, 22)

            Label {
                Text(L10n.text("note_detail.record.script_ready"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textMain)
            } icon: {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.green)
            }
            .padding(.top, 18)

            Button(action: onStartRecording) {
                Text(L10n.text("note_detail.record.action.start"))
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 56)
                    .background(Color.brandBlue)
                    .clipShape(Capsule())
            }
            .buttonStyle(.bouncy)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.5)
            .accessibilityLabel(L10n.text("note_detail.record.action.start"))
            .firstActionGuideTarget(.teleprompter)
            .padding(.top, 18)

            Text(L10n.text("note_detail.record.metadata"))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.textSub)
                .padding(.top, 12)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .top)
        .onChange(of: previewPages.count) { _, pageCount in
            selectedPreviewPage = min(selectedPreviewPage, max(pageCount - 1, 0))
        }
        .onChange(of: selectedPreviewPage) { oldPage, newPage in
            guard oldPage != newPage else { return }
            AppInteractionFeedback.selectionChanged()
        }
    }

    private var scriptPreview: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedPreviewPage) {
                ForEach(Array(previewPages.enumerated()), id: \.offset) { index, page in
                    Text(page)
                        .font(.system(size: 18, weight: .medium))
                        .lineSpacing(6)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.horizontal, 22)
                        .padding(.top, 34)
                        .padding(.bottom, 18)
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .white, location: 0),
                                    .init(color: .white, location: 0.48),
                                    .init(color: .white.opacity(0.34), location: 0.78),
                                    .init(color: .clear, location: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 12) {
                ForEach(previewPages.indices, id: \.self) { index in
                    Circle()
                        .fill(index == selectedPreviewPage ? Color.white : Color.white.opacity(0.28))
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                }
            }
            .frame(height: 28)
        }
        .frame(width: 220, height: 318)
        .background(Color(hex: "111418"))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.14), radius: 10, x: 0, y: 5)
        .accessibilityHidden(true)
    }

    private static func makePreviewPages(from script: String) -> [String] {
        let words = script
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)

        guard !words.isEmpty else {
            return [L10n.text("teleprompter.script.empty_placeholder")]
        }

        let pageCount = min(3, max(1, (words.count + 69) / 70))
        let pageSize = (words.count + pageCount - 1) / pageCount

        return stride(from: 0, to: words.count, by: pageSize).map { start in
            let end = min(start + pageSize, words.count)
            return words[start..<end].joined(separator: " ")
        }
    }
}
