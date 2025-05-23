import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation

// MARK: - Notification Repository

@DependencyClient
struct NotificationRepository {
    var getNotifications: @Sendable () async throws -> [NotificationItem]
    var markAsRead: @Sendable (UUID) async throws -> Void
    var deleteNotification: @Sendable (UUID) async throws -> Void
    var clearAll: @Sendable () async throws -> Void
    var sendLocalNotification: @Sendable (Notification, String, String) async -> Void
}

extension NotificationRepository: DependencyKey {
    static let liveValue: NotificationRepository = {
        @Dependency(\.grpcClient) var grpc
        @Dependency(\.firebaseAuth) var auth
        @Dependency(\.analytics) var analytics
        @Dependency(\.performance) var performance
        
        return NotificationRepository(
            getNotifications: {
                let trace = performance.startTrace("notifications.get")
                defer { performance.endTrace(trace, [:]) }
                
                let request = GetNotificationsRequest(firebaseUID: auth.getCurrentUID() ?? "")
                let response = try await grpc.notificationService.getNotifications(request)
                return response.notifications.map { $0.toDomain() }
            },
            
            markAsRead: { notificationID in
                let trace = performance.startTrace("notifications.mark_read")
                defer { performance.endTrace(trace, ["notification_id": notificationID.uuidString]) }
                
                let request = MarkNotificationRequest(notificationID: notificationID.uuidString)
                try await grpc.notificationService.markAsRead(request)
            },
            
            deleteNotification: { notificationID in
                let trace = performance.startTrace("notifications.delete")
                defer { performance.endTrace(trace, ["notification_id": notificationID.uuidString]) }
                
                let request = DeleteNotificationRequest(notificationID: notificationID.uuidString)
                try await grpc.notificationService.deleteNotification(request)
            },
            
            clearAll: {
                let trace = performance.startTrace("notifications.clear_all")
                defer { performance.endTrace(trace, [:]) }
                
                // Get all notifications and delete them
                let request = GetNotificationsRequest(firebaseUID: auth.getCurrentUID() ?? "")
                let response = try await grpc.notificationService.getNotifications(request)
                
                for notification in response.notifications {
                    let deleteRequest = DeleteNotificationRequest(notificationID: notification.id)
                    try await grpc.notificationService.deleteNotification(deleteRequest)
                }
            },
            
            sendLocalNotification: { type, title, body in
                await analytics.track(.notificationSent(type: type, title: title))
                // Local notification implementation would go here
                print("📬 Local notification: \(title) - \(body)")
            }
        )
    }()
    
    static let testValue = NotificationRepository(
        getNotifications: {
            [
                NotificationItem(
                    type: .checkIn,
                    title: "Check-in Reminder",
                    message: "Time for your daily check-in",
                    isRead: false
                ),
                NotificationItem(
                    type: .contactRequest,
                    title: "New Contact Request",
                    message: "John Doe wants to add you as a contact",
                    isRead: true
                )
            ]
        },
        markAsRead: { _ in },
        deleteNotification: { _ in },
        clearAll: { },
        sendLocalNotification: { _, _, _ in }
    )
}

extension DependencyValues {
    var notificationRepository: NotificationRepository {
        get { self[NotificationRepository.self] }
        set { self[NotificationRepository.self] = newValue }
    }
}