import Foundation
import SwiftUI
import Combine

/// View model for the notification feature
class NotificationViewModel: ObservableObject {
    // MARK: - Published Properties

    /// The user view model
    private var userViewModel: UserViewModel

    /// Whether notifications are enabled
    @Published var notificationsEnabled: Bool = true

    /// Whether to notify 30 minutes before check-in expiration
    @Published var notify30MinBefore: Bool = true

    /// Whether to notify 2 hours before check-in expiration
    @Published var notify2HoursBefore: Bool = false

    /// The notification history
    @Published var notificationHistory: [NotificationEvent] = []

    /// Whether settings are being updated
    @Published var isUpdating: Bool = false

    // MARK: - Initialization

    init(userViewModel: UserViewModel = UserViewModel()) {
        self.userViewModel = userViewModel
        self.notificationsEnabled = userViewModel.notificationsEnabled
        self.notify30MinBefore = userViewModel.notify30MinBefore
        self.notify2HoursBefore = userViewModel.notify2HoursBefore

        // Generate mock notification history
        notificationHistory = [
            NotificationEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-3600),
                type: .checkInReminder,
                title: "Check-in Reminder",
                body: "Your check-in will expire in 30 minutes."
            ),
            NotificationEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-86400),
                type: .manualAlert,
                title: "Manual Alert",
                body: "Jane Smith has triggered a manual alert."
            ),
            NotificationEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-86400 * 2),
                type: .pingNotification,
                title: "Ping Received",
                body: "Bob Johnson has pinged you."
            )
        ]
    }

    // MARK: - Methods

    /// Toggle notifications enabled
    func toggleNotificationsEnabled() {
        isUpdating = true

        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.notificationsEnabled.toggle()
            self.userViewModel.notificationsEnabled = self.notificationsEnabled
            self.isUpdating = false
        }
    }

    /// Toggle 30-minute reminder
    func toggle30MinReminder() {
        isUpdating = true

        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.notify30MinBefore.toggle()
            self.userViewModel.notify30MinBefore = self.notify30MinBefore
            self.isUpdating = false
        }
    }

    /// Toggle 2-hour reminder
    func toggle2HourReminder() {
        isUpdating = true

        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.notify2HoursBefore.toggle()
            self.userViewModel.notify2HoursBefore = self.notify2HoursBefore
            self.isUpdating = false
        }
    }

    /// Update the user view model
    /// - Parameter userViewModel: The user view model
    func updateUserViewModel(_ userViewModel: UserViewModel) {
        self.userViewModel = userViewModel
        self.notificationsEnabled = userViewModel.notificationsEnabled
        self.notify30MinBefore = userViewModel.notify30MinBefore
        self.notify2HoursBefore = userViewModel.notify2HoursBefore
    }
}

/// A notification event
struct NotificationEvent: Identifiable, Equatable {
    /// The notification ID
    var id: String

    /// The notification timestamp
    var timestamp: Date

    /// The notification type
    var type: NotificationType

    /// The notification title
    var title: String

    /// The notification body
    var body: String
}

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
