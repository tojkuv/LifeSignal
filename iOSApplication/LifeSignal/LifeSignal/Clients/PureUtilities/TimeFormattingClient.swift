import Foundation
import Dependencies
import DependenciesMacros

// MARK: - Time Formatting Client

@LifeSignalClient
@DependencyClient
struct TimeFormattingClient {
    var formatTimeAgo: @Sendable (_ timeInterval: TimeInterval) -> String = { _ in "" }
    var formatTimeRemaining: @Sendable (_ timeInterval: TimeInterval) -> String = { _ in "" }
    var formatIntervalText: @Sendable (_ timeInterval: TimeInterval) -> String = { _ in "" }
    var formatLastSeenText: @Sendable (_ date: Date) -> String = { _ in "" }
}

// MARK: - Live Implementation

extension TimeFormattingClient: DependencyKey {
    static let liveValue: TimeFormattingClient = Self(
        formatTimeAgo: { timeInterval in
            let days = Int(timeInterval) / 86400
            let hours = Int(timeInterval) % 86400 / 3600
            let minutes = Int(timeInterval) % 3600 / 60
            
            if days > 0 {
                if hours > 0 {
                    return "\(days)d \(hours)h ago"
                } else {
                    return "\(days)d ago"
                }
            } else if hours > 0 {
                if minutes > 0 {
                    return "\(hours)h \(minutes)m ago"
                } else {
                    return "\(hours)h ago"
                }
            } else {
                return "\(minutes)m ago"
            }
        },
        
        formatTimeRemaining: { timeInterval in
            let days = Int(timeInterval) / 86400
            let hours = Int(timeInterval) % 86400 / 3600
            let minutes = Int(timeInterval) % 3600 / 60
            
            if days > 0 {
                if hours > 0 {
                    return "\(days)d \(hours)h"
                } else {
                    return "\(days)d"
                }
            } else if hours > 0 {
                if minutes > 0 {
                    return "\(hours)h \(minutes)m"
                } else {
                    return "\(hours)h"
                }
            } else {
                return "\(minutes)m"
            }
        },
        
        formatIntervalText: { interval in
            let hours = Int(interval / 3600)
            let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

            if hours > 0 && minutes > 0 {
                return "\(hours)h \(minutes)m"
            } else if hours > 0 {
                return "\(hours)h"
            } else if minutes > 0 {
                return "\(minutes)m"
            } else {
                return "< 1m"
            }
        },
        
        formatLastSeenText: { date in
            let now = Date()
            let interval = now.timeIntervalSince(date)

            if interval < 60 {
                return "just now"
            } else if interval < 3600 {
                let minutes = Int(interval / 60)
                return "\(minutes)m ago"
            } else if interval < 86400 {
                let hours = Int(interval / 3600)
                return "\(hours)h ago"
            } else if interval < 2505600 { // 29 days in seconds (29 * 24 * 60 * 60)
                let days = Int(interval / 86400)
                return "\(days)d ago"
            } else {
                return "long ago"
            }
        }
    )
}

// MARK: - Test Implementation

extension TimeFormattingClient {
    static let testValue: TimeFormattingClient = Self(
        formatTimeAgo: { timeInterval in
            return "Mock time ago"
        },
        formatTimeRemaining: { timeInterval in
            return "Mock remaining"
        },
        formatIntervalText: { interval in
            return "Mock interval"
        },
        formatLastSeenText: { date in
            return "Mock last seen"
        }
    )
}

// MARK: - Dependency Values Extension

extension DependencyValues {
    var timeFormattingClient: TimeFormattingClient {
        get { self[TimeFormattingClient.self] }
        set { self[TimeFormattingClient.self] = newValue }
    }
}