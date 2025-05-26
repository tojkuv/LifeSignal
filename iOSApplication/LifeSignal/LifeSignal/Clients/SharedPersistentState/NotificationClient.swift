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
    func markAsRead(_ request: MarkNotificationRequest) async throws -> Empty_Proto
    func notifyEmergencyAlertToggled(_ request: NotifyEmergencyAlertRequest) async throws -> Empty_Proto
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


struct NotifyEmergencyAlertRequest: Sendable {
    let userId: UUID
    let isEmergencyAlertEnabled: Bool
    let authToken: String
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

    func markAsRead(_ request: MarkNotificationRequest) async throws -> Empty_Proto {
        try await Task.sleep(for: .milliseconds(200))
        return Empty_Proto()
    }

    
    func notifyEmergencyAlertToggled(_ request: NotifyEmergencyAlertRequest) async throws -> Empty_Proto {
        try await Task.sleep(for: .milliseconds(800))
        
        // Simulate sending notification to responders about emergency alert status change
        print("[MOCK] Emergency alert toggled for user \(request.userId): \(request.isEmergencyAlertEnabled ? "ENABLED" : "DISABLED")")
        print("[MOCK] Notifying all responders about emergency alert status change...")
        
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
    
    /// Initializes the notification client, requests permissions, and loads 30 days of notifications
    var initialize: @Sendable () async throws -> Void = { }
    
    /// Loads the past 30 days of notifications from server and updates shared state
    var loadNotificationHistory: @Sendable () async throws -> Void = { }
    
    /// Starts listening for real-time notifications (Firebase stream)
    var startListening: @Sendable () async throws -> Void = { }
    
    /// Stops listening for real-time notifications
    var stopListening: @Sendable () async throws -> Void = { }
    
    /// Cleanup method called when session ends
    var cleanup: @Sendable () async throws -> Void = { }
    
    // CRUD operations that sync with shared state
    var getNotifications: @Sendable () async -> [NotificationItem] = { [] }
    var getNotification: @Sendable (UUID) async throws -> NotificationItem? = { _ in nil }
    var addNotification: @Sendable (NotificationItem) async throws -> NotificationItem = { notification in notification }
    var updateNotification: @Sendable (NotificationItem) async throws -> NotificationItem = { notification in notification }
    
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
    
    // Notification scheduling (for local notifications) - moved to ephemeral section
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
    
    // Emergency Alert operations
    var notifyEmergencyAlertToggled: @Sendable (UUID, Bool) async throws -> Void = { _, _ in throw NotificationClientError.saveFailed("Operation failed") }
    
    // Ping management operations
    var clearAllReceivedPings: @Sendable () async throws -> Void = { }
    
    // Contact notification broadcasting
    var sendContactNotification: @Sendable (NotificationType, String, String, UUID?) async throws -> Void = { _, _, _, _ in throw NotificationClientError.saveFailed("Operation failed") }
    
    // Ping notification methods (explicit feature-driven)
    var sendPingNotification: @Sendable (NotificationType, String, String, UUID) async throws -> Void = { _, _, _, _ in throw NotificationClientError.saveFailed("Operation failed") }
    
    // Local device scheduling (not tracked in history)
    var scheduleLocalCheckInReminder: @Sendable (Date, String) async throws -> Void = { _, _ in }
    
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
            
            // Load 30 days of notification history - handled in mockValue.loadNotificationHistory
            
            // Start listening for real-time notifications - handled in mockValue.startListening
        },
        
        loadNotificationHistory: {
            let authInfo = try await Self.getAuthenticatedUserInfo()
            let service = MockNotificationService()
            
            // Get notifications from past 30 days
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            let request = GetNotificationsRequest(
                userId: authInfo.user.id,
                authToken: authInfo.token,
                fromDate: thirtyDaysAgo,
                toDate: Date()
            )
            
            let response = try await service.getNotifications(request)
            let notifications = response.notifications.map { $0.toDomain() }
            
            // Update shared state with fetched notifications
            @Shared(.notifications) var sharedNotifications
            @Shared(.unreadNotificationCount) var unreadCount
            
            $sharedNotifications.withLock { $0 = notifications.sorted { $0.timestamp > $1.timestamp } }
            $unreadCount.withLock { $0 = notifications.filter { !$0.isRead }.count }
        },
        
        startListening: {
            // Mock Firebase real-time listener for notifications
            // In production, this would connect to Firebase Firestore or FCM stream
            Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(10))
                    
                    // Simulate receiving a real-time notification
                    let notification = NotificationItem(
                        title: "Real-time Notification",
                        message: "This is a simulated real-time notification",
                        type: [NotificationType.sendManualAlertActive, .receiveResponderPing, .receiveSystemNotification].randomElement() ?? .receiveSystemNotification
                    )
                    
                    // Add to shared state
                    @Shared(.notifications) var notifications
                    @Shared(.unreadNotificationCount) var unreadCount
                    
                    $notifications.withLock { $0.insert(notification, at: 0) }
                    $unreadCount.withLock { $0 += 1 }
                    
                    // Send local notification
                    // Notification already added to shared state above
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
            let authInfo = try await Self.getAuthenticatedUserInfo()
            let service = MockNotificationService()
            
            let request = AddNotificationRequest(
                userId: authInfo.user.id,
                type: notification.type,
                title: notification.title,
                message: notification.message,
                contactId: notification.contactId,
                metadata: notification.metadata,
                authToken: authInfo.token
            )
            
