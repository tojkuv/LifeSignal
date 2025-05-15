import Foundation

/// Utility for formatting time and dates
struct TimeFormattingUtility {
    // MARK: - Static Methods
    
    /// Format a time interval for display
    /// - Parameter timeInterval: The time interval in seconds
    /// - Returns: A formatted string representation of the time interval
    static func formatTimeInterval(_ timeInterval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        
        return formatter.string(from: timeInterval) ?? "Unknown"
    }
    
    /// Format a date for display
    /// - Parameter date: The date to format
    /// - Returns: A formatted string representation of the date
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Format an interval in hours for display
    /// - Parameter hours: The interval in hours
    /// - Returns: A formatted string representation of the interval
    static func formatHourInterval(_ hours: Int) -> String {
        let days = hours / 24
        
        if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s")"
        } else {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        }
    }
    
    /// Format a date as time ago
    /// - Parameter date: The date to format
    /// - Returns: A formatted string representation of the time ago
    static func formatTimeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
