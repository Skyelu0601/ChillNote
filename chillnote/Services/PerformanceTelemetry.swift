import Foundation
import OSLog

enum PerformanceTelemetry {
    private static let logger = Logger(subsystem: "com.chillnote.app", category: "performance")

    @discardableResult
    static func begin(_ event: String) -> Date {
        Date()
    }

    static func end(_ event: String, from start: Date, extra: String = "") {
        let elapsedMs = Int(Date().timeIntervalSince(start) * 1000)
        if extra.isEmpty {
            logger.log("\(event, privacy: .public): \(elapsedMs, privacy: .public)ms")
        } else {
            logger.log("\(event, privacy: .public): \(elapsedMs, privacy: .public)ms \(extra, privacy: .public)")
        }
    }

    static func mark(_ event: String, detail: String = "") {
        if detail.isEmpty {
            logger.log("\(event, privacy: .public)")
        } else {
            logger.log("\(event, privacy: .public): \(detail, privacy: .public)")
        }
    }
}
