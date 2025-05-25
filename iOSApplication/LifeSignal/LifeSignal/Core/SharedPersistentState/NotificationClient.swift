import Foundation
import ComposableArchitecture
import Dependencies
import DependenciesMacros
import UserNotifications
@_exported import Sharing

// MARK: - gRPC Protocol Integration

protocol NotificationServiceProtocol: Sendable {
    func getNotifications(_ request: GetNotificationsRequest) async throws -> GetNotificationsResponse
    func addNotification(_ request: AddNotificationRequest) async throws -> Notification_Proto
    func markAsRead(_ request: MarkNotificationRequest) async throws -> Empty_Proto
    func deleteNotification(_ request: DeleteNotificationRequest) async throws -> Empty_Proto
    func clearAllNotifications(_ request: ClearAllNotificationsRequest) async throws -> Empty_Proto
}

// MARK: - gRPC Request/Response Types

struct GetNotificationsRequest: Sendable {
    let userId: UUID
    let authToken: String
}

struct GetNotificationsResponse: Sendable {
    let notifications: [Notification_Proto]
}

struct AddNotificationRequest: Sendable {
    let userId: UUID
    let type: NotificationType
    let title: String
    let message: String
    let contactId: UUID?
    let metadata: [String: String]
    let authToken: String
}

struct MarkNotificationRequest: Sendable {
    let notificationId: UUID
    let authToken: String
}

struct DeleteNotificationRequest: Sendable {
    let notificationId: UUID
    let authToken: String
}

struct ClearAllNotificationsRequest: Sendable {
    let userId: UUID
    let authToken: String
}

struct Empty_Proto: Sendable {}

// MARK: - gRPC Proto Types

struct Notification_Proto: Sendable {
    var id: String
    var userID: String
    var type: Notification_Type
    var title: String
    var message: String
    var isRead: Bool
    var createdAt: Int64
    var contactId: String?
    var userId: String?
    var metadata: [String: String]

    enum Notification_Type: Int32, CaseIterable, Sendable {
        case checkInReminder = 0
        case emergencyAlert = 1
        case contactPing = 2
        case dependentOverdue = 3
        case responderRequest = 4
        case system = 5
        case contactRequest = 6
    }
}

// MARK: - Mock gRPC Service

final class MockNotificationService: NotificationServiceProtocol {
    func getNotifications(_ request: GetNotificationsRequest) async throws -> GetNotificationsResponse {
        try await Task.sleep(for: .milliseconds(400))

        let mockNotifications = [
            Notification_Proto(
                id: UUID().uuidString,
                userID: request.userId.uuidString,
                type: .checkInReminder,
                title: "Check-in Reminder",
                message: "Time for your check-in!",
                isRead: false,
                createdAt: Int64(Date().addingTimeInterval(-3600).timeIntervalSince1970),
                contactId: nil,
                userId: request.userId.uuidString,
                metadata: [:]
            )
        ]

        return GetNotificationsResponse(notifications: mockNotifications)
    }

    func addNotification(_ request: AddNotificationRequest) async throws -> Notification_Proto {
        try await Task.sleep(for: .milliseconds(300))
        return Notification_Proto(
            id: UUID().uuidString,
            userID: request.userId.uuidString,
            type: request.type.toProto(),
            title: request.title,
            message: request.message,
            isRead: false,
            createdAt: Int64(Date().timeIntervalSince1970),
            contactId: request.contactId?.uuidString,
            userId: request.userId.uuidString,
            metadata: request.metadata
        )
    }

    func markAsRead(_ request: MarkNotificationRequest) async throws -> Empty_Proto {
        try await Task.sleep(for: .milliseconds(200))
        return Empty_Proto()
    }

    func deleteNotification(_ request: DeleteNotificationRequest) async throws -> Empty_Proto {
        try await Task.sleep(for: .milliseconds(200))
        return Empty_Proto()
    }

    func clearAllNotifications(_ request: ClearAllNotificationsRequest) async throws -> Empty_Proto {
        try await Task.sleep(for: .milliseconds(300))
        return Empty_Proto()
    }
}

