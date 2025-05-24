import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation

// MARK: - Generated gRPC Proto Types

struct User_Proto: Sendable {
    var id: String
    var name: String
    var phoneNumber: String
    var phoneRegion: String
    var emergencyNote: String
    var checkInInterval: Int64
    var lastCheckedIn: Int64?
    var isNotificationsEnabled: Bool
    var notify30MinBefore: Bool
    var notify2HoursBefore: Bool
    var qrCodeId: String
    var avatarURL: String
    var lastModified: Int64
}

struct Contact_Proto: Sendable {
    var id: String
    var name: String
    var phoneNumber: String
    var isResponder: Bool
    var isDependent: Bool
    var lastUpdated: Int64
    var emergencyNote: String
    var lastCheckInTime: Int64?
    var interval: Int64
    var hasIncomingPing: Bool
    var hasOutgoingPing: Bool
    var manualAlertActive: Bool
    var incomingPingTimestamp: Int64?
    var outgoingPingTimestamp: Int64?
    var manualAlertTimestamp: Int64?
}

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
        case manualAlert = 7
        case nonResponsive = 8
        case contactAdded = 9
        case contactRemoved = 10
        case contactRoleChanged = 11
        case qrCodeNotification = 12
        case alertCancelled = 13
    }
}

// MARK: - Protocol Definitions

protocol UserServiceProtocol: Sendable {
  func getUser(_ request: GetUserRequest) async throws -> User_Proto
  func createUser(_ request: CreateUserRequest) async throws -> User_Proto
  func updateUser(_ request: UpdateUserRequest) async throws -> User_Proto
  func deleteUser(_ request: DeleteUserRequest) async throws -> Empty_Proto
  func uploadAvatar(_ request: UploadAvatarRequest) async throws -> UploadAvatarResponse
}

protocol ContactServiceProtocol: Sendable {
  func getContacts(_ request: GetContactsRequest) async throws -> GetContactsResponse
  func addContact(_ request: AddContactRequest) async throws -> Contact_Proto
  func updateContact(_ request: UpdateContactRequest) async throws -> Contact_Proto
  func removeContact(_ request: RemoveContactRequest) async throws -> Empty_Proto
  func streamContactUpdates(_ request: StreamContactUpdatesRequest) -> AsyncStream<Contact_Proto>
}

protocol NotificationServiceProtocol: Sendable {
  func getNotifications(_ request: GetNotificationsRequest) async throws -> GetNotificationsResponse
  func addNotification(_ request: AddNotificationRequest) async throws -> Notification_Proto
  func markAsRead(_ request: MarkNotificationRequest) async throws -> Empty_Proto
  func deleteNotification(_ request: DeleteNotificationRequest) async throws -> Empty_Proto
  func clearAllNotifications(_ request: ClearAllNotificationsRequest) async throws -> Empty_Proto
}

// MARK: - Request/Response Types

struct GetUserRequest: Sendable {
    let uid: String
}

struct CreateUserRequest: Sendable {
    let uid: String
    let name: String
    let phoneNumber: String
    let phoneRegion: String
    let isNotificationsEnabled: Bool
    let notify30MinBefore: Bool
    let notify2HoursBefore: Bool
}

struct UpdateUserRequest: Sendable {
    let id: UUID
    let name: String
    let phoneNumber: String
    let phoneRegion: String
    let emergencyNote: String
    let checkInInterval: TimeInterval
    let isNotificationsEnabled: Bool
    let notify30MinBefore: Bool
    let notify2HoursBefore: Bool
    let avatarURL: String
}

struct DeleteUserRequest: Sendable {
    let userId: UUID
}

struct UploadAvatarRequest: Sendable {
    let userId: UUID
    let imageData: Data
}

struct UploadAvatarResponse: Sendable {
    let url: String
}

struct GetContactsRequest: Sendable {
    let userId: UUID
}

struct GetContactsResponse: Sendable {
    let contacts: [Contact_Proto]
}

struct AddContactRequest: Sendable {
    let userId: UUID
    let phoneNumber: String
    let name: String
    let isResponder: Bool
    let isDependent: Bool
}

struct UpdateContactRequest: Sendable {
    let contactId: UUID
    let name: String?
    let isResponder: Bool?
    let isDependent: Bool?
    let emergencyNote: String?
    let interval: TimeInterval?
    let hasIncomingPing: Bool?
    let hasOutgoingPing: Bool?
    let manualAlertActive: Bool?
}

struct RemoveContactRequest: Sendable {
    let contactId: UUID
}

