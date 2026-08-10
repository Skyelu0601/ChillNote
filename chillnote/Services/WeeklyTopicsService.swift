import Foundation

enum WeeklyTopicsServiceError: Error {
    case invalidURL
    case unauthorized
    case notFound
    case conflict
    case server
}

struct WeeklyTopicsService {
    func dashboard(token: String) async throws -> WeeklyTopicDashboard {
        try await request(path: "/weekly-topics/dashboard", token: token)
    }

    func updateSettings(
        _ payload: WeeklyTopicSettingsPayload,
        token: String
    ) async throws -> WeeklyTopicSettings {
        try await request(
            path: "/weekly-topics/settings",
            method: "PUT",
            token: token,
            body: payload
        )
    }

    func reports(token: String) async throws -> [WeeklyTopicReport] {
        let response: WeeklyTopicReportsResponse = try await request(
            path: "/weekly-topics/reports",
            token: token
        )
        return response.reports
    }

    func report(id: String, token: String) async throws -> WeeklyTopicReport {
        try await request(path: "/weekly-topics/reports/\(id)", token: token)
    }

    func markRead(id: String, token: String) async throws {
        try await requestWithoutResponse(
            path: "/weekly-topics/reports/\(id)/read",
            method: "POST",
            token: token
        )
    }

    func regenerate(id: String, token: String) async throws -> WeeklyTopicReport {
        try await request(
            path: "/weekly-topics/reports/\(id)/regenerate",
            method: "POST",
            token: token
        )
    }

    private func request<Response: Decodable>(
        path: String,
        method: String = "GET",
        token: String,
        body: (any Encodable)? = nil
    ) async throws -> Response {
        let request = try makeRequest(path: path, method: method, token: token, body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return try Self.decoder.decode(Response.self, from: data)
    }

    private func requestWithoutResponse(
        path: String,
        method: String,
        token: String
    ) async throws {
        let request = try makeRequest(path: path, method: method, token: token, body: nil)
        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response)
    }

    private func makeRequest(
        path: String,
        method: String,
        token: String,
        body: (any Encodable)?
    ) throws -> URLRequest {
        guard let url = URL(string: AppConfig.backendBaseURL + path) else {
            throw WeeklyTopicsServiceError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try Self.encoder.encode(AnyEncodable(body))
        }
        return request
    }

    private func validate(_ response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse else {
            throw WeeklyTopicsServiceError.server
        }
        switch response.statusCode {
        case 200..<300:
            return
        case 401, 403:
            throw WeeklyTopicsServiceError.unauthorized
        case 404:
            throw WeeklyTopicsServiceError.notFound
        case 409:
            throw WeeklyTopicsServiceError.conflict
        default:
            throw WeeklyTopicsServiceError.server
        }
    }

    private static let encoder = JSONEncoder()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = fractionalDateFormatter.date(from: value)
                ?? standardDateFormatter.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO-8601 date"
            )
        }
        return decoder
    }()

    private static let fractionalDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let standardDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void

    init(_ value: any Encodable) {
        encodeValue = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeValue(encoder)
    }
}

@MainActor
final class WeeklyTopicsStore: ObservableObject {
    @Published private(set) var dashboard: WeeklyTopicDashboard?
    @Published private(set) var reports: [WeeklyTopicReport] = []
    @Published private(set) var loadedReports: [String: WeeklyTopicReport] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var isRegenerating = false
    @Published var errorMessage: String?

    private let service: WeeklyTopicsService

    init(service: WeeklyTopicsService = WeeklyTopicsService()) {
        self.service = service
    }

    var hasUnreadReport: Bool {
        dashboard?.hasUnreadReport == true
    }

    func reload() async {
        guard let token = await AuthService.shared.getSessionToken(), !token.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            dashboard = try await service.dashboard(token: token)
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = L10n.text("weekly_topics.error.load")
        }
    }

    func loadHistory() async {
        guard let token = await AuthService.shared.getSessionToken(), !token.isEmpty else { return }
        do {
            reports = try await service.reports(token: token)
            for report in reports {
                loadedReports[report.id] = report
            }
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = L10n.text("weekly_topics.error.load")
        }
    }

    func loadReport(id: String) async -> WeeklyTopicReport? {
        if let report = loadedReports[id] { return report }
        guard let token = await AuthService.shared.getSessionToken(), !token.isEmpty else { return nil }
        do {
            let report = try await service.report(id: id, token: token)
            loadedReports[id] = report
            return report
        } catch is CancellationError {
            return nil
        } catch {
            errorMessage = L10n.text("weekly_topics.error.load")
            return nil
        }
    }

    func saveSettings(
        enabled: Bool,
        weekday: Int,
        hour: Int,
        minute: Int
    ) async -> Bool {
        guard let token = await AuthService.shared.getSessionToken(), !token.isEmpty else { return false }
        isSaving = true
        defer { isSaving = false }
        let payload = WeeklyTopicSettingsPayload(
            enabled: enabled,
            weekday: weekday,
            hour: hour,
            minute: minute,
            timeZone: TimeZone.current.identifier,
            locale: Locale.current.identifier
        )
        do {
            let settings = try await service.updateSettings(payload, token: token)
            if var dashboard {
                dashboard.settings = settings
                self.dashboard = dashboard
            } else {
                await reload()
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = L10n.text("weekly_topics.error.save")
            return false
        }
    }

    func markRead(_ report: WeeklyTopicReport) async {
        guard report.isUnread,
              let token = await AuthService.shared.getSessionToken(), !token.isEmpty else { return }
        do {
            try await service.markRead(id: report.id, token: token)
            var updated = report
            updated.readAt = Date()
            loadedReports[report.id] = updated
            if var dashboard, dashboard.latestReport?.id == report.id {
                dashboard.latestReport = updated
                dashboard.hasUnreadReport = false
                self.dashboard = dashboard
            }
        } catch {
            // Reading the report should never be interrupted by a failed receipt.
        }
    }

    func regenerate(_ report: WeeklyTopicReport) async -> WeeklyTopicReport? {
        guard report.canRegenerate,
              let token = await AuthService.shared.getSessionToken(), !token.isEmpty else { return nil }
        isRegenerating = true
        defer { isRegenerating = false }
        do {
            let updated = try await service.regenerate(id: report.id, token: token)
            loadedReports[report.id] = updated
            if var dashboard, dashboard.latestReport?.id == report.id {
                dashboard.latestReport = updated
                dashboard.hasUnreadReport = true
                self.dashboard = dashboard
            }
            if let index = reports.firstIndex(where: { $0.id == report.id }) {
                reports[index] = updated
            }
            errorMessage = nil
            return updated
        } catch {
            errorMessage = L10n.text("weekly_topics.error.regenerate")
            return nil
        }
    }
}
