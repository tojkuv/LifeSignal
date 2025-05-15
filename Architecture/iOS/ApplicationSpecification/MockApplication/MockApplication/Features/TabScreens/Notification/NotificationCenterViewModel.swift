import Foundation
import SwiftUI
import Combine

/// View model for the notification center
class NotificationCenterViewModel: ObservableObject {
    // MARK: - Published Properties

    /// The notification history
    @Published var notificationHistory: [NotificationEvent] = []

    /// Whether the view model is loading
    @Published var isLoading: Bool = false

    // MARK: - Private Properties

    /// The user defaults key for notification history
    private let notificationHistoryKey = "notificationHistory"

    // MARK: - Initialization

    init() {
        // Load notifications from UserDefaults
        loadNotifications()

        // Subscribe to notification center for new notifications
        subscribeToNotifications()
    }

    // MARK: - Methods

    /// Load notifications from UserDefaults
    func loadNotifications() {
        isLoading = true

        // Generate mock notification history since we can't use Codable with the existing types
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
            ),
            NotificationEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-86400 * 3),
                type: NotificationType.manualAlert,  // Using existing type
                title: "Role Changed",
                body: "You added John Doe as a responder."
            ),
            NotificationEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-86400 * 4),
                type: NotificationType.checkInReminder,  // Using existing type
                title: "Check-in Completed",
                body: "You have successfully checked in."
            )
        ]

        isLoading = false
    }

    /// Save notifications to UserDefaults - simplified to avoid Codable issues
    private func saveNotifications() {
        // We'll just keep notifications in memory for the mock app
        // In a real app, we would use a more robust persistence solution
    }

    /// Subscribe to notification center for new notifications
    private func subscribeToNotifications() {
        // Listen for new notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNewNotification(_:)),
            name: NSNotification.Name("NewNotification"),
            object: nil
        )
    }

    /// Handle a new notification
    /// - Parameter notification: The notification
    @objc private func handleNewNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let title = userInfo["title"] as? String,
              let body = userInfo["body"] as? String,
              let typeString = userInfo["type"] as? String else {
            return
        }

        // Determine the notification type
        var type: NotificationType = .pingNotification  // Default
        if typeString == "Check-in Reminder" {
            type = .checkInReminder
        } else if typeString == "Manual Alert" {
            type = .manualAlert
        } else if typeString == "Ping Notification" {
            type = .pingNotification
        }

        // Create a new notification event
        let newEvent = NotificationEvent(
            id: UUID().uuidString,
            timestamp: Date(),
            type: type,
            title: title,
            body: body
        )

        // Add the new notification to the history
        DispatchQueue.main.async {
            self.notificationHistory.insert(newEvent, at: 0)
            self.saveNotifications()
        }
    }

    /// Clear all notifications
    func clearAllNotifications() {
        notificationHistory = []
        saveNotifications()
    }

    /// Delete specific notifications
    /// - Parameter notifications: The notifications to delete
    func deleteNotifications(_ notifications: [NotificationEvent]) {
        for notification in notifications {
            if let index = notificationHistory.firstIndex(where: { $0.id == notification.id }) {
                notificationHistory.remove(at: index)
            }
        }

        saveNotifications()
    }

    /// Add a new notification
    /// - Parameters:
    ///   - title: The notification title
    ///   - body: The notification body
    ///   - type: The notification type
    func addNotification(title: String, body: String, type: NotificationType) {
        let newEvent = NotificationEvent(
            id: UUID().uuidString,
            timestamp: Date(),
            type: type,
            title: title,
            body: body
        )

        notificationHistory.insert(newEvent, at: 0)
        saveNotifications()
    }
}
