import Foundation
import ComposableArchitecture
import Dependencies
import DependenciesMacros
import UserNotifications

// MARK: - Unified Notification System

enum NotificationType: String, Codable, CaseIterable, Identifiable, Sendable {
    // Core types
    case checkInReminder = "check_in_reminder"
    case emergencyAlert = "emergency_alert"
    case contactPing = "contact_ping"
    case dependentOverdue = "dependent_overdue"
    case responderRequest = "responder_request"
    case system = "system"
    case contactRequest = "contact_request"

    // Legacy/specific types
    case manualAlert = "manual_alert"
    case nonResponsive = "non_responsive"
    case contactAdded = "contact_added"
    case contactRemoved = "contact_removed"
    case contactRoleChanged = "contact_role_changed"
    case qrCodeNotification = "qr_code"
    case alertCancelled = "alert_cancelled"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .checkInReminder: return "Check-in Reminder"
        case .emergencyAlert: return "Emergency Alert"
        case .contactPing: return "Contact Ping"
        case .dependentOverdue: return "Dependent Overdue"
        case .responderRequest: return "Responder Request"
        case .system: return "System"
        case .contactRequest: return "Contact Request"
        case .manualAlert: return "Manual Alert"
        case .nonResponsive: return "Non-Responsive Contact"
        case .contactAdded: return "Contact Added"
        case .contactRemoved: return "Contact Removed"
        case .contactRoleChanged: return "Contact Role Changed"
        case .qrCodeNotification: return "QR Code"
        case .alertCancelled: return "Alert Cancelled"
        }
    }

    var sound: UNNotificationSound {
        switch self {
        case .emergencyAlert:
            return .defaultCritical
        case .contactPing, .responderRequest, .dependentOverdue:
            return .default
        default:
            return .default
        }
    }
}

// MARK: - Unified Notification Model

struct NotificationItem: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let type: NotificationType
    let title: String
    let message: String
    var isRead: Bool
    let timestamp: Date
    let contactId: UUID?
    let userId: UUID?
    let metadata: [String: String]

    init(
        id: UUID = UUID(),
        type: NotificationType,
        title: String,
        message: String,
        isRead: Bool = false,
        timestamp: Date = Date(),
        contactId: UUID? = nil,
        userId: UUID? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
        self.isRead = isRead
        self.timestamp = timestamp
        self.contactId = contactId
        self.userId = userId
        self.metadata = metadata
    }
}

// MARK: - Notification Repository

@DependencyClient
struct NotificationRepository {
    // Core notification operations
    var sendNotification: @Sendable (NotificationItem) async throws -> Void = { _ in }
    var scheduleNotification: @Sendable (NotificationItem, TimeInterval) async throws -> String = { _, _ in "" }
    var cancelNotification: @Sendable (String) async throws -> Void = { _ in }
    var cancelAllNotifications: @Sendable () async throws -> Void = { }
    var getPendingNotifications: @Sendable () async throws -> [NotificationItem] = { [] }

    // Notification center management
    var getNotifications: @Sendable () async throws -> [NotificationItem] = { [] }
    var addNotification: @Sendable (NotificationItem) async throws -> Void = { _ in }
    var markAsRead: @Sendable (UUID) async throws -> Void = { _ in }
    var deleteNotification: @Sendable (UUID) async throws -> Void = { _ in }
    var clearAll: @Sendable () async throws -> Void = { }

    // Permission and settings
    var requestPermission: @Sendable () async throws -> Bool = { false }
    var getNotificationSettings: @Sendable () async throws -> UNNotificationSettings = {
        await UNUserNotificationCenter.current().notificationSettings()
    }
    var handleNotificationResponse: @Sendable (UNNotificationResponse) async throws -> Void = { _ in }
    var removeAllDeliveredNotifications: @Sendable () async throws -> Void = { }

    // Convenience methods for common notifications
    var showQRCodeResetNotification: @Sendable () async throws -> Void = { }
    var showNotificationSettingsUpdatedNotification: @Sendable () async throws -> Void = { }
    var showCheckInNotification: @Sendable () async throws -> Void = { }
    var showAlertActivationNotification: @Sendable () async throws -> Void = { }
    var showAlertDeactivationNotification: @Sendable () async throws -> Void = { }
    var showPingNotification: @Sendable (String) async throws -> Void = { _ in }
    var showContactAddedNotification: @Sendable (String) async throws -> Void = { _ in }
    var showContactRemovedNotification: @Sendable (String) async throws -> Void = { _ in }
    var showContactRoleToggleNotification: @Sendable (String, Bool, Bool, Bool, Bool) async throws -> Void = { _, _, _, _, _ in }
    var showQRCodeCopiedNotification: @Sendable () async throws -> Void = { }
    var showPhoneNumberChangedNotification: @Sendable () async throws -> Void = { }
    var showAllPingsClearedNotification: @Sendable () async throws -> Void = { }
}

