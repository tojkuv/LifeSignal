import ComposableArchitecture
import Foundation
import Dependencies
import DependenciesMacros
import UserNotifications

// MARK: - Core Types

enum NotificationType: String, Codable, CaseIterable, Identifiable, Sendable {
    case checkInReminder = "check_in_reminder"
    case emergencyAlert = "emergency_alert"
    case contactPing = "contact_ping"
    case dependentOverdue = "dependent_overdue"
    case responderRequest = "responder_request"
    case system = "system"
    case contactRequest = "contact_request"

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
        }
    }

    var sound: UNNotificationSound {
        switch self {
        case .emergencyAlert, .dependentOverdue:
            return .defaultCritical
        default:
            return .default
        }
    }
}

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

// MARK: - Notification Client

@DependencyClient
struct NotificationClient {
    // Core operations
    var sendNotification: @Sendable (NotificationItem) async throws -> Void = { _ in }
    var scheduleNotification: @Sendable (NotificationItem, TimeInterval) async throws -> String = { _, _ in "" }
    var cancelNotification: @Sendable (String) async throws -> Void = { _ in }
    var getPendingNotifications: @Sendable () async throws -> [NotificationItem] = { [] }

    // Notification center
    var getNotifications: @Sendable () async throws -> [NotificationItem] = { [] }
    var markAsRead: @Sendable (UUID) async throws -> Void = { _ in }
    var deleteNotification: @Sendable (UUID) async throws -> Void = { _ in }
    var clearAll: @Sendable () async throws -> Void = { }

    // Permissions
    var requestPermission: @Sendable () async throws -> Bool = { false }
    var getNotificationSettings: @Sendable () async throws -> UNNotificationSettings = {
        await UNUserNotificationCenter.current().notificationSettings()
    }
}

extension NotificationClient: DependencyKey {
    static let liveValue: NotificationClient = {
        return NotificationClient(
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
                // Mock implementation for MVP - replace with actual storage
                return []
            },

            markAsRead: { notificationId in
                // Mock implementation for MVP
                print("Marking notification as read: \(notificationId)")
            },

            deleteNotification: { notificationId in
                // Mock implementation for MVP
                print("Deleting notification: \(notificationId)")
            },

            clearAll: {
                // Mock implementation for MVP
                print("Clearing all notifications")
                UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
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
            }
        )
    }()

    static let testValue = NotificationClient()
    static let mockValue = NotificationClient()
}

extension DependencyValues {
    var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}

// MARK: - Notification Delegate

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    private var notificationHandler: ((NotificationItem) async -> Void)?
    private var tapHandler: ((NotificationItem) async -> Void)?

    func setNotificationHandler(_ handler: @escaping (NotificationItem) async -> Void) {
        self.notificationHandler = handler
    }

    func setTapHandler(_ handler: @escaping (NotificationItem) async -> Void) {
        self.tapHandler = handler
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
        if let notificationItem = parseNotificationItem(from: notification) {
            Task {
                await notificationHandler?(notificationItem)
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let notificationItem = parseNotificationItem(from: response.notification) {
            Task {
                await tapHandler?(notificationItem)
            }
        }
        completionHandler()
    }

    private func parseNotificationItem(from notification: UNNotification) -> NotificationItem? {
        let userInfo = notification.request.content.userInfo
        guard let typeString = userInfo["type"] as? String,
              let type = NotificationType(rawValue: typeString),
              let notificationIdString = userInfo["notification_id"] as? String,
              let notificationId = UUID(uuidString: notificationIdString),
              let timestamp = userInfo["timestamp"] as? TimeInterval else {
            return nil
        }

        let contactId = (userInfo["contact_id"] as? String).flatMap { UUID(uuidString: $0) }
        let userId = (userInfo["user_id"] as? String).flatMap { UUID(uuidString: $0) }
        let metadata = userInfo["metadata"] as? [String: String] ?? [:]

        return NotificationItem(
            id: notificationId,
            type: type,
            title: notification.request.content.title,
            message: notification.request.content.body,
            timestamp: Date(timeIntervalSince1970: timestamp),
            contactId: contactId,
            userId: userId,
            metadata: metadata
        )
    }
}