import Foundation

enum WeeklyTopicSourceAvailability: String, Codable, Hashable {
    case active
    case trashed
    case deleted
}

struct WeeklyTopicSettings: Codable, Equatable {
    var enabled: Bool
    var weekday: Int
    var hour: Int
    var minute: Int
    var timeZone: String
    var locale: String
    var lastPeriodEnd: Date?
    var nextRunAt: Date?
}

struct WeeklyTopicSource: Codable, Identifiable, Hashable {
    var id: String { noteId }

    let noteId: String
    let noteTitle: String
    let platformName: String?
    let excerpt: String
    var availability: WeeklyTopicSourceAvailability? = nil

    var resolvedAvailability: WeeklyTopicSourceAvailability {
        availability ?? .active
    }
}

struct WeeklyTopicItem: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let sources: [WeeklyTopicSource]
}

struct WeeklyTopicReport: Codable, Identifiable, Hashable {
    let id: String
    let periodStart: Date
    let periodEnd: Date
    let sourceNoteCount: Int
    let language: String
    let topics: [WeeklyTopicItem]
    var readAt: Date?
    let regenerationCount: Int
    let createdAt: Date

    var isUnread: Bool { readAt == nil }
    var canRegenerate: Bool { regenerationCount < 1 }
}

struct WeeklyTopicDashboard: Codable {
    var settings: WeeklyTopicSettings
    var latestReport: WeeklyTopicReport?
    var hasUnreadReport: Bool
    let currentSourceCount: Int
    let minimumSourceCount: Int
}

struct WeeklyTopicReportsResponse: Codable {
    let reports: [WeeklyTopicReport]
}

struct WeeklyTopicSettingsPayload: Encodable {
    let enabled: Bool
    let weekday: Int
    let hour: Int
    let minute: Int
    let timeZone: String
    let locale: String
}

enum WeeklyTopicsRoute: Hashable {
    case dashboard
}
