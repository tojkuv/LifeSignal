import Foundation
import ComposableArchitecture
import Dependencies
import DependenciesMacros
import UserNotifications
@_exported import Sharing

// MARK: - NotificationClient Documentation
/**
 * NotificationClient provides centralized notification management for the LifeSignal app.
 * 
 * ## Architecture Overview
 * - Uses SessionClient for authentication (token + user ID)
 * - Features control notification sending explicitly (no automatic notifications)
 * - All notifications are tracked in shared state history
 * - Local device operations (check-in reminders) are separate from tracked notifications
 * 
 * ## Notification Types & Semantics
 * 
 * ### Emergency Alerts (High Priority - Critical Sounds)
 * - `sendManualAlertActive/Inactive`: User emergency alert state changes
 * - `receiveDependentManualAlertActive/Inactive`: Dependent emergency alert state changes (to responders only)
 * 
 * ### Non-Responsive Alerts (High Priority - Critical Sounds)
 * - `receiveNonResponsiveAlert`: User missed their own check-in
 * - `receiveNonResponsiveDependentAlert`: Dependent missed check-in (to responders only)
 * 
 * ### Ping Communications (Medium/Low Priority)
 * - `sendDependentPing`: User sent ping to dependent
 * - `receiveResponderPing`: User received ping from responder
 * - `sendResponderPingResponded`: User responded to responder's ping  
 * - `receiveDependentPingResponded`: User received response from dependent
 * - `sendClearAllResponderPings`: User cleared all received responder pings
 * 
 * ### Contact Management (Low Priority)
 * - `receiveContactAdded/Removed/RoleChanged`: Network changes
 * 
 * ## Key Patterns
 * - Only responders receive notifications about their dependents (alerts, non-responsive)
 * - Features explicitly control when notifications are sent
 * - Type-safe gRPC integration with enum mapping
 * - Local scheduling vs tracked notifications are separate concerns
 */

// MARK: - gRPC Protocol Integration

protocol NotificationServiceProtocol: Sendable {
    func getNotifications(_ request: GetNotificationsRequest) async throws -> GetNotificationsResponse
    func addNotification(_ request: AddNotificationRequest) async throws -> Notification_Proto
    func markAsRead(_ request: MarkNotificationRequest) async throws -> MarkNotificationReadResponse
    func markAllAsRead(_ request: MarkAllNotificationsReadRequest) async throws -> Empty_Proto
    func clearNotificationsByType(_ request: ClearNotificationsByTypeRequest) async throws -> Empty_Proto
    func sendNotification(_ request: SendNotificationRequest) async throws -> Empty_Proto
    func scheduleNotification(_ request: ScheduleNotificationRequest) async throws -> Empty_Proto
    func notifyEmergencyAlertToggled(_ request: NotifyEmergencyAlertRequest) async throws -> Empty_Proto
    func startNotificationStream(_ request: StartNotificationStreamRequest) async throws -> AsyncThrowingStream<NotificationStreamEvent, Error>
}

// MARK: - gRPC Request/Response Types

struct GetNotificationsRequest: Sendable {
    let userId: UUID
    let authToken: String
    let fromDate: Date? // Get notifications from this date (for 30-day window)
    let toDate: Date? // Get notifications until this date
}

struct GetNotificationsResponse: Sendable {
    let notifications: [Notification_Proto]
}

struct AddNotificationRequest: Sendable {
    let userId: UUID
    let type: NotificationType  // Using our type-safe enum
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


struct MarkAllNotificationsReadRequest: Sendable {
    let authToken: String
}

struct ClearNotificationsByTypeRequest: Sendable {
    let type: NotificationType
    let authToken: String
}

struct SendNotificationRequest: Sendable {
    let notification: NotificationItem
    let authToken: String
}

struct ScheduleNotificationRequest: Sendable {
    let notification: NotificationItem
    let delay: TimeInterval
    let authToken: String
}

struct NotifyEmergencyAlertRequest: Sendable {
    let userId: UUID
    let isEmergencyAlertEnabled: Bool
    let authToken: String
}

struct MarkNotificationReadResponse: Sendable {
    let notification: NotificationItem
}

struct StartNotificationStreamRequest: Sendable {
    let userId: UUID
    let loadHistory: Bool
    let historyDays: Int
    let authToken: String
}

struct NotificationStreamEvent: Sendable {
    let type: StreamEventType
    let notifications: [NotificationItem]
    let timestamp: Date
    
