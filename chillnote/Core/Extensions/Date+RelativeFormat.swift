import Foundation

extension Date {
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
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            return timeFormatter.string(from: self)
        }
        
        // Check if it's yesterday
        if calendar.isDateInYesterday(self) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            return "Yesterday \(timeFormatter.string(from: self))"
        }
        
        // Check if it's within the last 6 days (this week)
        let daysDifference = calendar.dateComponents([.day], from: self, to: now).day ?? 0
        if daysDifference <= 6 {
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEEE" // Full weekday name
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            return "\(weekdayFormatter.string(from: self)) \(timeFormatter.string(from: self))"
        }
        
        // Check if it's within the same year
        let yearsDifference = calendar.dateComponents([.year], from: self, to: now).year ?? 0
        if yearsDifference == 0 {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d HH:mm"
            return dateFormatter.string(from: self)
        }
        
        // Over a year ago - show full date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        return dateFormatter.string(from: self)
    }
}