            let notificationProto = try await service.addNotification(request)
            let newNotification = notificationProto.toDomain()
            
            @Shared(.notifications) var notifications
            @Shared(.unreadNotificationCount) var unreadCount
            
            $notifications.withLock { $0.insert(newNotification, at: 0) } // Insert at beginning for newest first
            
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
        
        
        markAsRead: { notificationId in
            let authInfo = try await Self.getAuthenticatedUserInfo()
            let service = MockNotificationService()
            
            let request = MarkNotificationRequest(notificationId: notificationId, authToken: authInfo.token)
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
        
        sendNotification: { notification in
            // Add to shared state for app notification center
            @Shared(.notifications) var notifications
            @Shared(.unreadNotificationCount) var unreadCount
            
            var newNotification = notification
            newNotification.timestamp = Date()
            $notifications.withLock { $0.insert(newNotification, at: 0) }
            
            // Update unread count
            $unreadCount.withLock { $0 = notifications.filter { !$0.isRead }.count }
            
            // Always send to device for immediate display
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

            let request = UNNotificationRequest(
                identifier: notification.id.uuidString,
                content: content,
                trigger: nil
            )

            try await UNUserNotificationCenter.current().add(request)
            
            // For system notifications, remove from delivered notifications after showing
            if notification.type == .receiveSystemNotification {
                // Remove after a short delay to allow it to be displayed first
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notification.id.uuidString])
                }
            }
        },
        
        scheduleNotification: { notification, delay in
            // Add to shared state for app notification center
            @Shared(.notifications) var notifications
            @Shared(.unreadNotificationCount) var unreadCount
            
            var newNotification = notification
            newNotification.timestamp = Date().addingTimeInterval(delay)
            $notifications.withLock { $0.insert(newNotification, at: 0) }
            
            // Update unread count
            $unreadCount.withLock { $0 = notifications.filter { !$0.isRead }.count }
            
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
        
        getPendingNotifications: {
            @Shared(.notifications) var notifications
            // Return future notifications
            return notifications.filter { $0.timestamp > Date() }
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
            
            // Create notification for emergency alert state change
            let notification = NotificationItem(
                title: title,
                message: message,
                type: alertType
            )
            
            @Shared(.notifications) var notifications
            @Shared(.unreadNotificationCount) var unreadCount
            $notifications.withLock { $0.insert(notification, at: 0) }
            $unreadCount.withLock { $0 += 1 }
        },
        
        // Ping management operations
        clearAllReceivedPings: {
            let authInfo = try await Self.getAuthenticatedUserInfo()
            
            // Clear all received pings from shared state
            @Shared(.notifications) var notifications
            $notifications.withLock { 
                $0.removeAll { $0.type == .receiveResponderPing }
            }
            
            // Send clear all pings notification
            let notification = NotificationItem(
                title: "Pings Cleared",
                message: "All received pings have been cleared",
                type: .sendClearAllResponderPings
            )
            
            // Add clear action to history
            $notifications.withLock { $0.insert(notification, at: 0) }
            
            // Update unread count
            @Shared(.unreadNotificationCount) var unreadCount
            $unreadCount.withLock { $0 = notifications.filter { !$0.isRead }.count }
        },
        
        // Contact notification broadcasting 
        sendContactNotification: { notificationType, title, message, contactId in
            let authInfo = try await Self.getAuthenticatedUserInfo()
            
            // Create notification for the current user
            let notification = NotificationItem(
                title: title,
                message: message,
                type: notificationType,
                contactId: contactId
            )
            
            // All notification types are tracked in history
            @Shared(.notifications) var notifications
            @Shared(.unreadNotificationCount) var unreadCount
            
            $notifications.withLock { $0.insert(notification, at: 0) }
            $unreadCount.withLock { $0 = notifications.filter { !$0.isRead }.count }
            
            // Send gRPC notification to affected contacts
            let service = MockNotificationService()
            let request = AddNotificationRequest(
                userId: authInfo.user.id,
                type: notificationType,
                title: title,
                message: message,
                contactId: contactId,
                metadata: ["broadcast": "true"],
                authToken: authInfo.token
            )
            
            _ = try await service.addNotification(request)
        },
        
        // Ping notification methods (explicit feature-driven)
        sendPingNotification: { notificationType, title, message, contactId in
            let authInfo = try await Self.getAuthenticatedUserInfo()
            
            // Create notification for ping tracking
            let notification = NotificationItem(
                title: title,
                message: message,
                type: notificationType,
                contactId: contactId
            )
            
            // Ping notifications are always tracked in history
            @Shared(.notifications) var notifications
            @Shared(.unreadNotificationCount) var unreadCount
            
            $notifications.withLock { $0.insert(notification, at: 0) }
            $unreadCount.withLock { $0 = notifications.filter { !$0.isRead }.count }
            
            // Send gRPC notification for ping operations
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
            
            // Send local notification to user's device (only for received pings)
            if [.receiveResponderPing, .sendResponderPingResponded].contains(notificationType) {
                // Add notification to shared state
            @Shared(.notifications) var notifications
            @Shared(.unreadNotificationCount) var unreadCount
            $notifications.withLock { $0.insert(notification, at: 0) }
            $unreadCount.withLock { $0 += 1 }
            }
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
        }
        
    )
}

extension DependencyValues {
    var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}