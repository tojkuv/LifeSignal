import Foundation

// MARK: - Domain Model

enum Notification: String, Codable, CaseIterable, Identifiable, Sendable {
    case checkIn = "Check-in"
    case sos = "SOS"
    case contactRequest = "Contact Request"
    case system = "System"

    // Legacy cases for migration
    case checkInReminder = "Check-in Reminder"
    case manualAlert = "Manual Alert"
    case alert = "Alert"
    case nonResponsive = "Non-Responsive Contact"
    case pingNotification = "Ping Notification"
    case contactAdded = "Contact Added"
    case contactRemoved = "Contact Removed"
    case contactRoleChanged = "Contact Role Changed"
    case qrCodeNotification = "QR Code Notification"

    // Additional cases used in CheckInFeature
    case emergencyAlert = "Emergency Alert"
    case alertCancelled = "Alert Cancelled"

    /// The notification ID
    var id: String { self.rawValue }
}