    enum StreamEventType: String, Codable, Sendable {
        case initialHistory = "initial_history"
        case realTimeUpdate = "real_time_update"
        case bulkUpdate = "bulk_update"
    }
}


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
        // Emergency alerts (High Priority)
        case sendManualAlertActive = 0              // User activated emergency alert
        case sendManualAlertInactive = 1            // User deactivated emergency alert
        case receiveDependentManualAlertActive = 2  // Dependent activated emergency alert
        case receiveDependentManualAlertInactive = 3 // Dependent deactivated emergency alert
        
        // Non-responsive alerts (High Priority)
        case receiveNonResponsiveAlert = 4          // User missed check-in
        case receiveNonResponsiveDependentAlert = 5 // Dependent missed check-in
        
        // Contact management (Low Priority)
        case receiveContactAdded = 6                // Contact added to network
        case receiveContactRemoved = 7              // Contact removed from network
        case receiveContactRoleChanged = 8          // Contact role changed
        
        // Ping communications (Medium/Low Priority)
        case sendDependentPing = 9                  // User → Dependent ping
        case receiveResponderPing = 10              // User ← Responder ping
        case sendResponderPingResponded = 11        // User → Responder response
        case receiveDependentPingResponded = 12     // User ← Dependent response
        case sendClearAllResponderPings = 13        // User cleared all responder pings
        
        // System notifications
        case receiveSystemNotification = 14         // General system messages
    }
}

// MARK: - Mock gRPC Service

final class MockNotificationService: NotificationServiceProtocol {
    func getNotifications(_ request: GetNotificationsRequest) async throws -> GetNotificationsResponse {
        try await Task.sleep(for: .milliseconds(400))

        // Generate mock notifications for the past 30 days
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let fromDate = request.fromDate ?? thirtyDaysAgo
        let toDate = request.toDate ?? Date()
        
        var mockNotifications: [Notification_Proto] = []
        
        // Generate mock notifications across the date range
        let daysBetween = Calendar.current.dateComponents([.day], from: fromDate, to: toDate).day ?? 0
        
        for dayOffset in 0...min(daysBetween, 30) {
            guard let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: toDate) else { continue }
            
            // Add 1-3 notifications per day
            let notificationCount = Int.random(in: 1...3)
            
            for i in 0..<notificationCount {
                let hourOffset = Double(i * 8) // Spread throughout the day
                let notificationDate = date.addingTimeInterval(-hourOffset * 3600)
                
                let types: [Notification_Proto.Notification_Type] = [.sendManualAlertActive, .receiveDependentManualAlertActive, .receiveResponderPing, .sendDependentPing, .receiveSystemNotification]
                let randomType = types.randomElement() ?? .receiveSystemNotification
                
                let notification = Notification_Proto(
                    id: UUID().uuidString,
                    userID: request.userId.uuidString,
                    type: randomType,
                    title: Self.titleFor(type: randomType),
                    message: Self.messageFor(type: randomType),
                    isRead: Bool.random(),
                    createdAt: Int64(notificationDate.timeIntervalSince1970),
                    contactId: [.receiveResponderPing, .sendDependentPing, .sendResponderPingResponded, .receiveDependentPingResponded].contains(randomType) ? UUID().uuidString : nil,
                    userId: request.userId.uuidString,
                    metadata: [:]
                )
                
                mockNotifications.append(notification)
            }
        }