struct StreamContactUpdatesRequest: Sendable {
    let userId: UUID
}

struct GetNotificationsRequest: Sendable {
    let userId: UUID
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
}

struct MarkNotificationRequest: Sendable {
    let notificationId: UUID
}

struct DeleteNotificationRequest: Sendable {
    let notificationId: UUID
}

struct ClearAllNotificationsRequest: Sendable {
    let userId: UUID
}

struct Empty_Proto: Sendable {}

// MARK: - Mapping Extensions

extension User_Proto {
    func toDomain() -> User {
        User(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            phoneNumber: phoneNumber,
            phoneRegion: phoneRegion,
            emergencyNote: emergencyNote,
            checkInInterval: TimeInterval(checkInInterval),
            lastCheckedIn: lastCheckedIn.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            isNotificationsEnabled: isNotificationsEnabled,
            notify30MinBefore: notify30MinBefore,
            notify2HoursBefore: notify2HoursBefore,
            qrCodeId: UUID(uuidString: qrCodeId) ?? UUID(),
            avatarURL: avatarURL.isEmpty ? nil : avatarURL,
            avatarImageData: nil, // Avatar data is handled separately
            lastModified: Date(timeIntervalSince1970: TimeInterval(lastModified))
        )
    }
}

extension User {
    func toProto() -> User_Proto {
        User_Proto(
            id: id.uuidString,
            name: name,
            phoneNumber: phoneNumber,
            phoneRegion: phoneRegion,
            emergencyNote: emergencyNote,
            checkInInterval: Int64(checkInInterval),
            lastCheckedIn: lastCheckedIn.map { Int64($0.timeIntervalSince1970) },
            isNotificationsEnabled: isNotificationsEnabled,
            notify30MinBefore: notify30MinBefore,
            notify2HoursBefore: notify2HoursBefore,
            qrCodeId: qrCodeId.uuidString,
            avatarURL: avatarURL ?? "",
            lastModified: Int64(lastModified.timeIntervalSince1970)
        )
    }
}

extension Contact_Proto {
    func toDomain() -> Contact {
        Contact(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            phoneNumber: phoneNumber,
            isResponder: isResponder,
            isDependent: isDependent,
            lastUpdated: Date(timeIntervalSince1970: TimeInterval(lastUpdated)),
            emergencyNote: emergencyNote,
            lastCheckInTime: lastCheckInTime.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            interval: TimeInterval(interval),
            hasIncomingPing: hasIncomingPing,
            hasOutgoingPing: hasOutgoingPing,
            manualAlertActive: manualAlertActive,
            incomingPingTimestamp: incomingPingTimestamp.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            outgoingPingTimestamp: outgoingPingTimestamp.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            manualAlertTimestamp: manualAlertTimestamp.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        )
    }
}

extension Contact {
    func toProto() -> Contact_Proto {
        Contact_Proto(
            id: id.uuidString,
            name: name,
            phoneNumber: phoneNumber,
            isResponder: isResponder,
            isDependent: isDependent,
            lastUpdated: Int64(lastUpdated.timeIntervalSince1970),
            emergencyNote: emergencyNote,
            lastCheckInTime: lastCheckInTime.map { Int64($0.timeIntervalSince1970) },
            interval: Int64(interval),
            hasIncomingPing: hasIncomingPing,
            hasOutgoingPing: hasOutgoingPing,
            manualAlertActive: manualAlertActive,
            incomingPingTimestamp: incomingPingTimestamp.map { Int64($0.timeIntervalSince1970) },
            outgoingPingTimestamp: outgoingPingTimestamp.map { Int64($0.timeIntervalSince1970) },
            manualAlertTimestamp: manualAlertTimestamp.map { Int64($0.timeIntervalSince1970) }
        )
    }
}

extension Notification_Proto {
    func toDomain() -> NotificationItem {
        NotificationItem(
            id: UUID(uuidString: id) ?? UUID(),
            type: type.toDomain(),
            title: title,
            message: message,
            isRead: isRead,
            timestamp: Date(timeIntervalSince1970: TimeInterval(createdAt)),
            contactId: contactId.flatMap { UUID(uuidString: $0) },
            userId: userId.flatMap { UUID(uuidString: $0) },
            metadata: metadata
        )
    }
}

