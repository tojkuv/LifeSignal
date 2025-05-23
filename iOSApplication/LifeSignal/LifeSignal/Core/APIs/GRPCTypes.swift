import Foundation

// MARK: - Generated gRPC Proto Types

struct User_Proto: Sendable {
    var id: String
    var firebaseUID: String
    var name: String
    var phoneNumber: String
    var isNotificationsEnabled: Bool
    var avatarURL: String
    var lastModified: Int64
}

struct Contact_Proto: Sendable {
    var id: String
    var userID: String
    var name: String
    var phoneNumber: String
    var relationship: Contact_Relationship
    var status: Contact_ContactStatus
    var lastUpdated: Int64
    
    enum Contact_Relationship: Int32, CaseIterable, Sendable {
        case responder = 0
        case dependent = 1
    }
    
    enum Contact_ContactStatus: Int32, CaseIterable, Sendable {
        case active = 0
        case away = 1
        case busy = 2
        case offline = 3
    }
}

struct Notification_Proto: Sendable {
    var id: String
    var userID: String
    var type: Notification_Type
    var title: String
    var message: String
    var isRead: Bool
    var createdAt: Int64
    
    enum Notification_Type: Int32, CaseIterable, Sendable {
        case checkIn = 0
        case sos = 1
        case contactRequest = 2
        case system = 3
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
  func updateContactStatus(_ request: UpdateContactStatusRequest) async throws -> Contact_Proto
  func removeContact(_ request: RemoveContactRequest) async throws -> Empty_Proto
  func streamContactUpdates(_ request: StreamContactUpdatesRequest) -> AsyncStream<Contact_Proto>
}

protocol NotificationServiceProtocol: Sendable {
  func getNotifications(_ request: GetNotificationsRequest) async throws -> GetNotificationsResponse
  func markAsRead(_ request: MarkNotificationRequest) async throws -> Empty_Proto
  func deleteNotification(_ request: DeleteNotificationRequest) async throws -> Empty_Proto
}

// MARK: - Request/Response Types

struct GetUserRequest: Sendable { 
    let firebaseUID: String 
}

struct CreateUserRequest: Sendable { 
    let firebaseUID: String
    let name: String
    let phoneNumber: String
    let isNotificationsEnabled: Bool 
}

struct UpdateUserRequest: Sendable { 
    let firebaseUID: String
    let name: String
    let phoneNumber: String
    let isNotificationsEnabled: Bool
    let avatarURL: String 
}

struct DeleteUserRequest: Sendable { 
    let firebaseUID: String 
}

struct UploadAvatarRequest: Sendable { 
    let firebaseUID: String
    let imageData: Data 
}

struct UploadAvatarResponse: Sendable { 
    let url: String 
}

struct GetContactsRequest: Sendable { 
    let firebaseUID: String 
}

struct GetContactsResponse: Sendable { 
    let contacts: [Contact_Proto] 
}

struct AddContactRequest: Sendable { 
    let firebaseUID: String
    let phoneNumber: String
    let relationship: Contact_Proto.Contact_Relationship
}

struct UpdateContactStatusRequest: Sendable { 
    let contactID: String
    let status: Contact_Proto.Contact_ContactStatus 
}

struct RemoveContactRequest: Sendable { 
    let contactID: String 
}

struct StreamContactUpdatesRequest: Sendable { 
    let firebaseUID: String 
}

struct GetNotificationsRequest: Sendable {
    let firebaseUID: String
}

struct GetNotificationsResponse: Sendable {
    let notifications: [Notification_Proto]
}

struct MarkNotificationRequest: Sendable {
    let notificationID: String
}

struct DeleteNotificationRequest: Sendable {
    let notificationID: String
}

struct Empty_Proto: Sendable {}

// MARK: - Mapping Extensions

extension User_Proto {
    func toDomain() -> User {
        User(
            id: UUID(uuidString: id) ?? UUID(),
            firebaseUID: firebaseUID,
            name: name,
            phoneNumber: phoneNumber,
            isNotificationsEnabled: isNotificationsEnabled,
            avatarURL: avatarURL.isEmpty ? nil : avatarURL,
            lastModified: Date(timeIntervalSince1970: TimeInterval(lastModified))
        )
    }
}

extension User {
    func toProto() -> User_Proto {
        User_Proto(
            id: id.uuidString,
            firebaseUID: firebaseUID,
            name: name,
            phoneNumber: phoneNumber,
            isNotificationsEnabled: isNotificationsEnabled,
            avatarURL: avatarURL ?? "",
            lastModified: Int64(lastModified.timeIntervalSince1970)
        )
    }
}

extension Contact_Proto {
    func toDomain() -> Contact {
        Contact(
            id: UUID(uuidString: id) ?? UUID(),
            userID: UUID(uuidString: userID) ?? UUID(),
            name: name,
            phoneNumber: phoneNumber,
            relationship: relationship.toDomain(),
            status: status.toDomain(),
            lastUpdated: Date(timeIntervalSince1970: TimeInterval(lastUpdated)),
            qrCodeId: UUID().uuidString,
            lastCheckIn: nil,
            note: "",
            manualAlertActive: false,
            isNonResponsive: false,
            hasIncomingPing: false,
            incomingPingTimestamp: nil,
            hasOutgoingPing: false,
            outgoingPingTimestamp: nil,
            checkInInterval: 24 * 60 * 60,
            manualAlertTimestamp: nil
        )
    }
}

extension Contact {
    func toProto() -> Contact_Proto {
        Contact_Proto(
            id: id.uuidString,
            userID: userID.uuidString,
            name: name,
            phoneNumber: phoneNumber,
            relationship: relationship.toProto(),
            status: status.toProto(),
            lastUpdated: Int64(lastUpdated.timeIntervalSince1970)
        )
    }
}

extension Contact_Proto.Contact_Relationship {
    func toDomain() -> Contact.Relationship {
        switch self {
        case .responder: return .responder
        case .dependent: return .dependent
        }
    }
}

extension Contact.Relationship {
    func toProto() -> Contact_Proto.Contact_Relationship {
        switch self {
        case .responder: return .responder
        case .dependent: return .dependent
        }
    }
}

extension Contact_Proto.Contact_ContactStatus {
    func toDomain() -> Contact.Status {
        switch self {
        case .active: return .active
        case .away: return .away
        case .busy: return .busy
        case .offline: return .offline
        }
    }
}

extension Contact.Status {
    func toProto() -> Contact_Proto.Contact_ContactStatus {
        switch self {
        case .active: return .active
        case .away: return .away
        case .busy: return .busy
        case .offline: return .offline
        }
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
            timestamp: Date(timeIntervalSince1970: TimeInterval(createdAt))
        )
    }
}

extension NotificationItem {
    func toProto() -> Notification_Proto {
        Notification_Proto(
            id: id.uuidString,
            userID: "", // Will be filled by server
            type: type.toProto(),
            title: title,
            message: message,
            isRead: isRead,
            createdAt: Int64(timestamp.timeIntervalSince1970)
        )
    }
}

extension Notification_Proto.Notification_Type {
    func toDomain() -> Notification {
        switch self {
        case .checkIn: return .checkIn
        case .sos: return .sos
        case .contactRequest: return .contactRequest
        case .system: return .system
        }
    }
}

extension Notification {
    func toProto() -> Notification_Proto.Notification_Type {
        switch self {
        case .checkIn, .checkInReminder: return .checkIn
        case .sos, .manualAlert, .alert, .emergencyAlert, .alertCancelled: return .sos
        case .contactRequest, .contactAdded, .contactRemoved, .contactRoleChanged: return .contactRequest
        case .system, .nonResponsive, .pingNotification, .qrCodeNotification: return .system
        }
    }
}