        return GetNotificationsResponse(notifications: mockNotifications)
    }
    
    private static func titleFor(type: Notification_Proto.Notification_Type) -> String {
        switch type {
        case .sendManualAlertActive: return "Emergency Alert Activated"
        case .sendManualAlertInactive: return "Emergency Alert Deactivated"
        case .receiveDependentManualAlertActive: return "Dependent Emergency Alert"
        case .receiveDependentManualAlertInactive: return "Dependent Alert Resolved"
        case .receiveNonResponsiveAlert: return "Missed Check-in"
        case .receiveNonResponsiveDependentAlert: return "Dependent Non-Responsive"
        case .receiveContactAdded: return "Contact Added"
        case .receiveContactRemoved: return "Contact Removed"
        case .receiveContactRoleChanged: return "Role Changed"
        case .sendDependentPing: return "Ping Sent to Dependent"
        case .receiveResponderPing: return "Ping from Responder"
        case .sendResponderPingResponded: return "Response Sent to Responder"
        case .receiveDependentPingResponded: return "Response from Dependent"
        case .sendClearAllResponderPings: return "Pings Cleared"
        case .receiveSystemNotification: return "System"
        }
    }
    
    private static func messageFor(type: Notification_Proto.Notification_Type) -> String {
        switch type {
        case .sendManualAlertActive: return "Emergency alert has been activated"
        case .sendManualAlertInactive: return "Emergency alert has been deactivated"
        case .receiveDependentManualAlertActive: return "A dependent has activated an emergency alert"
        case .receiveDependentManualAlertInactive: return "A dependent has deactivated their emergency alert"
        case .receiveNonResponsiveAlert: return "You missed your scheduled check-in"
        case .receiveNonResponsiveDependentAlert: return "A dependent hasn't checked in on time"
        case .receiveContactAdded: return "A new contact was added to your network"
        case .receiveContactRemoved: return "A contact was removed from your network"
        case .receiveContactRoleChanged: return "A contact's role has been updated"
        case .sendDependentPing: return "You sent a ping to a dependent"
        case .receiveResponderPing: return "You received a ping from a responder"
        case .sendResponderPingResponded: return "You responded to a responder's ping"
        case .receiveDependentPingResponded: return "Your dependent responded to your ping"
        case .sendClearAllResponderPings: return "All received responder pings have been cleared"
        case .receiveSystemNotification: return "System notification message"
        }
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

    func markAsRead(_ request: MarkNotificationRequest) async throws -> MarkNotificationReadResponse {
        try await Task.sleep(for: .milliseconds(200))
        
        // Mock finding and updating the notification
        let updatedNotification = NotificationItem(
            id: request.notificationId,
            title: "Mock Notification",
            message: "This notification has been marked as read",
            isRead: true
        )
        
        return MarkNotificationReadResponse(notification: updatedNotification)
    }
    
    func markAllAsRead(_ request: MarkAllNotificationsReadRequest) async throws -> Empty_Proto {
        try await Task.sleep(for: .milliseconds(400))
        return Empty_Proto()
    }
    
    func clearNotificationsByType(_ request: ClearNotificationsByTypeRequest) async throws -> Empty_Proto {
        try await Task.sleep(for: .milliseconds(300))
        return Empty_Proto()
    }
    
    func sendNotification(_ request: SendNotificationRequest) async throws -> Empty_Proto {
        try await Task.sleep(for: .milliseconds(250))
        return Empty_Proto()
    }
    
    func scheduleNotification(_ request: ScheduleNotificationRequest) async throws -> Empty_Proto {
        try await Task.sleep(for: .milliseconds(300))
        return Empty_Proto()
    }

    
    func notifyEmergencyAlertToggled(_ request: NotifyEmergencyAlertRequest) async throws -> Empty_Proto {
        try await Task.sleep(for: .milliseconds(800))
        
        // Simulate sending notification to responders about emergency alert status change
        print("[MOCK] Emergency alert toggled for user \(request.userId): \(request.isEmergencyAlertEnabled ? "ENABLED" : "DISABLED")")
        print("[MOCK] Notifying all responders about emergency alert status change...")
        
        return Empty_Proto()
    }
    
    func startNotificationStream(_ request: StartNotificationStreamRequest) async throws -> AsyncThrowingStream<NotificationStreamEvent, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // 1. If history requested, send initial state first
                    if request.loadHistory {
                        try await Task.sleep(for: .milliseconds(500))
                        
                        // Generate initial history (reuse existing logic)
                        let historyRequest = GetNotificationsRequest(
                            userId: request.userId,
                            authToken: request.authToken,
                            fromDate: Calendar.current.date(byAdding: .day, value: -request.historyDays, to: Date()),
                            toDate: Date()
                        )
                        
                        let historyResponse = try await getNotifications(historyRequest)
                        let historyNotifications = historyResponse.notifications.map { $0.toDomain() }
                        
                        // Send initial history as first stream event
                        let initialEvent = NotificationStreamEvent(
                            type: .initialHistory,
                            notifications: historyNotifications.sorted { $0.timestamp > $1.timestamp },
                            timestamp: Date()
                        )
                        continuation.yield(initialEvent)
                    }
                    
                    // 2. Start real-time updates
                    while !Task.isCancelled {
                        try await Task.sleep(for: .seconds(10))
                        
                        // Simulate real-time notification
                        let notification = NotificationItem(
                            title: "Real-time Notification",
                            message: "This is a simulated real-time notification from stream",
                            type: [NotificationType.sendManualAlertActive, .receiveResponderPing, .receiveSystemNotification].randomElement() ?? .receiveSystemNotification
                        )
                        
                        let updateEvent = NotificationStreamEvent(
                            type: .realTimeUpdate,
                            notifications: [notification],
                            timestamp: Date()
                        )
                        continuation.yield(updateEvent)
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
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
        case .sendManualAlertActive: return .sendManualAlertActive
        case .sendManualAlertInactive: return .sendManualAlertInactive
        case .receiveDependentManualAlertActive: return .receiveDependentManualAlertActive
        case .receiveDependentManualAlertInactive: return .receiveDependentManualAlertInactive
        case .receiveNonResponsiveAlert: return .receiveNonResponsiveAlert
        case .receiveNonResponsiveDependentAlert: return .receiveNonResponsiveDependentAlert
        case .receiveContactAdded: return .receiveContactAdded
        case .receiveContactRemoved: return .receiveContactRemoved
        case .receiveContactRoleChanged: return .receiveContactRoleChanged
        case .sendDependentPing: return .sendDependentPing
        case .receiveResponderPing: return .receiveResponderPing
        case .sendResponderPingResponded: return .sendResponderPingResponded
        case .receiveDependentPingResponded: return .receiveDependentPingResponded
        case .sendClearAllResponderPings: return .sendClearAllResponderPings
        case .receiveSystemNotification: return .receiveSystemNotification
        }
    }
}

