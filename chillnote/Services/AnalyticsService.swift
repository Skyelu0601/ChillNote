import Foundation

enum AnalyticsEvent: String {
    case recordStart = "record_start"
    case recordEnd = "record_end"
    case transcribeSuccess = "transcribe_success"
    case transcribeFail = "transcribe_fail"
    case aiActionUsed = "ai_action_used"
    case reviewGenerated = "review_generated"
}

final class AnalyticsService {
    static let shared = AnalyticsService()
    private let storageKey = "analytics_events"
    private let maxEvents = 200
    
    private init() {}
    
    func log(_ event: AnalyticsEvent, properties: [String: String] = [:]) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        var payload = "event=\(event.rawValue)|time=\(timestamp)"
        if !properties.isEmpty {
            let props = properties.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
            payload += "|props=\(props)"
        }
        
        var events = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        events.append(payload)
        if events.count > maxEvents {
            events = Array(events.suffix(maxEvents))
        }
        UserDefaults.standard.set(events, forKey: storageKey)
    }
}