// MARK: - Mapping Extensions

extension Notification_Proto {
    func toDomain() -> NotificationItem {
        NotificationItem(
            id: UUID(uuidString: id) ?? UUID(),
            title: title,
            message: message,
            timestamp: Date(timeIntervalSince1970: TimeInterval(createdAt)),
            isRead: isRead,
            type: type.toDomain(),
            contactId: contactId.flatMap { UUID(uuidString: $0) },
            userId: userId.flatMap { UUID(uuidString: $0) },
            metadata: metadata
        )
    }
}

extension Notification_Proto.Notification_Type {
    func toDomain() -> NotificationType {
        switch self {
        case .checkInReminder: return .checkInReminder
        case .emergencyAlert: return .emergencyAlert
        case .contactPing: return .contactPing
        case .dependentOverdue: return .dependentOverdue
        case .responderRequest: return .responderRequest
        case .system: return .system
        case .contactRequest: return .contactRequest
        }
    }
}

extension NotificationType {
    func toProto() -> Notification_Proto.Notification_Type {
        switch self {
        case .checkInReminder: return .checkInReminder
        case .emergencyAlert: return .emergencyAlert
        case .contactPing: return .contactPing
        case .dependentOverdue: return .dependentOverdue
        case .responderRequest: return .responderRequest
        case .system: return .system
        case .contactRequest: return .contactRequest
        // Handle additional cases from NotificationClient's enum
        case .contactUpdate: return .system
        case .systemNotification: return .system
        case .incomingPing: return .contactPing
        case .missedCheckIn: return .dependentOverdue
        }
    }
}

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
            title: notification.request.content.title,
            message: notification.request.content.body,
            timestamp: Date(timeIntervalSince1970: timestamp),
            type: type,
            contactId: contactId,
            userId: userId,
            metadata: metadata
        )
    }
}

// MARK: - Notification Shared State

extension SharedReaderKey where Self == InMemoryKey<[NotificationItem]>.Default {
    static var notifications: Self {
        Self[.inMemory("notifications"), default: []]
    }
}

extension SharedReaderKey where Self == InMemoryKey<Int>.Default {
    static var unreadNotificationCount: Self {
        Self[.inMemory("unreadNotificationCount"), default: 0]
    }
}

extension SharedReaderKey where Self == InMemoryKey<[PendingNotificationAction]>.Default {
    static var pendingNotificationActions: Self {
        Self[.inMemory("pendingNotificationActions"), default: []]
    }
}

// MARK: - Notification Persistence Models

struct PendingNotificationAction: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var operation: NotificationOperation
    var payload: Data
    var createdAt: Date
    var attemptCount: Int
    var maxAttempts: Int
    var priority: ActionPriority
    
    enum ActionPriority: Int, Codable, CaseIterable {
        case low = 0
        case standard = 1
        case high = 2
        case critical = 3
    }
    
    enum NotificationOperation: String, Codable, CaseIterable {
        case createNotification = "notification.create"
        case markNotificationRead = "notification.read"
        case clearNotifications = "notification.clear"
    }
    
    init(
        id: UUID = UUID(),
        operation: NotificationOperation,
        payload: Data,
        createdAt: Date = Date(),
        attemptCount: Int = 0,
        maxAttempts: Int = 3,
        priority: ActionPriority = .standard
    ) {
        self.id = id
        self.operation = operation
        self.payload = payload
        self.createdAt = createdAt
        self.attemptCount = attemptCount
        self.maxAttempts = maxAttempts
        self.priority = priority
    }
    
    var canRetry: Bool {
        attemptCount < maxAttempts
    }
    
    var isExpired: Bool {
        let expiryTime: TimeInterval = priority == .critical ? 86400 : 3600
        return Date().timeIntervalSince(createdAt) > expiryTime
    }
}


// MARK: - Domain Models

