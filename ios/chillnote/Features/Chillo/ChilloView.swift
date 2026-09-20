import SwiftUI
import SwiftData
import UIKit

struct ChilloRoute: Hashable { }

struct ChilloView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var syncManager: SyncManager
    @StateObject private var store = ChilloStore()
    @StateObject private var dictation = ChilloDictation()
    @State private var sheet: Sheet?
    @State private var note: Note?
    @State private var deleteID: String?
    @State private var syncFailed = false
    @FocusState private var focused: Bool
    private enum Sheet: Identifiable {
        case history, sources(ChilloTurn), library
        var id: String {
            switch self { case .history: return "history"; case .sources(let turn): return turn.id; case .library: return "library" }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            messages
        }
        .background(Color.white.ignoresSafeArea())
        .foregroundStyle(Color.black)
        .tint(.brandBlue)
        .preferredColorScheme(.light)
        .navigationBarHidden(true)
        .safeAreaInset(edge: .bottom, spacing: 0) { composer }
        .task {
            await store.load()
            if let id = store.conversationID { await store.open(id) }
            syncFailed = !(await syncManager.syncNow(context: modelContext))
            await store.poll()
        }
        .onDisappear { dictation.stop() }
        .onChange(of: authService.currentUserId) { _, _ in dismiss() }
        .onChange(of: dictation.transcript) { _, text in store.input = text }
        .sheet(item: $sheet) { destination in
            NavigationStack {
                sheetContent(destination)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L10n.text("common.close")) { sheet = nil }
                        }
                    }
            }
            .presentationDragIndicator(.visible)
            .presentationDetents([.medium, .large])
        }
        .navigationDestination(item: $note) { note in NoteDetailView(note: note) }
        .alert(L10n.text("chillo.delete.title"), isPresented: Binding(get: { deleteID != nil }, set: { if !$0 { deleteID = nil } })) {
            Button(L10n.text("common.cancel"), role: .cancel) { deleteID = nil }
            Button(L10n.text("common.delete"), role: .destructive) {
                if let id = deleteID { Task { await store.remove(id) } }
                deleteID = nil
            }
        } message: { Text(L10n.text("chillo.delete.body")) }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                .accessibilityLabel(L10n.text("common.back"))
            Spacer()
            Button { focused = false; sheet = .history } label: {
                HStack(spacing: 5) {
                    Text(L10n.text("chillo.title")).font(.system(size: 19, weight: .semibold))
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                }.frame(minHeight: 44)
            }.accessibilityLabel(L10n.text("chillo.history"))
            Spacer()
            Button { dictation.stop(); store.newConversation() } label: { Image(systemName: "square.and.pencil").frame(width: 44, height: 44) }
                .disabled(store.busy).accessibilityLabel(L10n.text("chillo.new"))
        }
        .font(.system(size: 20))
        .foregroundStyle(.black)
        .padding(.horizontal, 10)
    }

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    if syncFailed { Text(L10n.text("chillo.sync.warning")).font(.footnote).foregroundStyle(.secondary) }
                    if store.turns.isEmpty { emptyState }
                    if store.olderCursor != nil {
                        Button(L10n.text("chillo.more")) { Task { await store.loadOlder() } }
                    }
                    ForEach(store.turns) { turn in
                        turnView(turn).id(turn.id)
                    }
                    if let error = store.error {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(error).font(.footnote).foregroundStyle(.secondary)
                            Button(L10n.text("chillo.retry")) { Task { await store.load(); await store.reload() } }
                                .font(.footnote)
                        }
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 22).padding(.vertical, 26)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: store.turns.last?.id) { _, _ in withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
            .onChange(of: store.turns.last?.status) { _, _ in
                if store.turns.last?.status == "completed", let id = store.turns.last?.id { withAnimation { proxy.scrollTo(id, anchor: .top) } }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L10n.text("chillo.empty.title")).font(.system(size: 24, weight: .semibold))
            Text(L10n.text("chillo.empty.body")).font(.system(size: 15)).foregroundStyle(.secondary).lineSpacing(4)
            if store.library != nil && store.needsConsent {
                Text(L10n.text("chillo.consent.body")).font(.footnote).foregroundStyle(.secondary).lineSpacing(3)
                Button(L10n.text("chillo.consent.accept")) { Task { await store.consent(true) } }
                    .buttonStyle(.borderedProminent).tint(.brandBlue)
            } else {
                ForEach(["chillo.suggestion.ideas", "chillo.suggestion.connect"], id: \.self) { key in
                    Button { store.input = L10n.text(key); focused = true } label: {
                        Text(L10n.text(key)).font(.system(size: 14)).multilineTextAlignment(.leading)
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            .overlay(Capsule().stroke(Color.black.opacity(0.09)))
                    }.foregroundStyle(.black)
                }
            }
        }.padding(.top, 68).padding(.bottom, 24)
    }

    private func turnView(_ turn: ChilloTurn) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Spacer(minLength: 40)
                Text(turn.request).font(.system(size: 16)).lineSpacing(5)
                    .padding(.horizontal, 17).padding(.vertical, 13)
                    .background(Color(red: 238 / 255, green: 245 / 255, blue: 1), in: RoundedRectangle(cornerRadius: 21))
                    .textSelection(.enabled)
            }
            if turn.isActive {
                HStack(spacing: 10) { ProgressView(); Text(L10n.text("chillo.working")).font(.subheadline).foregroundStyle(.secondary) }
            } else if turn.sourcesChanged {
                Text(L10n.text("chillo.sources.changed")).font(.subheadline).foregroundStyle(.secondary)
            } else if !turn.answer.isEmpty {
                ChilloAnswerText(answer: turn.answer)
                HStack(spacing: 20) {
                    if !turn.sources.isEmpty {
                        Button { sheet = .sources(turn) } label: {
                            Label(L10n.text("chillo.sources.count", Int64(Set(turn.sources.map(\.noteId)).count)), systemImage: "doc.text")
                        }.font(.footnote)
                    }
                    Spacer(minLength: 0)
                    Button { UIPasteboard.general.string = ChilloCitationRenderer.plainAnswer(turn.answer) } label: { Image(systemName: "doc.on.doc") }
                        .accessibilityLabel(L10n.text("chillo.copy"))
                    Button { Task { if let id = await store.action("draft", turn: turn) { await openNote(id) } } } label: {
                        Image(systemName: turn.draftNoteId == nil ? "square.and.arrow.down" : "checkmark")
                    }.disabled(store.busy).accessibilityLabel(L10n.text(turn.draftNoteId == nil ? "chillo.save" : "chillo.open.draft"))
                }.font(.system(size: 16)).foregroundStyle(.secondary)
            } else {
                Text(turn.status == "cancelled" ? L10n.text("chillo.stopped") : ChilloStore.errorText(turn.errorCode)).font(.subheadline).foregroundStyle(.secondary)
                if turn.id == store.turns.last?.id {
                    Button(L10n.text("chillo.retry")) { Task { _ = await store.action("retry", turn: turn) } }.disabled(store.busy)
                }
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 4) {
            if let error = dictation.error { Text(error).font(.caption).foregroundStyle(.secondary) }
            HStack(alignment: .bottom, spacing: 10) {
                Button { focused = false; sheet = .library } label: { Image(systemName: "plus").frame(width: 32, height: 40) }
                    .accessibilityLabel(L10n.text("chillo.library"))
                TextField(L10n.text("chillo.placeholder"), text: $store.input, axis: .vertical)
                    .lineLimit(1...6).font(.system(size: 16)).focused($focused)
                    .padding(.vertical, 10).disabled(store.busy)
                Button { Task { if dictation.recording { dictation.stop() } else { await dictation.start(prefix: store.input) } } } label: {
                    Image(systemName: dictation.recording ? "stop.circle" : "mic").frame(width: 28, height: 40)
                }.accessibilityLabel(L10n.text("chillo.dictate")).disabled(store.busy || store.generating)
                Button {
                    dictation.stop()
                    if let turn = store.turns.last, turn.isActive { Task { _ = await store.action("cancel", turn: turn) } }
                    else { focused = false; Task { await store.send() } }
                } label: {
                    Image(systemName: store.generating ? "stop.fill" : "arrow.up")
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 34, height: 34).background(.black, in: Circle())
                        .padding(.bottom, 3)
                }
                .disabled(store.busy || (!store.generating && (store.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.needsConsent || store.input.count > 16000)))
                .opacity(store.needsConsent || (store.input.isEmpty && !store.generating) ? 0.3 : 1)
                .accessibilityLabel(L10n.text(store.generating ? "chillo.stop" : "chillo.send"))
            }
            .foregroundStyle(.black).padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 27))
            .overlay(RoundedRectangle(cornerRadius: 27).stroke(Color.black.opacity(0.12)))
            .padding(.horizontal, 16).padding(.vertical, 8)
        }.background(.white)
    }

    @ViewBuilder private func sheetContent(_ destination: Sheet) -> some View {
        switch destination {
        case .history:
            List {
                ForEach(store.history) { conversation in
                    Button(conversation.title.isEmpty ? L10n.text("chillo.new") : conversation.title) {
                        sheet = nil; Task { await store.open(conversation.id) }
                    }.foregroundStyle(.primary)
                    .swipeActions { Button(role: .destructive) { deleteID = conversation.id } label: { Label(L10n.text("common.delete"), systemImage: "trash") } }
                }
                if store.historyCursor != nil { Button(L10n.text("chillo.more")) { Task { await store.moreHistory() } } }
            }.navigationTitle(L10n.text("chillo.history")).navigationBarTitleDisplayMode(.inline)
        case .sources(let turn):
            List(uniqueChilloSources(turn.sources)) { source in
                VStack(alignment: .leading, spacing: 10) {
                    Button { sheet = nil; Task { await openNote(source.noteId) } } label: {
                        Text(verbatim: source.title).font(.headline)
                    }.disabled(source.availability == "unavailable")
                    Text(source.availability == "active" ? source.excerpt : L10n.text("chillo.sources.changed"))
                        .font(.subheadline).foregroundStyle(.secondary).textSelection(.enabled)
                    Button(L10n.text("chillo.exclude")) { Task { await store.exclude(source); sheet = nil } }.font(.footnote).disabled(store.generating)
                }.padding(.vertical, 8)
            }.navigationTitle(L10n.text("chillo.sources")).navigationBarTitleDisplayMode(.inline)
        case .library:
            List {
                if let library = store.library {
                    Text(L10n.text("chillo.library.summary", Int64(library.available), Int64(library.total)))
                    Text(L10n.text("chillo.library.index", Int64(library.indexed), Int64(library.available))).foregroundStyle(.secondary)
                }
                Text(L10n.text("chillo.library.scope")).font(.subheadline).foregroundStyle(.secondary)
                Text(L10n.text("chillo.consent.body")).font(.footnote).foregroundStyle(.secondary)
                Button(L10n.text(store.needsConsent ? "chillo.consent.accept" : "chillo.consent.revoke")) {
                    Task { await store.consent(store.needsConsent); sheet = nil }
                }
            }.navigationTitle(L10n.text("chillo.library")).navigationBarTitleDisplayMode(.inline)
        }
    }

    private func openNote(_ id: String) async {
        guard let uuid = UUID(uuidString: id), let userID = authService.currentUserId else { return }
        _ = await syncManager.syncNow(context: modelContext)
        let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == uuid && $0.userId == userID && $0.deletedAt == nil })
        if let found = try? modelContext.fetch(descriptor).first { note = found }
        else { store.error = L10n.text("chillo.note.unavailable") }
    }
}

