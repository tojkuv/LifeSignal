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

    /// The currently selected filter
    @Published var selectedFilter: NotificationType? = nil

    /// Filtered notifications based on the selected filter
    var filteredNotifications: [NotificationEvent] {
        guard let filter = selectedFilter else {
            return notificationHistory
        }

        // Special case for Alerts filter - include both manual alerts and non-responsive notifications
        if filter == .manualAlert {
            return notificationHistory.filter { $0.type == .manualAlert || $0.type == .nonResponsive }
        }

        return notificationHistory.filter { $0.type == filter }
    }

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

        // Generate mock notification history with more diverse and realistic scenarios
        notificationHistory = [
            // Contact operations
            NotificationEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-3600), // 1 hour ago
                type: .contactAdded,
                title: "Contact Added",
                body: "You added Alex Johnson as a contact."
            ),
            NotificationEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-10800), // 3 hours ago
                type: .contactRemoved,
                title: "Contact Removed",
                body: "You removed Maria Garcia from your contacts."
            ),
            NotificationEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-18000), // 5 hours ago
                type: .contactRoleChanged,
                title: "Role Changed",
                body: "You changed James Wilson from responder to dependent."
            ),

            // Check-in reminders
            NotificationEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-1800), // 30 minutes ago
                type: .checkInReminder,
                title: "Check-in Reminder",
                body: "Your check-in will expire in 30 minutes."
            ),
            NotificationEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-7200), // 2 hours ago
                type: .checkInReminder,
                title: "Check-in Reminder",
                body: "Your check-in will expire in 2 hours."
            ),

            // Non-responsive notifications
            NotificationEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-14400), // 4 hours ago
                type: .nonResponsive,
                title: "Non-Responsive Contact",
                body: "Taylor Morgan has not checked in and is now non-responsive."
            ),
            NotificationEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-64800), // 18 hours ago
                type: .nonResponsive,
                title: "Non-Responsive Contact",
                body: "Casey Kim has not checked in and is now non-responsive."
            ),

            // Manual alerts
            NotificationEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-43200), // 12 hours ago
                type: .manualAlert,
                title: "Manual Alert",
                body: "Jane Smith has triggered a manual alert."
            ),
            NotificationEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-86400), // 1 day ago
                type: .manualAlert,
                title: "Manual Alert",
                body: "Michael Rodriguez has triggered a manual alert."
            ),

            // Ping notifications
            NotificationEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-21600), // 6 hours ago
                type: .pingNotification,
                title: "Ping Received",
                body: "Emily Chen has pinged you."
            ),
            NotificationEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-129600), // 1.5 days ago
                type: .pingNotification,
                title: "Ping Received",
                body: "Bob Johnson has pinged you."
            ),

            // More contact role changes
            NotificationEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-172800), // 2 days ago
                type: .contactRoleChanged,
                title: "Role Changed",
                body: "You added Sarah Williams as a responder."
            ),
            NotificationEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-259200), // 3 days ago
                type: .contactRoleChanged,
                title: "Role Changed",
                body: "You added David Miller as a dependent."
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
        } else if typeString == "Non-Responsive Contact" {
            type = .nonResponsive
        } else if typeString == "Ping Notification" {
            type = .pingNotification
        } else if typeString == "Contact Added" {
            type = .contactAdded
        } else if typeString == "Contact Removed" {
            type = .contactRemoved
        } else if typeString == "Contact Role Changed" {
            type = .contactRoleChanged
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

    /// Set the selected filter
    /// - Parameter filter: The notification type to filter by (nil for all)
    func setFilter(_ filter: NotificationType?) {
        selectedFilter = filter
    }

    /// Dismiss the notification center
    func dismiss(completion: @escaping () -> Void) {
        // Trigger haptic feedback
        HapticFeedback.triggerHaptic()
        completion()
    }
}
