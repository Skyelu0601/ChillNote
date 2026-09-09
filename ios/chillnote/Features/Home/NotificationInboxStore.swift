import Foundation
import Combine

struct InboxNotification: Decodable, Identifiable {
    let id: String
    let kind: String
    let amount: Int?
    let createdAt: String
    var readAt: String?

    var isSupported: Bool {
        kind == "welcome_pro" || (kind == "welcome_credits" && (amount ?? 0) > 0)
    }
    var date: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: createdAt) ?? ISO8601DateFormatter().date(from: createdAt)
    }
}

@MainActor
final class NotificationInboxStore: ObservableObject {
    @Published private(set) var items: [InboxNotification] = []
    @Published private(set) var isLoading = false
    @Published private(set) var failed = false
    private var accountID: String?
    private var revision = 0
    private var acknowledged = Set<String>()
    private var marking = Set<String>()
    var hasUnread: Bool { items.contains { $0.readAt == nil } }

    func reload() async {
        let userID = AuthService.shared.currentUserId
        if accountID != userID {
            accountID = userID
            items = []
            acknowledged = []
            marking = []
        }
        if StoreService.shared.currentTier == .pro {
            items.removeAll { $0.kind == "welcome_credits" }
        }
        revision += 1
        let requestRevision = revision
        failed = false
        guard let userID else { isLoading = false; return }
        isLoading = true
        do {
            let request = try await request(path: "/notifications")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let result = try JSONDecoder().decode(InboxResponse.self, from: data)
            guard requestRevision == revision, AuthService.shared.currentUserId == userID else { return }
            items = result.notifications.filter {
                $0.isSupported && !(StoreService.shared.currentTier == .pro && $0.kind == "welcome_credits")
            }.map { item in
                var item = item
                if acknowledged.contains(item.id) { item.readAt = item.readAt ?? "read" }
                return item
            }
            isLoading = false
        } catch {
            guard requestRevision == revision, AuthService.shared.currentUserId == userID else { return }
            isLoading = false
            failed = true
        }
    }

    func markRead(_ id: String) async {
        guard let userID = accountID, userID == AuthService.shared.currentUserId,
              items.contains(where: { $0.id == id && $0.readAt == nil }), !marking.contains(id) else { return }
        marking.insert(id)
        defer { marking.remove(id) }
        do {
            var request = try await request(path: "/notifications/read")
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(ReadRequest(ids: [id]))
            let (_, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            guard accountID == userID, AuthService.shared.currentUserId == userID else { return }
            acknowledged.insert(id)
            if let index = items.firstIndex(where: { $0.id == id }) { items[index].readAt = "read" }
        } catch {
            if accountID == userID, AuthService.shared.currentUserId == userID { failed = true }
        }
    }

    private func request(path: String) async throws -> URLRequest {
        guard let token = await AuthService.shared.getSessionToken(), !token.isEmpty else { throw URLError(.userAuthenticationRequired) }
        var request = URLRequest(url: URL(string: AppConfig.backendBaseURL + path)!)
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
    private struct InboxResponse: Decodable { let notifications: [InboxNotification] }
    private struct ReadRequest: Encodable { let ids: [String] }
}