extension NotificationType {
    func toProto() -> Notification_Proto.Notification_Type {
        switch self {
        case .sendManualAlertActive: return .sendManualAlertActive
        case .sendManualAlertInactive: return .sendManualAlertInactive
        case .receiveDependentManualAlertActive: return .receiveDependentManualAlertActive
        case .receiveDependentManualAlertInactive: return .receiveDependentManualAlertInactive
        case .receiveNonResponsiveAlert: return .receiveNonResponsiveAlert
        case .receiveNonResponsiveDependentAlert: return .receiveNonResponsiveDependentAlert
        case .receiveContactAdded: return .receiveContactAdded
        case .receiveContactRemoved: return .receiveContactRemoved
        case .receiveContactRoleChanged: return .receiveContactRoleChanged
        case .sendDependentPing: return .sendDependentPing
        case .receiveResponderPing: return .receiveResponderPing
        case .sendResponderPingResponded: return .sendResponderPingResponded
        case .receiveDependentPingResponded: return .receiveDependentPingResponded
        case .sendClearAllResponderPings: return .sendClearAllResponderPings
        case .receiveSystemNotification: return .receiveSystemNotification
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
        type: NotificationType = .receiveSystemNotification,
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
    // MARK: - Emergency Alerts (High Priority - Critical)
    case sendManualAlertActive = "send_manual_alert_active"           // User activated emergency alert
    case sendManualAlertInactive = "send_manual_alert_inactive"       // User deactivated emergency alert
    case receiveDependentManualAlertActive = "receive_dependent_manual_alert_active"     // Dependent activated emergency alert
    case receiveDependentManualAlertInactive = "receive_dependent_manual_alert_inactive" // Dependent deactivated emergency alert
    
    // MARK: - Non-Responsive Alerts (High Priority - Critical)
    case receiveNonResponsiveAlert = "receive_non_responsive_alert"                    // User missed check-in
    case receiveNonResponsiveDependentAlert = "receive_non_responsive_dependent_alert" // Dependent missed check-in
    
    // MARK: - Contact Management (Low Priority)
    case receiveContactAdded = "receive_contact_added"                      // Contact added to network
    case receiveContactRemoved = "receive_contact_removed"                  // Contact removed from network  
    case receiveContactRoleChanged = "receive_contact_role_changed"         // Contact role changed
    
    // MARK: - Ping Communications (Medium/Low Priority)
    // Ping lifecycle: User → Contact → Response
    case sendDependentPing = "send_dependent_ping"                       // User sent ping to dependent
    case receiveResponderPing = "receive_responder_ping"               // User received ping from responder
    case sendResponderPingResponded = "send_responder_ping_responded"    // User responded to responder's ping
    case receiveDependentPingResponded = "receive_dependent_ping_responded" // User received response from dependent
    case sendClearAllResponderPings = "send_clear_all_responder_pings"                     // User cleared all received responder pings
    
    // MARK: - System Notifications (Low Priority)
    case receiveSystemNotification = "receive_system_notification"          // General system messages
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .sendManualAlertActive:
            return "Emergency Alert Activated"
        case .sendManualAlertInactive:
            return "Emergency Alert Deactivated"
        case .receiveDependentManualAlertActive:
            return "Dependent Emergency Alert"
        case .receiveDependentManualAlertInactive:
            return "Dependent Alert Resolved"
        case .receiveNonResponsiveAlert:
            return "Missed Check-in"
        case .receiveNonResponsiveDependentAlert:
            return "Dependent Non-Responsive"
        case .receiveContactAdded:
            return "Contact Added"
        case .receiveContactRemoved:
            return "Contact Removed"
        case .receiveContactRoleChanged:
            return "Role Changed"
        case .sendDependentPing:
            return "Ping Sent to Dependent"
        case .receiveResponderPing:
            return "Ping from Responder"
        case .sendResponderPingResponded:
            return "Response Sent to Responder"
        case .receiveDependentPingResponded:
            return "Response from Dependent"
        case .sendClearAllResponderPings:
            return "Pings Cleared"
        case .receiveSystemNotification:
            return "System"
        }
    }
    
