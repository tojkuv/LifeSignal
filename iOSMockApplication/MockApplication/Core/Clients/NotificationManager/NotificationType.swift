import Foundation
import SwiftUI
import Combine

/// Notification types
enum NotificationType: String, CaseIterable, Identifiable {
    /// A check-in reminder
    case checkInReminder = "Check-in Reminder"

    /// A manual alert
    case manualAlert = "Manual Alert"

    /// A non-responsive contact notification
    case nonResponsive = "Non-Responsive Contact"

    /// A ping notification
    case pingNotification = "Ping Notification"

    /// A contact added notification
    case contactAdded = "Contact Added"

    /// A contact removed notification
    case contactRemoved = "Contact Removed"

    /// A contact role changed notification
    case contactRoleChanged = "Contact Role Changed"

    /// A QR code notification
    case qrCodeNotification = "QR Code Notification"

    /// The notification ID
    var id: String { self.rawValue }
}