extension NotificationItem {
    func toProto() -> Notification_Proto {
        Notification_Proto(
            id: id.uuidString,
            userID: userId?.uuidString ?? "",
            type: type.toProto(),
            title: title,
            message: message,
            isRead: isRead,
            createdAt: Int64(timestamp.timeIntervalSince1970),
            contactId: contactId?.uuidString,
            userId: userId?.uuidString,
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
        case .manualAlert: return .manualAlert
        case .nonResponsive: return .nonResponsive
        case .contactAdded: return .contactAdded
        case .contactRemoved: return .contactRemoved
        case .contactRoleChanged: return .contactRoleChanged
        case .qrCodeNotification: return .qrCodeNotification
        case .alertCancelled: return .alertCancelled
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
        case .manualAlert: return .manualAlert
        case .nonResponsive: return .nonResponsive
        case .contactAdded: return .contactAdded
        case .contactRemoved: return .contactRemoved
        case .contactRoleChanged: return .contactRoleChanged
        case .qrCodeNotification: return .qrCodeNotification
        case .alertCancelled: return .alertCancelled
        }
    }
}

// MARK: - gRPC Client

@DependencyClient
struct GRPCClient {
    var userService: UserServiceProtocol
    var contactService: ContactServiceProtocol
    var notificationService: NotificationServiceProtocol
}

// MARK: - Mock Services for Testing/Development

final class MockUserService: UserServiceProtocol {
    func getUser(_ request: GetUserRequest) async throws -> User_Proto {
        User_Proto(
            id: UUID().uuidString,
            name: "Test User",
            phoneNumber: "+1234567890",
            phoneRegion: "US",
            emergencyNote: "Test emergency note",
            checkInInterval: 86400,
            lastCheckedIn: nil,
            isNotificationsEnabled: true,
            notify30MinBefore: true,
            notify2HoursBefore: true,
            qrCodeId: UUID().uuidString,
            avatarURL: "",
            lastModified: Int64(Date().timeIntervalSince1970)
        )
    }
    
    func createUser(_ request: CreateUserRequest) async throws -> User_Proto {
        User_Proto(
            id: UUID().uuidString,
            name: request.name,
            phoneNumber: request.phoneNumber,
            phoneRegion: request.phoneRegion,
            emergencyNote: "",
            checkInInterval: 86400,
            lastCheckedIn: nil,
            isNotificationsEnabled: request.isNotificationsEnabled,
            notify30MinBefore: request.notify30MinBefore,
            notify2HoursBefore: request.notify2HoursBefore,
            qrCodeId: UUID().uuidString,
            avatarURL: "",
            lastModified: Int64(Date().timeIntervalSince1970)
        )
    }
    
    func updateUser(_ request: UpdateUserRequest) async throws -> User_Proto {
        User_Proto(
            id: request.id.uuidString,
            name: request.name,
            phoneNumber: request.phoneNumber,
            phoneRegion: request.phoneRegion,
            emergencyNote: request.emergencyNote,
            checkInInterval: Int64(request.checkInInterval),
            lastCheckedIn: nil,
            isNotificationsEnabled: request.isNotificationsEnabled,
            notify30MinBefore: request.notify30MinBefore,
            notify2HoursBefore: request.notify2HoursBefore,
            qrCodeId: UUID().uuidString,
            avatarURL: request.avatarURL,
            lastModified: Int64(Date().timeIntervalSince1970)
        )
    }
    
    func deleteUser(_ request: DeleteUserRequest) async throws -> Empty_Proto {
        Empty_Proto()
    }
    
    func uploadAvatar(_ request: UploadAvatarRequest) async throws -> UploadAvatarResponse {
        UploadAvatarResponse(url: "https://example.com/avatar.jpg")
    }
}

final class MockContactService: ContactServiceProtocol {
    func getContacts(_ request: GetContactsRequest) async throws -> GetContactsResponse {
        GetContactsResponse(contacts: [])
    }
    
    func addContact(_ request: AddContactRequest) async throws -> Contact_Proto {
        Contact_Proto(
            id: UUID().uuidString,
            name: request.name,
            phoneNumber: request.phoneNumber,
            isResponder: request.isResponder,
            isDependent: request.isDependent,
            lastUpdated: Int64(Date().timeIntervalSince1970),
            emergencyNote: "",
            lastCheckInTime: nil,
            interval: 86400,
            hasIncomingPing: false,
            hasOutgoingPing: false,
            manualAlertActive: false,
            incomingPingTimestamp: nil,
            outgoingPingTimestamp: nil,
            manualAlertTimestamp: nil
        )
    }
    
