import SwiftUI

struct NoteConversationView: View {
    @ObservedObject var store: NoteConversationStore
    let recipes: [AgentRecipe]
    let enabled: Bool
    let content: String
    let onSkill: (AgentRecipe) -> Void
    let save: (String) -> Bool
    @State private var showsSkills = false
    @State private var showsClearConfirmation = false
    @State private var readingPosition: String?
    @FocusState private var focused: Bool

    private var quickSkills: [AgentRecipe] {
        Array(recipes.prefix(4))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        if store.turns.isEmpty { welcome.padding(.horizontal, 20) }
                        ForEach(store.turns) { turn in
                            // Keep the scroll target full-width; its text inset must travel with it.
                            conversationTurn(turn)
                                .padding(.horizontal, 20)
                                .id(turn.id.uuidString)
                        }
                        if store.busy {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text(L10n.text("chillo.working")).foregroundStyle(Color.textSub)
                            }
                            .padding(.horizontal, 20)
                        }
                        Color.clear.frame(height: 1).id("conversation-bottom")
                    }
                    .scrollTargetLayout()
                    .padding(.vertical, store.turns.isEmpty ? 12 : 20)
                }
                .scrollPosition(id: $readingPosition, anchor: .top)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: store.turns.count) { _, _ in scrollToBottom(proxy) }
                .onChange(of: store.busy) { _, _ in scrollToBottom(proxy) }
                .onChange(of: focused) { _, focus in if focus { scrollToBottom(proxy) } }
            }
            composer
        }
        .background(Color.bgSecondary)
        .sheet(isPresented: $showsSkills) {
            NoteDetailAISkillsSheet()
        }
        .sheet(isPresented: $store.showSubscription) { SubscriptionView() }
        .alert(L10n.text("note_chat.clear.title"), isPresented: $showsClearConfirmation) {
            Button(L10n.text("common.cancel"), role: .cancel) {}
            Button(L10n.text("note_chat.clear.action"), role: .destructive) {
                store.clearConversation()
                readingPosition = nil
            }
        } message: {
            Text(L10n.text("note_chat.clear.message"))
        }
    }

    private var conversationMenu: some View {
        Menu {
            Button {
                focused = false
                showsSkills = true
            } label: {
                Label(L10n.text("recipes.action.manage"), systemImage: "sparkles")
            }
            .disabled(store.busy)
            .accessibilityIdentifier("note-chat-menu-skills")
            if !store.turns.isEmpty {
                Button(role: .destructive) {
                    focused = false
                    showsClearConfirmation = true
                } label: {
                    Label(L10n.text("note_chat.clear.action"), systemImage: "trash")
                }
                .accessibilityIdentifier("note-chat-clear")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44)
        }
        .foregroundStyle(Color.textSub)
        .disabled(!enabled)
        .accessibilityLabel(L10n.text("note_chat.menu"))
        .accessibilityIdentifier("note-chat-menu")
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("note_chat.welcome.title"))
                .font(.headline).foregroundStyle(Color.textMain)
            VStack(spacing: 8) {
                ForEach(quickSkills) { recipe in
                    Button { sendSkill(recipe) } label: {
                        HStack(spacing: 14) {
                            CreatorSkillIcon(recipe: recipe, size: 20, container: 36)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(recipe.localizedName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.textMain)
                                Text(quickSkillDescription(recipe))
                                    .font(.footnote)
                                    .foregroundStyle(Color.textSub)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.textSub)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(recipe.id == quickSkills.first?.id ? Color.brandBlueSoft : Color.bgSecondary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(recipe.id == quickSkills.first?.id ? Color.brandBlue.opacity(0.12) : Color.borderSubtle)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain).disabled(!enabled || store.busy)
                    .accessibilityIdentifier("note-chat-skill-\(recipe.id)")
                    .firstActionGuideTarget(recipe.id == quickSkills.first?.id ? .aiSkills : nil)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.text("note_chat.suggestions.title"))
                    .font(.headline).foregroundStyle(Color.textMain)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        promptSuggestion("script")
                        promptSuggestion("hooks")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        promptSuggestion("script")
                        promptSuggestion("hooks")
                    }
                }
            }
            .padding(.top, 8)
        }
        .padding(.top, 4)
    }

    private func quickSkillDescription(_ recipe: AgentRecipe) -> String {
        guard !recipe.isCustom else { return recipe.localizedDescription }
        switch recipe.id {
        case "rewrite", "hook_generator", "caption_pack", "repurpose_pack":
            return L10n.text("note_chat.quick_skill.\(recipe.id).description")
        default:
            return recipe.localizedDescription
        }
    }

    private func promptSuggestion(_ name: String) -> some View {
        let prompt = L10n.text("note_chat.suggestions.\(name)")
        return Button {
            store.input = prompt
            focused = true
        } label: {
            Text(prompt)
                .font(.caption)
                .foregroundStyle(Color.textSub)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .fixedSize(horizontal: false, vertical: true)
                .background(Color.bgPrimary, in: Capsule())
                .overlay(Capsule().stroke(Color.borderSubtle))
        }
        .buttonStyle(.plain)
        .disabled(!enabled || store.busy)
        .accessibilityIdentifier("note-chat-prompt-\(name)")
    }

    private func conversationTurn(_ turn: NoteConversationTurn) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Spacer(minLength: 32)
                Group {
                    if let recipe = turn.recipe {
                        HStack(spacing: 8) {
                            CreatorSkillIcon(recipe: recipe, size: 16, container: 26)
                            Text(recipe.localizedName).fontWeight(.medium)
                            Text(L10n.text("note_chat.skill_badge"))
                                .font(.caption).foregroundStyle(Color.textSub)
                                .padding(.horizontal, 5).padding(.vertical, 3)
                                .background(Color.brandBlue.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                        }
                    } else { Text(turn.message).textSelection(.enabled) }
                }
                .padding(12).background(Color.brandBlueSoft, in: RoundedRectangle(cornerRadius: 16))
            }
            if let answer = turn.answer {
                ChilloAnswerText(answer: answer, removesCitations: false)
                    .accessibilityIdentifier("note-chat-answer-\(turn.id)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(Color.textMain)
                HStack(spacing: 12) {
                    Button { store.replace(with: turn, save: save) } label: {
                        Label(L10n.text("note_chat.replace"), systemImage: "arrow.triangle.2.circlepath")
                            .font(.subheadline).padding(.horizontal, 12).padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10).stroke(Color.borderSubtle))
                    }
                    .disabled(!enabled || store.busy)
                    .accessibilityIdentifier("note-chat-replace-\(turn.id)")
                    if store.appliedTurnID == turn.id && store.canUndo(currentContent: content) {
                        Button(L10n.text("common.undo")) { store.undo(save: save) }
                            .font(.subheadline)
                            .accessibilityIdentifier("note-chat-undo")
                            .disabled(!enabled || store.busy)
                    }
                    NoteConversationCopyButton(answer: answer, turnID: turn.id)
                }
                .buttonStyle(.plain).foregroundStyle(Color.textMain)
            } else if turn.failed {
                HStack {
                    Text(L10n.text("note_chat.failed")).foregroundStyle(Color.textSub)
                    if turn.id == store.turns.last?.id {
                        Button(L10n.text("chillo.retry")) { store.retry(turn) }
                            .disabled(!enabled || store.busy)
                    }
                }
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !store.turns.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(quickSkills) { recipe in
                            Button { sendSkill(recipe) } label: {
                                Text(recipe.localizedName).font(.footnote)
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(Color.brandBlueSoft, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(!enabled || store.busy)
                            .accessibilityIdentifier("note-chat-skill-\(recipe.id)")
                            .firstActionGuideTarget(recipe.id == quickSkills.first?.id ? .aiSkills : nil)
                        }
                    }
                }
            }
            if let error = store.error {
                Text(error).font(.caption).foregroundStyle(Color.red)
            }
            HStack(alignment: .bottom, spacing: 8) {
                conversationMenu
                    .padding(.leading, 4).padding(.bottom, 1)
                TextField(L10n.text("note_chat.input.placeholder"), text: $store.input, axis: .vertical)
                    .lineLimit(1...5).focused($focused)
                    .accessibilityIdentifier("note-chat-input")
                    .padding(.vertical, 12)
                    .disabled(!enabled)
                Button {
                    if store.busy { store.cancel() } else { focused = false; store.send() }
                } label: {
                    Image(systemName: store.busy ? "stop.fill" : "arrow.up")
                        .font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(store.busy || !store.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.brandBlue : Color.gray.opacity(0.4), in: Circle())
                }
                .accessibilityLabel(L10n.text(store.busy ? "common.cancel" : "chillo.send"))
                .accessibilityIdentifier("note-chat-send")
                .disabled(!enabled || (!store.busy && store.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                .padding(.trailing, 4).padding(.bottom, 3)
            }
            .background(RoundedRectangle(cornerRadius: 24).stroke(Color.borderSubtle))
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    private func sendSkill(_ recipe: AgentRecipe) {
        focused = false; onSkill(recipe)
    }
    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("conversation-bottom", anchor: .bottom) }
    }
}

private struct NoteConversationCopyButton: View {
    let answer: String
    let turnID: UUID
    @State private var isCopied = false
    @State private var copyRevision = 0

    var body: some View {
        Button {
            UIPasteboard.general.string = answer
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            isCopied = true
            copyRevision += 1
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .frame(width: 44, height: 44)
                if isCopied {
                    Text(L10n.text("ai_skills.result.copy_success")).font(.footnote)
                }
            }
            .foregroundStyle(isCopied ? Color.accentSecondaryText : Color.textMain)
        }
        .accessibilityLabel(L10n.text("chillo.copy"))
        .accessibilityValue(isCopied ? L10n.text("ai_skills.result.copy_success") : "")
        .accessibilityIdentifier("note-chat-copy-\(turnID)")
        .task(id: copyRevision) {
            guard copyRevision > 0 else { return }
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            isCopied = false
        }
    }
}
