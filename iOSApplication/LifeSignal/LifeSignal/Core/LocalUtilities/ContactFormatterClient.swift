import DependenciesMacros
import Foundation
import SwiftUI
import ComposableArchitecture

@DependencyClient
struct ContactFormatterClient {
    var statusDisplay: @Sendable (Contact) -> (String, Color) = { _ in ("", .gray) }
    var lastSeenText: @Sendable (Date) -> String = { _ in "" }
    var intervalText: @Sendable (TimeInterval) -> String = { _ in "" }
    var contactRoleText: @Sendable (Contact) -> String = { _ in "" }
    var contactActivityStatus: @Sendable (Contact) -> (String, Color) = { _ in ("Unknown", .gray) }
}

extension ContactFormatterClient: DependencyKey {
    static let liveValue = ContactFormatterClient(
        statusDisplay: { contact in
            // Determine status based on contact's current state
            if contact.manualAlertActive {
                return ("Alert Active", .red)
            } else if contact.hasIncomingPing {
                return ("Incoming Ping", .orange)
            } else if contact.hasOutgoingPing {
                return ("Outgoing Ping", .blue)
            } else if let lastCheckIn = contact.lastCheckInTime {
                let timeSinceCheckIn = Date().timeIntervalSince(lastCheckIn)
                if timeSinceCheckIn < contact.interval {
                    return ("Active", .green)
                } else if timeSinceCheckIn < contact.interval * 2 {
                    return ("Overdue", .yellow)
                } else {
                    return ("Unresponsive", .red)
                }
            } else {
                return ("No Check-in", .gray)
            }
        },
        
        lastSeenText: { date in
            let now = Date()
            let interval = now.timeIntervalSince(date)
            
            if interval < 60 {
                return "Just now"
            } else if interval < 3600 {
                let minutes = Int(interval / 60)
                return "\(minutes)m ago"
            } else if interval < 86400 {
                let hours = Int(interval / 3600)
                return "\(hours)h ago"
            } else if interval < 604800 { // 7 days
                let days = Int(interval / 86400)
                return "\(days)d ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                return formatter.string(from: date)
            }
        },
        
        intervalText: { interval in
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
        
        contactRoleText: { contact in
            if contact.isResponder && contact.isDependent {
                return "Responder & Dependent"
            } else if contact.isResponder {
                return "Responder"
            } else if contact.isDependent {
                return "Dependent"
            } else {
                return "Contact"
            }
        },
        
        contactActivityStatus: { contact in
            // More detailed activity status
            let now = Date()
            
            // Check for active alerts first
            if contact.manualAlertActive {
                if let alertTime = contact.manualAlertTimestamp {
                    let timeSinceAlert = now.timeIntervalSince(alertTime)
                    if timeSinceAlert < 300 { // 5 minutes
                        return ("🚨 Alert (Just Now)", .red)
                    } else if timeSinceAlert < 3600 { // 1 hour
                        let minutes = Int(timeSinceAlert / 60)
                        return ("🚨 Alert (\(minutes)m ago)", .red)
                    } else {
                        return ("🚨 Alert Active", .red)
                    }
                } else {
                    return ("🚨 Alert Active", .red)
                }
            }
            
            // Check for pings
            if contact.hasIncomingPing {
                if let pingTime = contact.incomingPingTimestamp {
                    let timeSincePing = now.timeIntervalSince(pingTime)
                    if timeSincePing < 300 { // 5 minutes
                        return ("📥 Pinged (Just Now)", .orange)
                    } else {
                        let minutes = Int(timeSincePing / 60)
                        return ("📥 Pinged (\(minutes)m ago)", .orange)
                    }
                } else {
                    return ("📥 Incoming Ping", .orange)
                }
            }
            
            if contact.hasOutgoingPing {
                if let pingTime = contact.outgoingPingTimestamp {
                    let timeSincePing = now.timeIntervalSince(pingTime)
                    if timeSincePing < 300 { // 5 minutes
                        return ("📤 Sent Ping (Just Now)", .blue)
                    } else {
                        let minutes = Int(timeSincePing / 60)
                        return ("📤 Sent Ping (\(minutes)m ago)", .blue)
                    }
                } else {
                    return ("📤 Outgoing Ping", .blue)
                }
            }
            
            // Check check-in status
            if let lastCheckIn = contact.lastCheckInTime {
                let timeSinceCheckIn = now.timeIntervalSince(lastCheckIn)
                let overdueFactor = timeSinceCheckIn / contact.interval
                
                if overdueFactor < 0.5 {
                    return ("✅ Recently Active", .green)
                } else if overdueFactor < 1.0 {
                    return ("⏰ Active", .green)
                } else if overdueFactor < 1.5 {
                    return ("⚠️ Overdue", .yellow)
                } else if overdueFactor < 2.0 {
                    return ("❗ Late Check-in", .orange)
                } else {
                    return ("❌ Unresponsive", .red)
                }
            } else {
                return ("❓ No Check-in", .gray)
            }
        }
    )
    
    static let testValue = ContactFormatterClient(
        statusDisplay: { _ in ("Mock Status", .gray) },
        lastSeenText: { _ in "Mock Time" },
        intervalText: { _ in "Mock Interval" },
        contactRoleText: { _ in "Mock Role" },
        contactActivityStatus: { _ in ("Mock Activity", .gray) }
    )
}

extension DependencyValues {
    var contactFormatterClient: ContactFormatterClient {
        get { self[ContactFormatterClient.self] }
        set { self[ContactFormatterClient.self] = newValue }
    }
}