    var title: String {
        return displayName
    }
    
    var priority: NotificationPriority {
        switch self {
        case .sendManualAlertActive, .receiveDependentManualAlertActive, .receiveNonResponsiveAlert, .receiveNonResponsiveDependentAlert:
            return .high
        case .sendManualAlertInactive, .receiveDependentManualAlertInactive, .receiveResponderPing, .sendResponderPingResponded:
            return .medium
        case .receiveContactAdded, .receiveContactRemoved, .receiveContactRoleChanged, .sendDependentPing, .receiveDependentPingResponded, .sendClearAllResponderPings, .receiveSystemNotification:
            return .low
        }
    }
    
    var sound: UNNotificationSound {
        switch self {
        case .sendManualAlertActive, .receiveDependentManualAlertActive, .receiveNonResponsiveAlert, .receiveNonResponsiveDependentAlert:
            return .defaultCritical
        default:
            return .default
        }
    }
    
    // MARK: - Notification Categories
    
    /// Indicates if this notification type represents an emergency situation
    var isEmergency: Bool {
        switch self {
        case .sendManualAlertActive, .receiveDependentManualAlertActive, .receiveNonResponsiveAlert, .receiveNonResponsiveDependentAlert:
            return true
        default:
            return false
        }
    }
    
    /// Indicates if this notification type is related to ping communications
    var isPingRelated: Bool {
        switch self {
        case .sendDependentPing, .receiveResponderPing, .sendResponderPingResponded, .receiveDependentPingResponded, .sendClearAllResponderPings:
            return true
        default:
            return false
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

// MARK: - NotificationClient Internal Helpers

extension NotificationClient {
    /// Gets the authenticated user info for NotificationClient operations
    private static func getAuthenticatedUserInfo() async throws -> (token: String, user: User) {
        @Shared(.authenticationToken) var authToken
        @Shared(.currentUser) var currentUser
        
        guard let token = authToken else {
            throw NotificationClientError.saveFailed("No authentication token available")
        }
        
        guard let user = currentUser else {
            throw NotificationClientError.saveFailed("No current user available")
        }
        
        return (token: token, user: user)
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
        @Shared(.isNetworkConnected) var isConnected
        
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
    
    // MARK: - Centralized State Management
    
    /// Initializes the notification client, requests permissions
    var initialize: @Sendable () async throws -> Void = { }
    
    /// Starts listening for real-time notifications and loads initial history (combined operation)
    var startListening: @Sendable () async throws -> Void = { }
    
    /// Stops listening for real-time notifications
    var stopListening: @Sendable () async throws -> Void = { }
    
    /// Cleanup method called when session ends
    var cleanup: @Sendable () async throws -> Void = { }
    
    // Core notification operations
    var scheduleNotification: @Sendable (NotificationItem, TimeInterval) async throws -> String = { _, _ in "" }
    
    // Notification scheduling (for local notifications)
    var cancelScheduledNotification: @Sendable (String) async throws -> Void = { _ in }
    
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
    
    // Emergency Alert operations
    var notifyEmergencyAlertToggled: @Sendable (UUID, Bool) async throws -> Void = { _, _ in throw NotificationClientError.saveFailed("Operation failed") }
    
    // Ping management operations
    var clearAllReceivedPings: @Sendable () async throws -> Void = { }
    var clearSentPing: @Sendable (UUID) async throws -> Void = { _ in }
    
    // Contact notification operations
    var notifyContactAdded: @Sendable (UUID) async throws -> Void = { _ in }
    var notifyContactRemoved: @Sendable (UUID) async throws -> Void = { _ in }
    var notifyContactRoleChanged: @Sendable (UUID) async throws -> Void = { _ in }
    
    // Ping notification methods (explicit feature-driven)
    var sendPingNotification: @Sendable (NotificationType, String, String, UUID) async throws -> Void = { _, _, _, _ in throw NotificationClientError.saveFailed("Operation failed") }
    
    // Local device scheduling (not tracked in history)
    var scheduleLocalCheckInReminder: @Sendable (Date, String) async throws -> Void = { _, _ in }
    
    // System notification method for local feedback (not tracked in persistent history)
    var sendSystemNotification: @Sendable (String, String) async throws -> Void = { _, _ in }
    
}

extension NotificationClient: DependencyKey {
    static let liveValue = NotificationClient()
    static let testValue = NotificationClient()
    
    static let mockValue = NotificationClient(
        notificationService: MockNotificationService(),
        
        // MARK: - Centralized State Management Implementation
        
        initialize: {
            // Request notification permissions
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert])
            
            // Set up notification delegate
            let delegate = NotificationDelegate()
            UNUserNotificationCenter.current().delegate = delegate
            
            // Stream setup with initial history load is handled in startListening()
        },
        
        startListening: {
            let authInfo = try await Self.getAuthenticatedUserInfo()
            let service = MockNotificationService()
            
            // Combined operation: Setup stream + load initial history
            let streamRequest = StartNotificationStreamRequest(
                userId: authInfo.user.id,
                loadHistory: true,
                historyDays: 30,
                authToken: authInfo.token
            )
            
            let stream = try await service.startNotificationStream(streamRequest)
            
            // Handle both initial history and real-time updates through single stream
            Task {
                for try await event in stream {
                    @Shared(.notifications) var notifications
                    @Shared(.unreadNotificationCount) var unreadCount
                    
                    switch event.type {
                    case .initialHistory:
                        // Bulk load initial state
                        $notifications.withLock { $0 = event.notifications }
                        $unreadCount.withLock { $0 = event.notifications.filter { !$0.isRead }.count }
                        print("[STREAM] Loaded \(event.notifications.count) historical notifications")
                        
                    case .realTimeUpdate:
                        // Single notification updates
                        for notification in event.notifications {
                            $notifications.withLock { $0.insert(notification, at: 0) }
                            if !notification.isRead {
                                $unreadCount.withLock { $0 += 1 }
                            }
                        }
                        print("[STREAM] Received \(event.notifications.count) real-time notification(s)")
                        
                    case .bulkUpdate:
                        // Server-initiated bulk changes (e.g., mark all as read, clear by type)
                        for notification in event.notifications {
                            $notifications.withLock { notifications in
                                if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                                    notifications[index] = notification
                                } else {
                                    notifications.insert(notification, at: 0)
                                }
                            }
                        }
                        $unreadCount.withLock { $0 = notifications.filter { !$0.isRead }.count }
                        print("[STREAM] Applied \(event.notifications.count) bulk update(s)")
                    }
                }
            }
        },
        
        stopListening: {
            // Stop Firebase listener and cancel background tasks
        },
        
        cleanup: {
            // Stop listening - mock implementation doesn't need cleanup
            
            // Clear shared state
            @Shared(.notifications) var notifications
            @Shared(.unreadNotificationCount) var unreadCount
            
            $notifications.withLock { $0.removeAll() }
            $unreadCount.withLock { $0 = 0 }
            
            // Cancel all pending local notifications
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        },
        
        
        
        
        
        scheduleNotification: { notification, delay in
            let authInfo = try await Self.getAuthenticatedUserInfo()
            let service = MockNotificationService()
            
            var newNotification = notification
            newNotification.timestamp = Date().addingTimeInterval(delay)
            
            let scheduleRequest = ScheduleNotificationRequest(notification: newNotification, delay: delay, authToken: authInfo.token)
            _ = try await service.scheduleNotification(scheduleRequest)
            
            // Stream will handle updating shared state
            
            // Always schedule device notification
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
                "metadata": notification.metadata,
                "isSystemNotification": notification.type == .receiveSystemNotification
            ]

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            let request = UNNotificationRequest(
                identifier: notification.id.uuidString,
                content: content,
                trigger: trigger
            )

            try await UNUserNotificationCenter.current().add(request)
            
            // For system notifications, schedule removal after showing
            if notification.type == .receiveSystemNotification {
                Task {
                    try? await Task.sleep(for: .seconds(delay + 3))
                    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notification.id.uuidString])
                }
            }
            