struct NotificationItem: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var title: String
    var message: String
    var timestamp: Date
    var isRead: Bool
    var type: NotificationType
    var relatedContactId: UUID?
    var actionRequired: Bool
    let contactId: UUID?
    let userId: UUID?
    let metadata: [String: String]
    
    init(
        id: UUID = UUID(),
        title: String,
        message: String,
        timestamp: Date = Date(),
        isRead: Bool = false,
        type: NotificationType = .checkInReminder,
        relatedContactId: UUID? = nil,
        actionRequired: Bool = false,
        contactId: UUID? = nil,
        userId: UUID? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.timestamp = timestamp
        self.isRead = isRead
        self.type = type
        self.relatedContactId = relatedContactId
        self.actionRequired = actionRequired
        self.contactId = contactId ?? relatedContactId
        self.userId = userId
        self.metadata = metadata
    }
}

enum NotificationType: String, Codable, CaseIterable, Identifiable, Sendable {
    case checkInReminder = "check_in_reminder"
    case emergencyAlert = "emergency_alert"
    case contactUpdate = "contact_update"
    case systemNotification = "system_notification"
    case incomingPing = "incoming_ping"
    case missedCheckIn = "missed_check_in"
    case contactPing = "contact_ping"
    case dependentOverdue = "dependent_overdue"
    case responderRequest = "responder_request"
    case system = "system"
    case contactRequest = "contact_request"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .checkInReminder:
            return "Check-in Reminder"
        case .emergencyAlert:
            return "Emergency Alert"
        case .contactUpdate:
            return "Contact Update"
        case .systemNotification, .system:
            return "System Notification"
        case .incomingPing, .contactPing:
            return "Incoming Ping"
        case .missedCheckIn:
            return "Missed Check-in"
        case .dependentOverdue:
            return "Dependent Overdue"
        case .responderRequest:
            return "Responder Request"
        case .contactRequest:
            return "Contact Request"
        }
    }
    
    var title: String {
        return displayName
    }
    
    var priority: NotificationPriority {
        switch self {
        case .emergencyAlert, .missedCheckIn, .dependentOverdue:
            return .high
        case .incomingPing, .checkInReminder, .contactPing, .responderRequest:
            return .medium
        case .contactUpdate, .systemNotification, .system, .contactRequest:
            return .low
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

enum NotificationPriority: Int, Codable, CaseIterable, Sendable {
    case low = 0
    case medium = 1
    case high = 2
}


// MARK: - Client Errors

enum NotificationClientError: Error, LocalizedError {
    case notificationNotFound(String)
    case saveFailed(String)
    case deleteFailed(String)
    case markReadFailed(String)
    case permissionDenied(String)
    case scheduleError(String)
    
    var errorDescription: String? {
        switch self {
        case .notificationNotFound(let details):
            return "Notification not found: \(details)"
        case .saveFailed(let details):
            return "Save failed: \(details)"
        case .deleteFailed(let details):
            return "Delete failed: \(details)"
        case .markReadFailed(let details):
            return "Mark read failed: \(details)"
        case .permissionDenied(let details):
            return "Permission denied: \(details)"
        case .scheduleError(let details):
            return "Schedule error: \(details)"
        }
    }
}

// MARK: - Notification Client

// MARK: - Notification Persistence Helpers

extension NotificationClient {
    static func getAuthenticationToken() async throws -> String {
        @Dependency(\.authenticationClient) var authClient
        guard let token = try await authClient.getIdToken(false) else {
            throw NotificationClientError.saveFailed("No authentication token available")
        }
        return token
    }
    
    // For backward compatibility during transition
    static func getAuthToken() async throws -> String {
        return try await getAuthenticationToken()
    }
    
    static func storeNotificationsData(_ notifications: [NotificationItem], key: String = "notifications") async {
        // Mock local storage - would use Core Data/file system in production
        try? await Task.sleep(for: .milliseconds(50))
    }
    
    static func retrieveNotificationsData<T>(_ key: String, type: T.Type) async -> T? {
        // Mock retrieval - would load from Core Data/file system in production
        try? await Task.sleep(for: .milliseconds(50))
        return nil
    }
    
    static func addPendingNotificationAction(_ operation: PendingNotificationAction.NotificationOperation, payload: Data, priority: PendingNotificationAction.ActionPriority) async {
        @Shared(.pendingNotificationActions) var pending
        let action = PendingNotificationAction(
            operation: operation,
            payload: payload,
            priority: priority
        )
        $pending.withLock { $0.append(action) }
    }
    
    static func executeWithNetworkFallback<T>(
        _ networkOperation: @escaping () async throws -> T,
        pendingOperation: PendingNotificationAction.NotificationOperation? = nil,
        priority: PendingNotificationAction.ActionPriority = .standard
    ) async throws -> T {
        @Dependency(\.networkClient) var network
        
        let isConnected = await network.checkConnectivity()
        
        if isConnected {
            do {
                let result = try await networkOperation()
                // Store successful result locally
                if let notifications = result as? [NotificationItem] {
                    await Self.storeNotificationsData(notifications)
                }
                return result
            } catch {
                if let operation = pendingOperation {
                    await Self.addPendingNotificationAction(operation, payload: Data(), priority: priority)
                }
                throw error
            }
        } else {
            // For notifications, some operations can work offline
            if let operation = pendingOperation {
                await Self.addPendingNotificationAction(operation, payload: Data(), priority: priority)
            }
            
            throw NotificationClientError.saveFailed("Operation requires network connectivity")
        }
    }
}

@DependencyClient
struct NotificationClient {
    // gRPC service integration
    var notificationService: NotificationServiceProtocol = MockNotificationService()
    // CRUD operations that sync with shared state
    var getNotifications: @Sendable () async -> [NotificationItem] = { [] }
    var getNotification: @Sendable (UUID) async throws -> NotificationItem? = { _ in nil }
    var addNotification: @Sendable (NotificationItem) async throws -> NotificationItem = { notification in notification }
    var updateNotification: @Sendable (NotificationItem) async throws -> NotificationItem = { notification in notification }
    var removeNotification: @Sendable (UUID) async throws -> Void = { _ in }
    var clearAllNotifications: @Sendable () async throws -> Void = { }
    
    // Read status operations that sync with shared state
    var markAsRead: @Sendable (UUID) async throws -> NotificationItem = { _ in
        throw NotificationClientError.notificationNotFound("Notification not found")
    }
    var markAllAsRead: @Sendable () async throws -> [NotificationItem] = { [] }
    var getUnreadCount: @Sendable () async -> Int = { 0 }
    var getUnreadNotifications: @Sendable () async -> [NotificationItem] = { [] }
    
    // Filtering and search
    var getNotificationsByType: @Sendable (NotificationType) async -> [NotificationItem] = { _ in [] }
    var getNotificationsByContact: @Sendable (UUID) async -> [NotificationItem] = { _ in [] }
    var searchNotifications: @Sendable (String) async -> [NotificationItem] = { _ in [] }
    
    // Core notification operations
    var sendNotification: @Sendable (NotificationItem) async throws -> Void = { _ in }
    var scheduleNotification: @Sendable (NotificationItem, TimeInterval) async throws -> String = { _, _ in "" }
    var getPendingNotifications: @Sendable () async throws -> [NotificationItem] = { [] }
    
    // Notification scheduling (for local notifications)
    var scheduleCheckInReminder: @Sendable (Date, String) async throws -> Void = { _, _ in }
    var cancelScheduledNotification: @Sendable (String) async throws -> Void = { _ in }
    var cancelAllScheduledNotifications: @Sendable () async throws -> Void = { }
    
    // Permissions
    var requestPermission: @Sendable () async throws -> Bool = { false }
    var getNotificationSettings: @Sendable () async throws -> UNNotificationSettings = {
        await UNUserNotificationCenter.current().notificationSettings()
    }
    
    // FCM Token management for remote notifications
    var registerFCMToken: @Sendable (String) async throws -> Void = { _ in }
    var getFCMToken: @Sendable () async -> String? = { nil }
    var clearFCMToken: @Sendable () async throws -> Void = { }
    var refreshFCMToken: @Sendable () async throws -> String? = { nil }
    
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
                        title: request.content.title,
                        message: request.content.body,
                        timestamp: Date(timeIntervalSince1970: timestamp),
                        type: type,
                        contactId: contactId,
                        userId: userId,
                        metadata: metadata
                    )
                }
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
            
            cancelScheduledNotification: { identifier in
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
            }
        )
    }()
    
    static let testValue = NotificationClient()
    
    static let mockValue = NotificationClient(
        getNotifications: {
            @Shared(.notifications) var notifications
            return notifications
        },
        
        getNotification: { notificationId in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(200))
            
            @Shared(.notifications) var notifications
            return notifications.first { $0.id == notificationId }
        },
        
        addNotification: { notification in
            let authToken = try await Self.getAuthToken()
            let service = MockNotificationService()
            @Dependency(\.userClient) var userClient
            
            guard let currentUser = await userClient.getCurrentUser() else {
                throw NotificationClientError.saveFailed("No current user available")
            }
            
            let request = AddNotificationRequest(
                userId: currentUser.id,
                type: notification.type,
                title: notification.title,
                message: notification.message,
                contactId: notification.contactId,
                metadata: notification.metadata,
                authToken: authToken
            )
            
            let notificationProto = try await service.addNotification(request)
            let newNotification = notificationProto.toDomain()
            
            @Shared(.notifications) var notifications
            @Shared(.unreadNotificationCount) var unreadCount
            
            $notifications.withLock { $0.append(newNotification) }
            
            // Update unread count
            $unreadCount.withLock { $0 = notifications.filter { !$0.isRead }.count }
            
            return newNotification
        },
        
        updateNotification: { notification in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(250))
            
            @Shared(.notifications) var notifications
            
            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                $notifications.withLock { $0[index] = notification }
                return notification
            }
            
            throw NotificationClientError.notificationNotFound("Notification with ID \(notification.id) not found")
        },
        
        removeNotification: { notificationId in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(200))
            
            @Shared(.notifications) var notifications
            @Shared(.unreadNotificationCount) var unreadCount
            
            $notifications.withLock { $0.removeAll { $0.id == notificationId } }
            
            // Update unread count
            $unreadCount.withLock { $0 = notifications.filter { !$0.isRead }.count }
        },
        
        clearAllNotifications: {
            let authToken = try await Self.getAuthToken()
            let service = MockNotificationService()
            @Dependency(\.userClient) var userClient
            
            guard let currentUser = await userClient.getCurrentUser() else {
                throw NotificationClientError.saveFailed("No current user available")
            }
            
            let request = ClearAllNotificationsRequest(userId: currentUser.id, authToken: authToken)
            _ = try await service.clearAllNotifications(request)
            
            @Shared(.notifications) var notifications
            @Shared(.unreadNotificationCount) var unreadCount
            
            $notifications.withLock { $0.removeAll() }
            $unreadCount.withLock { $0 = 0 }
        },
        
        markAsRead: { notificationId in
            let authToken = try await Self.getAuthToken()
            let service = MockNotificationService()
            
            let request = MarkNotificationRequest(notificationId: notificationId, authToken: authToken)
            _ = try await service.markAsRead(request)
            
            @Shared(.notifications) var notifications
            @Shared(.unreadNotificationCount) var unreadCount
            
            if let index = notifications.firstIndex(where: { $0.id == notificationId }) {
                $notifications.withLock { $0[index].isRead = true }
                
                // Update unread count
                $unreadCount.withLock { $0 = notifications.filter { !$0.isRead }.count }
                
                return notifications[index]
            }
            
            throw NotificationClientError.notificationNotFound("Notification with ID \(notificationId) not found")
        },
        
        markAllAsRead: {
            // Simulate delay
            try await Task.sleep(for: .milliseconds(400))
            
            @Shared(.notifications) var notifications
            @Shared(.unreadNotificationCount) var unreadCount
            
            $notifications.withLock {
                for index in $0.indices {
                    $0[index].isRead = true
                }
            }
            
            $unreadCount.withLock { $0 = 0 }
            
            return notifications
        },
        
        getUnreadCount: {
            @Shared(.unreadNotificationCount) var unreadCount
            return unreadCount
        },
        
        getUnreadNotifications: {
            @Shared(.notifications) var notifications
            return notifications.filter { !$0.isRead }
        },
        
        getNotificationsByType: { type in
            @Shared(.notifications) var notifications
            return notifications.filter { $0.type == type }
        },
        
        getNotificationsByContact: { contactId in
            @Shared(.notifications) var notifications
            return notifications.filter { $0.relatedContactId == contactId }
        },
        
        searchNotifications: { query in
            @Shared(.notifications) var notifications
            
            if query.isEmpty {
                return notifications
            }
            
            return notifications.filter { notification in
                notification.title.localizedCaseInsensitiveContains(query) ||
                notification.message.localizedCaseInsensitiveContains(query)
            }
        },
        
        scheduleCheckInReminder: { date, message in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(200))
            // Mock scheduling always succeeds
        },
        
        cancelScheduledNotification: { identifier in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(150))
            // Mock cancellation always succeeds
        },
        
        cancelAllScheduledNotifications: {
            // Simulate delay
            try await Task.sleep(for: .milliseconds(300))
            // Mock cancellation always succeeds
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        },
        
        sendNotification: { notification in
            // Add to shared state for mock
            @Shared(.notifications) var notifications
            @Shared(.unreadNotificationCount) var unreadCount
            
            var newNotification = notification
            newNotification.timestamp = Date()
            $notifications.withLock { $0.append(newNotification) }
            
            // Update unread count
            $unreadCount.withLock { $0 = notifications.filter { !$0.isRead }.count }
        },
        
        scheduleNotification: { notification, delay in
            // Add to shared state for mock
            @Shared(.notifications) var notifications
            @Shared(.unreadNotificationCount) var unreadCount
            
            var newNotification = notification
            newNotification.timestamp = Date().addingTimeInterval(delay)
            $notifications.withLock { $0.append(newNotification) }
            
            // Update unread count
            $unreadCount.withLock { $0 = notifications.filter { !$0.isRead }.count }
            
            return notification.id.uuidString
        },
        
        getPendingNotifications: {
            @Shared(.notifications) var notifications
            // Return future notifications
            return notifications.filter { $0.timestamp > Date() }
        },
        
        requestPermission: {
            // Mock always grants permission
            return true
        },
        
        getNotificationSettings: {
            await UNUserNotificationCenter.current().notificationSettings()
        },
        
        // FCM Token management for remote notifications
        registerFCMToken: { token in
            // Register the FCM token with UserClient for server sync
            @Dependency(\.userClient) var userClient
            
            // Update user's FCM token on server for push notifications
            _ = try await userClient.updateFCMToken(token)
            
            // Mock: Simulate successful FCM token registration
            print("🔔 [MOCK] FCM Token registered: \(String(token.prefix(20)))...")
        },
        
        getFCMToken: {
            // Return mock FCM token for MVP
            @Dependency(\.userClient) var userClient
            
            // Get current FCM token from UserClient
            return await userClient.getCurrentFCMToken() ?? "mock_fcm_token_\(UUID().uuidString)"
        },
        
        clearFCMToken: {
            // Clear FCM token from UserClient
            @Dependency(\.userClient) var userClient
            
            _ = try await userClient.clearFCMToken()
            
            // Mock: Simulate successful FCM token clearing
            print("🔔 [MOCK] FCM Token cleared successfully")
        },
        
        refreshFCMToken: {
            // Mock: Generate new FCM token
            let newToken = "mock_fcm_token_\(UUID().uuidString)"
            
            // Register the new token
            @Dependency(\.userClient) var userClient
            _ = try await userClient.updateFCMToken(newToken)
            
            print("🔔 [MOCK] FCM Token refreshed: \(String(newToken.prefix(20)))...")
            return newToken
        }
        
    )
}

extension DependencyValues {
    var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}