    func updateContact(_ request: UpdateContactRequest) async throws -> Contact_Proto {
        Contact_Proto(
            id: request.contactId.uuidString,
            name: request.name ?? "Updated Contact",
            phoneNumber: "+1234567890",
            isResponder: request.isResponder ?? true,
            isDependent: request.isDependent ?? false,
            lastUpdated: Int64(Date().timeIntervalSince1970),
            emergencyNote: request.emergencyNote ?? "",
            lastCheckInTime: nil,
            interval: Int64(request.interval ?? 86400),
            hasIncomingPing: request.hasIncomingPing ?? false,
            hasOutgoingPing: request.hasOutgoingPing ?? false,
            manualAlertActive: request.manualAlertActive ?? false,
            incomingPingTimestamp: nil,
            outgoingPingTimestamp: nil,
            manualAlertTimestamp: nil
        )
    }
    
    func removeContact(_ request: RemoveContactRequest) async throws -> Empty_Proto {
        Empty_Proto()
    }
    
    func streamContactUpdates(_ request: StreamContactUpdatesRequest) -> AsyncStream<Contact_Proto> {
        AsyncStream { _ in }
    }
}

final class MockNotificationService: NotificationServiceProtocol {
    func getNotifications(_ request: GetNotificationsRequest) async throws -> GetNotificationsResponse {
        GetNotificationsResponse(notifications: [])
    }
    
    func addNotification(_ request: AddNotificationRequest) async throws -> Notification_Proto {
        Notification_Proto(
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
        Empty_Proto()
    }
    
    func deleteNotification(_ request: DeleteNotificationRequest) async throws -> Empty_Proto {
        Empty_Proto()
    }
    
    func clearAllNotifications(_ request: ClearAllNotificationsRequest) async throws -> Empty_Proto {
        Empty_Proto()
    }
}

final class LiveUserService: UserServiceProtocol {
    // Production implementation would go here
    func getUser(_ request: GetUserRequest) async throws -> User_Proto {
        // Real gRPC call implementation
        fatalError("Live service not implemented")
    }
    
    func createUser(_ request: CreateUserRequest) async throws -> User_Proto {
        fatalError("Live service not implemented")
    }
    
    func updateUser(_ request: UpdateUserRequest) async throws -> User_Proto {
        fatalError("Live service not implemented")
    }
    
    func deleteUser(_ request: DeleteUserRequest) async throws -> Empty_Proto {
        fatalError("Live service not implemented")
    }
    
    func uploadAvatar(_ request: UploadAvatarRequest) async throws -> UploadAvatarResponse {
        fatalError("Live service not implemented")
    }
}

final class LiveContactService: ContactServiceProtocol {
    // Production implementation would go here
    func getContacts(_ request: GetContactsRequest) async throws -> GetContactsResponse {
        fatalError("Live service not implemented")
    }
    
    func addContact(_ request: AddContactRequest) async throws -> Contact_Proto {
        fatalError("Live service not implemented")
    }
    
    func updateContact(_ request: UpdateContactRequest) async throws -> Contact_Proto {
        fatalError("Live service not implemented")
    }
    
    func removeContact(_ request: RemoveContactRequest) async throws -> Empty_Proto {
        fatalError("Live service not implemented")
    }
    
    func streamContactUpdates(_ request: StreamContactUpdatesRequest) -> AsyncStream<Contact_Proto> {
        fatalError("Live service not implemented")
    }
}

final class LiveNotificationService: NotificationServiceProtocol {
    // Production implementation would go here
    func getNotifications(_ request: GetNotificationsRequest) async throws -> GetNotificationsResponse {
        fatalError("Live service not implemented")
    }
    
    func addNotification(_ request: AddNotificationRequest) async throws -> Notification_Proto {
        fatalError("Live service not implemented")
    }
    
    func markAsRead(_ request: MarkNotificationRequest) async throws -> Empty_Proto {
        fatalError("Live service not implemented")
    }
    
    func deleteNotification(_ request: DeleteNotificationRequest) async throws -> Empty_Proto {
        fatalError("Live service not implemented")
    }
    
    func clearAllNotifications(_ request: ClearAllNotificationsRequest) async throws -> Empty_Proto {
        fatalError("Live service not implemented")
    }
}

// MARK: - Dependency Implementation

extension GRPCClient: DependencyKey {
    static let liveValue = GRPCClient(
        userService: LiveUserService(),
        contactService: LiveContactService(),
        notificationService: LiveNotificationService()
    )
    
    static let testValue = GRPCClient(
        userService: MockUserService(),
        contactService: MockContactService(),
        notificationService: MockNotificationService()
    )
}

extension DependencyValues {
    var grpcClient: GRPCClient {
        get { self[GRPCClient.self] }
        set { self[GRPCClient.self] = newValue }
    }
}