            return notification.id.uuidString
        },
        
        
        cancelScheduledNotification: { identifier in
            // Simulate delay
            try await Task.sleep(for: .milliseconds(150))
            // Mock cancellation always succeeds
        },
        
        
        requestPermission: {
            // Mock always grants permission
            return true
        },
        
        getNotificationSettings: {
            await UNUserNotificationCenter.current().notificationSettings()
        },
        
        // FCM Token management for remote notifications - Independent implementation
        registerFCMToken: { token in
            // Independent mock implementation for NotificationClient
            print("🔔 [NotificationClient MOCK] FCM Token registered: \(String(token.prefix(20)))...")
        },
        
        getFCMToken: {
            // Independent mock FCM token for NotificationClient
            return "notification_fcm_token_\(UUID().uuidString)"
        },
        
        clearFCMToken: {
            // Independent mock implementation for NotificationClient
            print("🔔 [NotificationClient MOCK] FCM Token cleared successfully")
        },
        
        refreshFCMToken: {
            // Independent mock implementation - generates new FCM token for NotificationClient
            let newToken = "notification_fcm_token_\(UUID().uuidString)"
            print("🔔 [NotificationClient MOCK] FCM Token refreshed: \(String(newToken.prefix(20)))...")
            return newToken
        },
        
        // Emergency Alert operations
        notifyEmergencyAlertToggled: { userId, isEmergencyAlertEnabled in
            let authInfo = try await Self.getAuthenticatedUserInfo()
            let service = MockNotificationService()
            
            // Notify responders about emergency alert status change
            let notifyRequest = NotifyEmergencyAlertRequest(
                userId: userId,
                isEmergencyAlertEnabled: isEmergencyAlertEnabled,
                authToken: authInfo.token
            )
            _ = try await service.notifyEmergencyAlertToggled(notifyRequest)
            
            // Send emergency alert state notification to user's history
            let alertType: NotificationType = isEmergencyAlertEnabled ? .sendManualAlertActive : .sendManualAlertInactive
            let title = isEmergencyAlertEnabled ? "Emergency Alert Activated" : "Emergency Alert Deactivated"
            let message = isEmergencyAlertEnabled ? "Your emergency alert has been activated" : "Your emergency alert has been deactivated"
            
            // Create notification for emergency alert state change via gRPC
            let notification = NotificationItem(
                title: title,
                message: message,
                type: alertType
            )
            
            let addNotificationRequest = AddNotificationRequest(
                userId: userId,
                type: alertType,
                title: title,
                message: message,
                contactId: nil,
                metadata: [:],
                authToken: authInfo.token
            )
            _ = try await service.addNotification(addNotificationRequest)
            
            // Stream will handle updating shared state
        },
        
        // Ping management operations
        clearAllReceivedPings: {
            let authInfo = try await Self.getAuthenticatedUserInfo()
            
            // Single gRPC call to clear all received pings
            // Server handles: 1) Sending acknowledgments to responders, 2) Clearing pings, 3) Updating notification history
            let service = MockNotificationService()
            let clearRequest = AddNotificationRequest(
                userId: authInfo.user.id,
                type: .sendClearAllResponderPings,
                title: "Clear All Received Pings",
                message: "User requested to clear all received responder pings",
                contactId: nil,
                metadata: ["action": "clear_all_received_pings"],
                authToken: authInfo.token
            )
            _ = try await service.addNotification(clearRequest)
            
            // Server handles all processing atomically:
            // 1. Server identifies who sent pings and sends them acknowledgment notifications
            // 2. Server clears user's received ping notifications  
            // 3. Server adds clear action to user's notification history
            // 4. Server streams all updates back to clients
            //
            // Stream will handle updating all shared state - no direct manipulation here
        },
        
        clearSentPing: { contactId in
            let authInfo = try await Self.getAuthenticatedUserInfo()
            let service = MockNotificationService()
            
            // Single gRPC call to clear sent ping to specific contact
            // Server handles: 1) Removing ping from contact's received pings, 2) Updating user's sent ping history
            let clearRequest = AddNotificationRequest(
                userId: authInfo.user.id,
                type: .sendClearAllResponderPings, // Reuse existing type or create new one for single ping
                title: "Ping Retracted",
                message: "You retracted a ping sent to a contact",
                contactId: contactId,
                metadata: ["action": "clear_sent_ping", "target_contact": contactId.uuidString],
                authToken: authInfo.token
            )
            _ = try await service.addNotification(clearRequest)
            
            // Server handles all processing atomically:
            // 1. Server removes the ping from the contact's received pings
            // 2. Server adds retraction to user's notification history
            // 3. Server notifies the contact that the ping was retracted
            // 4. Server streams all updates back to clients
            //
            // Stream will handle updating all shared state - no direct manipulation here
        },
        
        // Contact notification operations
        notifyContactAdded: { contactId in
            let authInfo = try await Self.getAuthenticatedUserInfo()
            let service = MockNotificationService()
            
            let request = AddNotificationRequest(
                userId: authInfo.user.id,
                type: .receiveContactAdded,
                title: "Contact Added",
                message: "A new contact was added to your network",
                contactId: contactId,
                metadata: ["action": "contact_added"],
                authToken: authInfo.token
            )
            
            _ = try await service.addNotification(request)
            // Stream will handle updating shared state
        },
        
        notifyContactRemoved: { contactId in
            let authInfo = try await Self.getAuthenticatedUserInfo()
            let service = MockNotificationService()
            
            let request = AddNotificationRequest(
                userId: authInfo.user.id,
                type: .receiveContactRemoved,
                title: "Contact Removed",
                message: "A contact was removed from your network",
                contactId: contactId,
                metadata: ["action": "contact_removed"],
                authToken: authInfo.token
            )
            
            _ = try await service.addNotification(request)
            // Stream will handle updating shared state
        },
        
        notifyContactRoleChanged: { contactId in
            let authInfo = try await Self.getAuthenticatedUserInfo()
            let service = MockNotificationService()
            
            let request = AddNotificationRequest(
                userId: authInfo.user.id,
                type: .receiveContactRoleChanged,
                title: "Role Changed",
                message: "A contact's role has been updated",
                contactId: contactId,
                metadata: ["action": "role_changed"],
                authToken: authInfo.token
            )
            
            _ = try await service.addNotification(request)
            // Stream will handle updating shared state
        },
        
        // Ping notification methods (explicit feature-driven)
        sendPingNotification: { notificationType, title, message, contactId in
            let authInfo = try await Self.getAuthenticatedUserInfo()
            
            // Send gRPC notification for ping operations and track in user's history
            let service = MockNotificationService()
            let request = AddNotificationRequest(
                userId: authInfo.user.id,
                type: notificationType,
                title: title,
                message: message,
                contactId: contactId,
                metadata: ["ping": "true"],
                authToken: authInfo.token
            )
            
            _ = try await service.addNotification(request)
            
            // Stream will handle updating shared state for all ping notifications
        },
        
        // Local device scheduling (not tracked in history)
        scheduleLocalCheckInReminder: { date, message in
            // Create local check-in reminder notification
            let content = UNMutableNotificationContent()
            content.title = "Check-in Reminder"
            content.body = message
            content.sound = .default
            content.userInfo = ["isLocalReminder": true]
            
            // Schedule local notification without adding to history
            let timeInterval = date.timeIntervalSinceNow
            if timeInterval > 0 {
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "checkin_reminder_\(UUID().uuidString)",
                    content: content,
                    trigger: trigger
                )
                
                try await UNUserNotificationCenter.current().add(request)
            }
        },
        
        // System notification method for local feedback (shows immediately, not tracked in persistent history)
        sendSystemNotification: { title, message in
            // Create immediate local system notification for user feedback
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = message
            content.sound = .none
            content.userInfo = [
                "notification_id": UUID().uuidString,
                "type": NotificationType.receiveSystemNotification.rawValue,
                "timestamp": Date().timeIntervalSince1970,
                "isSystemNotification": true,
                "isTemporary": true  // Mark as temporary so it doesn't persist
            ]
            
            // Schedule immediate notification
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "system_notification_\(UUID().uuidString)",
                content: content,
                trigger: trigger
            )
            
            try await UNUserNotificationCenter.current().add(request)
            
            // Auto-remove after 3 seconds to keep notification center clean
            Task {
                try? await Task.sleep(for: .seconds(3))
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [request.identifier])
            }
        }
        
    )
}

extension DependencyValues {
    var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}