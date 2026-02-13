import Foundation

extension Date {
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    private static let sameYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d HH:mm"
        return formatter
    }()

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()

    /// Returns a human-friendly relative time string
    /// - Today: "14:30"
    /// - Yesterday: "Yesterday 14:30"
    /// - This week (2-6 days ago): "Monday 14:30"
    /// - Within a year: "Jan 10 14:30"
    /// - Over a year ago: "2025/01/10"
    func relativeFormatted() -> String {
        let calendar = Calendar.current
        let now = Date()
        
        // Check if it's today
        if calendar.isDateInToday(self) {
            return Self.timeFormatter.string(from: self)
        }
        
        // Check if it's yesterday
        if calendar.isDateInYesterday(self) {
            return "Yesterday \(Self.timeFormatter.string(from: self))"
        }
        
        // Check if it's within the last 6 days (this week)
        let daysDifference = calendar.dateComponents([.day], from: self, to: now).day ?? 0
        if daysDifference <= 6 {
            return "\(Self.weekdayFormatter.string(from: self)) \(Self.timeFormatter.string(from: self))"
        }
        
        // Check if it's within the same year
        let yearsDifference = calendar.dateComponents([.year], from: self, to: now).year ?? 0
        if yearsDifference == 0 {
            return Self.sameYearFormatter.string(from: self)
        }
        
        // Over a year ago - show full date
        return Self.fullDateFormatter.string(from: self)
    }
}
