import SwiftUI

struct NoteConversationView: View {
    @ObservedObject var store: NoteConversationStore
    let recipes: [AgentRecipe]
    @Binding var isExpanded: Bool
    let enabled: Bool
    let content: String
    let onSkill: (AgentRecipe) -> Void
    let save: (String) -> Bool
    @State private var showsSkills = false
    @State private var selectedSkill: AgentRecipe?
    @State private var readingPosition: String?
    @FocusState private var focused: Bool

    private var quickSkills: [AgentRecipe] {
        let preferred = ["rewrite", "hook_generator", "caption_pack", "repurpose_pack"]
        let ordered = preferred.compactMap { id in recipes.first { $0.id == id } }
        return Array((ordered + recipes.filter { !preferred.contains($0.id) }).prefix(4))
    }

    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                HStack {
                    expandButton
                    Spacer()
                    Text(L10n.text("chillo.title")).font(.headline)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 12)
            }
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
                    .padding(.vertical, 20)
                }
                .scrollPosition(id: $readingPosition, anchor: .top)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: store.turns.count) { _, _ in scrollToBottom(proxy) }
                .onChange(of: store.busy) { _, _ in scrollToBottom(proxy) }
                .onChange(of: focused) { _, focus in if focus { scrollToBottom(proxy) } }
            }
            .overlay(alignment: .topLeading) {
                if !isExpanded { expandButton.padding(.leading, 12).padding(.top, 8) }
            }
            composer
        }
        .background(Color.bgSecondary)
        .sheet(isPresented: $showsSkills, onDismiss: {
            if let recipe = selectedSkill { selectedSkill = nil; onSkill(recipe) }
        }) {
            NoteDetailAISkillsSheet(onSelect: { selectedSkill = $0 })
        }
        .sheet(isPresented: $store.showSubscription) { SubscriptionView() }
    }

    private var expandButton: some View {
        Button { isExpanded.toggle() } label: {
            ChatFullscreenIcon(isExpanded: isExpanded)
                .stroke(Color.textSub, style: StrokeStyle(lineWidth: 1.5, lineCap: .square, lineJoin: .miter))
                .frame(width: 13, height: 13)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.text(isExpanded ? "note_chat.collapse" : "note_chat.expand"))
        .accessibilityIdentifier("note-chat-expand")
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(L10n.text("note_chat.welcome.title"))
                    .font(.title2.bold()).foregroundStyle(Color.textMain)
                Spacer(minLength: 0)
                Button { focused = false; showsSkills = true } label: {
                    Image(systemName: "ellipsis").frame(width: 44, height: 44)
                }
                .foregroundStyle(Color.textSub)
                .disabled(!enabled || store.busy)
                .accessibilityLabel(L10n.text("note_chat.all_skills"))
                .accessibilityIdentifier("note-chat-skills")
            }
            Text(L10n.text("note_chat.welcome.message"))
                .foregroundStyle(Color.textSub)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(quickSkills) { recipe in
                    Button { sendSkill(recipe) } label: {
                        HStack(spacing: 10) {
                            CreatorSkillIcon(recipe: recipe, size: 18, container: 34)
                            Text(recipe.localizedName).font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.textMain)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(RoundedRectangle(cornerRadius: 14).stroke(Color.borderSubtle))
                    }
                    .buttonStyle(.plain).disabled(!enabled || store.busy)
                    .accessibilityIdentifier("note-chat-skill-\(recipe.id)")
                    .firstActionGuideTarget(recipe.id == quickSkills.first?.id ? .aiSkills : nil)
                }
            }
        }
        .padding(.top, 32)
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
                    Button { UIPasteboard.general.string = answer } label: {
                        Image(systemName: "doc.on.doc").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(L10n.text("chillo.copy"))
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
            if let error = store.error {
                Text(error).font(.caption).foregroundStyle(Color.red)
            }
            if store.canUndo(currentContent: content) {
                HStack {
                    Spacer()
                    Button(L10n.text("common.undo")) { store.undo(save: save) }
                        .accessibilityIdentifier("note-chat-undo")
                        .disabled(!enabled || store.busy)
                }
            }
            HStack(alignment: .bottom, spacing: 8) {
                if !store.turns.isEmpty {
                    Button { focused = false; showsSkills = true } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18)).foregroundStyle(Color.textSub)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain).disabled(!enabled || store.busy)
                    .padding(.leading, 4).padding(.bottom, 1)
                    .accessibilityLabel(L10n.text("note_chat.all_skills"))
                    .accessibilityIdentifier("note-chat-skills")
                    .firstActionGuideTarget(.aiSkills)
                }
                TextField(L10n.text("chillo.placeholder"), text: $store.input, axis: .vertical)
                    .lineLimit(1...5).focused($focused)
                    .accessibilityIdentifier("note-chat-input")
                    .padding(.vertical, 12).padding(.leading, store.turns.isEmpty ? 14 : 0)
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

/// Four-corner fullscreen glyph, matching the Android conversation control.
private struct ChatFullscreenIcon: Shape {
    let isExpanded: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for x in [CGFloat(0), 1] {
            for y in [CGFloat(0), 1] {
                let dx: CGFloat = x == 0 ? 1 : -1
                let dy: CGFloat = y == 0 ? 1 : -1
                let corner = CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
                let horizontal = CGPoint(x: corner.x + dx * rect.width / 3, y: corner.y)
                let vertical = CGPoint(x: corner.x, y: corner.y + dy * rect.height / 3)
                let elbow = isExpanded ? CGPoint(x: horizontal.x, y: vertical.y) : corner
                path.move(to: horizontal)
                path.addLine(to: elbow)
                path.addLine(to: vertical)
            }
        }
        return path
    }
}
