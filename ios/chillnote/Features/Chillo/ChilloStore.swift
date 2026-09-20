import Foundation

struct ChilloSource: Decodable, Identifiable {
    let number: Int
    let noteId: String
    let availability: String
    let title: String
    let excerpt: String
    let platform: String?
    var id: Int { number }
}

struct ChilloTurn: Decodable, Identifiable {
    let id: String
    let request: String
    let answer: String
    let status: String
    let errorCode: String?
    let sources: [ChilloSource]
    let sourcesChanged: Bool
    let draftNoteId: String?
    var isActive: Bool { status == "queued" || status == "running" }
}

struct ChilloConversation: Decodable, Identifiable {
    let id: String
    let title: String
}

struct ChilloDetail: Decodable {
    let id: String
    let turns: [ChilloTurn]
    let pinnedIds: [String]
    let excludedIds: [String]
    let olderCursor: String?
}

struct ChilloLibrary: Decodable {
    let total: Int
    let available: Int
    let indexed: Int
    let pending: Int
    let consentVersion: Int
}

struct ChilloService {
    struct Failure: Error { let code: String }
    func request<T: Decodable>(_ path: String, method: String = "GET", body: [String: Any]? = nil) async throws -> T {
        guard let token = await AuthService.shared.getSessionToken(), !token.isEmpty,
              let url = URL(string: AppConfig.backendBaseURL + "/chillo" + path) else { throw Failure(code: "UNAUTHORIZED") }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            let error = (try? JSONSerialization.jsonObject(with: data)) as? [String: String]
            throw Failure(code: error?["error"] ?? "REQUEST_FAILED")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

@MainActor
final class ChilloStore: ObservableObject {
    @Published private(set) var conversationID: String?
    @Published private(set) var turns: [ChilloTurn] = []
    @Published private(set) var history: [ChilloConversation] = []
    @Published private(set) var library: ChilloLibrary?
    @Published private(set) var busy = false
    @Published private(set) var loading = false
    @Published var error: String?
    @Published var input = ""
    @Published private(set) var olderCursor: String?
    @Published private(set) var historyCursor: String?
    private var pinnedIds: [String] = []
    private var excludedIds: [String] = []
    // Keep a failed/ambiguous submission's ID so a network retry cannot create another turn.
    private var pendingSubmission: (id: String, message: String)?
    private let service = ChilloService()
    var generating: Bool { turns.contains(where: \.isActive) }
    var needsConsent: Bool { library?.consentVersion != 1 }
    private struct OK: Decodable { }
    private struct History: Decodable { let conversations: [ChilloConversation]; let nextCursor: String? }
    private struct Draft: Decodable { let noteId: String }

    func load() async {
        loading = true
        defer { loading = false }
        await perform {
            self.library = try await self.service.request("/library")
            try await self.refreshHistory()
        }
    }

    func consent(_ accepted: Bool) async {
        await perform {
            let _: OK = try await self.service.request("/consent", method: "PUT", body: ["version": accepted ? 1 : 0])
            self.library = try await self.service.request("/library")
            if !accepted { try await self.refresh() }
        }
    }

    func newConversation() {
        guard !busy else { return }
        conversationID = nil; turns = []; input = ""; pinnedIds = []; excludedIds = []
        pendingSubmission = nil; olderCursor = nil; error = nil
    }

    func open(_ id: String) async {
        guard !busy else { return }
        await perform {
            let detail: ChilloDetail = try await self.service.request("/conversations/\(id)")
            self.conversationID = id; self.turns = detail.turns; self.olderCursor = detail.olderCursor
            self.pinnedIds = detail.pinnedIds; self.excludedIds = detail.excludedIds
            self.input = ""; self.pendingSubmission = nil
        }
    }

    func send() async {
        guard !busy, !generating, !needsConsent else { return }
        let message = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, message.count <= 16000 else { return }
        busy = true
        defer { busy = false }
        await perform {
            if self.conversationID == nil { self.conversationID = UUID().uuidString.lowercased() }
            let conversationID = self.conversationID!
            let _: ChilloConversation = try await self.service.request("/conversations", method: "POST", body: ["id": conversationID])
            if self.pendingSubmission?.message != message { self.pendingSubmission = (UUID().uuidString.lowercased(), message) }
            let turn: ChilloTurn = try await self.service.request("/conversations/\(conversationID)/turns", method: "POST", body: ["id": self.pendingSubmission!.id, "message": message, "locale": L10n.contentLocaleIdentifier])
            if !self.turns.contains(where: { $0.id == turn.id }) { self.turns.append(turn) }
            self.input = ""; self.pendingSubmission = nil
            try await self.refreshHistory()
        }
    }

    func poll() async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(2))
                if generating && !busy { try await refresh() }
            } catch is CancellationError { return }
            catch { self.error = L10n.text("chillo.error.connection") }
        }
    }

    func reload() async { await perform { try await self.refresh() } }

    private func refresh() async throws {
        guard let id = conversationID else { return }
        let detail: ChilloDetail = try await service.request("/conversations/\(id)")
        guard conversationID == id else { return }
        // Preserve already paged-in history while replacing the latest turn states.
        let ids = Set(detail.turns.map(\.id))
        turns = turns.filter { !ids.contains($0.id) } + detail.turns
        if turns.count <= 40 { olderCursor = detail.olderCursor }
        error = nil
    }

    func loadOlder() async {
        guard let id = conversationID, let cursor = olderCursor else { return }
        await perform {
            let detail: ChilloDetail = try await self.service.request("/conversations/\(id)?cursor=\(cursor)")
            guard self.conversationID == id else { return }
            let ids = Set(self.turns.map(\.id))
            self.turns = detail.turns.filter { !ids.contains($0.id) } + self.turns
            self.olderCursor = detail.olderCursor
        }
    }

    func moreHistory() async { await perform { try await self.refreshHistory(more: true) } }
    private func refreshHistory(more: Bool = false) async throws {
        let suffix = more ? historyCursor.map { "?cursor=\($0)" } ?? "" : ""
        let result: History = try await service.request("/conversations" + suffix)
        history = more ? history + result.conversations.filter { item in !history.contains(where: { $0.id == item.id }) } : result.conversations
        historyCursor = result.nextCursor
    }

    func remove(_ id: String) async {
        await perform {
            let _: OK = try await self.service.request("/conversations/\(id)", method: "DELETE")
            self.history.removeAll { $0.id == id }
            if self.conversationID == id { self.newConversation() }
        }
    }

    func action(_ action: String, turn: ChilloTurn) async -> String? {
        guard let id = conversationID, !busy else { return nil }
        busy = true; defer { busy = false }
        var noteID: String?
        await perform {
            let path = "/conversations/\(id)/turns/\(turn.id)/\(action)"
            if action == "draft" {
                let result: Draft = try await self.service.request(path, method: "POST")
                noteID = result.noteId
            } else { let _: OK = try await self.service.request(path, method: "POST") }
            try await self.refresh()
        }
        return noteID
    }

    func exclude(_ source: ChilloSource) async {
        guard let id = conversationID, !generating else { return }
        await perform {
            let updated = Array(Set(self.excludedIds + [source.noteId]))
            let _: OK = try await self.service.request("/conversations/\(id)", method: "PATCH", body: ["pinnedIds": self.pinnedIds.filter { $0 != source.noteId }, "excludedIds": updated])
            self.excludedIds = updated
        }
    }

    private func perform(_ action: () async throws -> Void) async {
        do { try await action(); error = nil }
        catch is CancellationError { }
        catch let failure as ChilloService.Failure { error = Self.errorText(failure.code) }
        catch { self.error = L10n.text("chillo.error.connection") }
    }

    static func errorText(_ code: String?) -> String {
        switch code {
        case "CONSENT_REQUIRED": return L10n.text("chillo.consent.body")
        case "INSUFFICIENT_CREDITS": return L10n.text("chillo.error.credits")
        case "BUSY": return L10n.text("chillo.working")
        case "SOURCES_CHANGED": return L10n.text("chillo.sources.changed")
        case "DRAFT_DELETED": return L10n.text("chillo.draft.deleted")
        default: return L10n.text("chillo.error.connection")
        }
    }
}