private struct ChilloAnswerText: View {
    let answer: String
    var body: some View {
        Text(rendered).font(.system(size: 16)).lineSpacing(6).textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    private var rendered: AttributedString {
        AttributedString(ChilloCitationRenderer.render(answer: answer))
    }
}

enum ChilloCitationRenderer {
    static func plainAnswer(_ answer: String) -> String {
        let normalized = answer.replacingOccurrences(
            of: #"\[(\d+)\]\(\s*chillo-source:\/\/\d+\s*\)"#,
            with: "[$1]",
            options: .regularExpression
        )
        return normalized.replacingOccurrences(
            of: #"[ \t]*\[\s*\d+(?:\s*,\s*\d+)*\s*\]"#,
            with: "",
            options: .regularExpression
        )
        .replacingOccurrences(of: #"[ \t]+([,.;:!?])"#, with: "$1", options: .regularExpression)
        .replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func render(answer: String) -> NSAttributedString {
        RichTextConverter.markdownToAttributedString(
            plainAnswer(answer),
            baseFont: .systemFont(ofSize: 16),
            textColor: .black
        )
    }
}

func uniqueChilloSources(_ sources: [ChilloSource]) -> [ChilloSource] {
    var seen = Set<String>()
    return sources.filter { source in
        seen.insert(source.noteId).inserted
    }
}