extension NotificationRepository: DependencyKey {
    static let liveValue: NotificationRepository = {

        // Helper function to send and optionally track notifications
        @Sendable func sendAndTrackNotification(
            title: String,
            body: String,
            type: NotificationType,
            trackInCenter: Bool,
            contactId: UUID? = nil,
            userId: UUID? = nil,
            metadata: [String: String] = [:]
        ) async throws {
            let notification = NotificationItem(
                type: type,
                title: title,
                message: body,
                contactId: contactId,
                userId: userId,
                metadata: metadata
            )

            // Send system notification
            let content = UNMutableNotificationContent()
            content.title = notification.title
            content.body = notification.message
            content.sound = notification.type.sound
            content.userInfo = [
                "notification_id": notification.id.uuidString,
                "type": notification.type.rawValue,
                "contact_id": notification.contactId?.uuidString ?? "",
                "user_id": notification.userId?.uuidString ?? "",
                "timestamp": notification.timestamp.timeIntervalSince1970,
                "metadata": notification.metadata
            ]

            let request = UNNotificationRequest(
                identifier: notification.id.uuidString,
                content: content,
                trigger: nil
            )

            try await UNUserNotificationCenter.current().add(request)

            // Track in notification center if requested
            if trackInCenter {
                // In production, this would save to local storage or send to server
                // For now, we'll just log it
                print("Tracking notification in center: \(notification.title)")
            }
        }

        return NotificationRepository(
            sendNotification: { notification in
                let content = UNMutableNotificationContent()
                content.title = notification.title
                content.body = notification.message
                content.sound = notification.type.sound
                content.userInfo = [
                    "notification_id": notification.id.uuidString,
                    "type": notification.type.rawValue,
                    "contact_id": notification.contactId?.uuidString ?? "",
                    "user_id": notification.userId?.uuidString ?? "",
                    "timestamp": notification.timestamp.timeIntervalSince1970,
                    "metadata": notification.metadata
                ]

                let request = UNNotificationRequest(
                    identifier: notification.id.uuidString,
                    content: content,
                    trigger: nil
                )

                try await UNUserNotificationCenter.current().add(request)
            },

            scheduleNotification: { notification, delay in
                let content = UNMutableNotificationContent()
                content.title = notification.title
                content.body = notification.message
                content.sound = notification.type.sound
                content.userInfo = [
                    "notification_id": notification.id.uuidString,
                    "type": notification.type.rawValue,
                    "contact_id": notification.contactId?.uuidString ?? "",
                    "user_id": notification.userId?.uuidString ?? "",
                    "timestamp": notification.timestamp.timeIntervalSince1970,
                    "metadata": notification.metadata
                ]

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
                let request = UNNotificationRequest(
                    identifier: notification.id.uuidString,
                    content: content,
                    trigger: trigger
                )

                try await UNUserNotificationCenter.current().add(request)
                return notification.id.uuidString
            },

            cancelNotification: { identifier in
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
            },

            cancelAllNotifications: {
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            },

            getPendingNotifications: {
                let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
                return requests.compactMap { request -> NotificationItem? in
                    guard let typeString = request.content.userInfo["type"] as? String,
                          let type = NotificationType(rawValue: typeString),
                          let notificationIdString = request.content.userInfo["notification_id"] as? String,
                          let notificationId = UUID(uuidString: notificationIdString),
                          let timestamp = request.content.userInfo["timestamp"] as? TimeInterval else {
                        return nil
                    }

                    let contactId = (request.content.userInfo["contact_id"] as? String).flatMap { UUID(uuidString: $0) }
                    let userId = (request.content.userInfo["user_id"] as? String).flatMap { UUID(uuidString: $0) }
                    let metadata = request.content.userInfo["metadata"] as? [String: String] ?? [:]

                    return NotificationItem(
                        id: notificationId,
                        type: type,
                        title: request.content.title,
                        message: request.content.body,
                        timestamp: Date(timeIntervalSince1970: timestamp),
                        contactId: contactId,
                        userId: userId,
                        metadata: metadata
                    )
                }
            },

            getNotifications: {
                // Mock implementation - replace with actual storage
                return [
                    NotificationItem(
                        type: .checkInReminder,
                        title: "Check-in Reminder",
                        message: "Time for your check-in!",
                        timestamp: Date().addingTimeInterval(-3600)
                    ),
                    NotificationItem(
                        type: .emergencyAlert,
                        title: "Alert",
                        message: "Contact needs assistance",
                        isRead: true,
                        timestamp: Date().addingTimeInterval(-7200)
                    )
                ]
            },

            addNotification: { notification in
                // Mock implementation - replace with actual storage
                print("Adding notification to center: \(notification.title)")
            },

            markAsRead: { notificationId in
                // Mock implementation - replace with actual storage update
                print("Marking notification as read: \(notificationId)")
            },

            deleteNotification: { notificationId in
                // Mock implementation - replace with actual storage deletion
                print("Deleting notification: \(notificationId)")
            },

            clearAll: {
                // Mock implementation - replace with actual storage clearing
                print("Clearing all notifications")
            },

            requestPermission: {
                let options: UNAuthorizationOptions = [.alert, .sound, .badge, .criticalAlert]
                return try await withCheckedThrowingContinuation { continuation in
                    UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: granted)
                        }
                    }
                }
            },

            getNotificationSettings: {
                await UNUserNotificationCenter.current().notificationSettings()
            },

            handleNotificationResponse: { response in
                let userInfo = response.notification.request.content.userInfo

                guard let typeString = userInfo["type"] as? String,
                      let _ = NotificationType(rawValue: typeString) else {
                    return
                }

                switch response.actionIdentifier {
                case UNNotificationDefaultActionIdentifier:
                    // User tapped the notification
                    break
                case UNNotificationDismissActionIdentifier:
                    // User dismissed the notification
                    break
                default:
                    // Custom action
                    break
                }
            },

            removeAllDeliveredNotifications: {
                UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            },

            // Convenience method implementations
            showQRCodeResetNotification: {
                try await sendAndTrackNotification(
                    title: "QR Code Reset",
                    body: "Your QR code has been reset. Previous QR codes are no longer valid.",
                    type: .qrCodeNotification,
                    trackInCenter: false
                )
            },

            showNotificationSettingsUpdatedNotification: {
                try await sendAndTrackNotification(
                    title: "Notification Settings Updated",
                    body: "Your notification settings have been successfully updated.",
                    type: .system,
                    trackInCenter: false
                )
            },

            showCheckInNotification: {
                try await sendAndTrackNotification(
                    title: "Check-in Completed",
                    body: "You have successfully checked in.",
                    type: .checkInReminder,
                    trackInCenter: true
                )
            },

            showAlertActivationNotification: {
                try await sendAndTrackNotification(
                    title: "Alert Activated",
                    body: "You have activated an alert. Your responders have been notified.",
                    type: .manualAlert,
                    trackInCenter: true
                )
            },

            showAlertDeactivationNotification: {
                try await sendAndTrackNotification(
                    title: "Alert Deactivated",
                    body: "You have deactivated your alert.",
                    type: .manualAlert,
                    trackInCenter: true
                )
            },

            showPingNotification: { contactName in
                try await sendAndTrackNotification(
                    title: "Ping Sent",
                    body: "You pinged \(contactName).",
                    type: .contactPing,
                    trackInCenter: true
                )
            },

            showContactAddedNotification: { contactName in
                try await sendAndTrackNotification(
                    title: "Contact Added",
                    body: "You have added \(contactName) to your contacts.",
                    type: .contactAdded,
                    trackInCenter: true
                )
            },

            showContactRemovedNotification: { contactName in
                try await sendAndTrackNotification(
                    title: "Contact Removed",
                    body: "You have removed \(contactName) from your contacts.",
                    type: .contactRemoved,
                    trackInCenter: true
                )
            },

            showContactRoleToggleNotification: { contactName, isResponder, isDependent, wasResponder, wasDependent in
                let responderChanged = isResponder != wasResponder
                let dependentChanged = isDependent != wasDependent

                var title = "Contact Role Updated"
                var body = ""

                if responderChanged && dependentChanged {
                    if isResponder && isDependent {
                        body = "\(contactName) is now both a responder and a dependent."
                    } else if !isResponder && !isDependent {
                        body = "\(contactName) is no longer a responder or a dependent."
                    } else {
                        body = "\(contactName)'s roles have been updated."
                    }
                } else if responderChanged {
                    if isResponder {
                        title = "Responder Added"
                        body = "\(contactName) can now respond to your alerts."
                    } else {
                        title = "Responder Removed"
                        body = "\(contactName) will no longer respond to your alerts."
                    }
                } else if dependentChanged {
                    if isDependent {
                        title = "Dependent Added"
                        body = "You can now check on \(contactName)."
                    } else {
                        title = "Dependent Removed"
                        body = "You will no longer check on \(contactName)."
                    }
                } else {
                    body = "\(contactName)'s roles remain unchanged."
                }

                try await sendAndTrackNotification(
                    title: title,
                    body: body,
                    type: .contactRoleChanged,
                    trackInCenter: true
                )
            },

            showQRCodeCopiedNotification: {
                try await sendAndTrackNotification(
                    title: "QR Code ID Copied",
                    body: "Your QR code ID has been copied to the clipboard.",
                    type: .qrCodeNotification,
                    trackInCenter: false
                )
            },

            showPhoneNumberChangedNotification: {
                try await sendAndTrackNotification(
                    title: "Phone Number Updated",
                    body: "Your phone number has been successfully updated.",
                    type: .system,
                    trackInCenter: false
                )
            },

            showAllPingsClearedNotification: {
                try await sendAndTrackNotification(
                    title: "All Pings Cleared",
                    body: "You have cleared all pending pings.",
                    type: .contactPing,
                    trackInCenter: true
                )
            }
        )
    }()

    static let testValue = NotificationRepository()
}

// MARK: - Dependency Extension

extension DependencyValues {
    var notificationRepository: NotificationRepository {
        get { self[NotificationRepository.self] }
        set { self[NotificationRepository.self] = newValue }
    }
}